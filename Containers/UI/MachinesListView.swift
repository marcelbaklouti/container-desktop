import SwiftUI

struct MachinesListView: View {
    @State private var store = MachineStore()
    @State private var searchText = ""
    @State private var selectedID: String?
    @State private var showInspector = false
    @State private var showCreate = false
    @State private var reconfiguring: Machine?
    @State private var shellMachine: Machine?
    @State private var pendingDeletion: Machine?

    var body: some View {
        List(selection: $selectedID) {
            ForEach(store.machines.filter { searchText.isEmpty || $0.id.localizedCaseInsensitiveContains(searchText) }) { machine in
                MachineRow(machine: machine)
                    .tag(machine.id)
                    .contextMenu { actions(for: machine) }
            }
        }
        .overlay { emptyState }
        .navigationTitle("Machines")
        .searchable(text: $searchText, prompt: "Filter machines")
        .toolbar {
            ToolbarItem {
                Button { showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.trailing") }
            }
            ToolbarItem {
                Button { showCreate = true } label: { Label("Create Machine", systemImage: "plus") }
            }
        }
        .task { await store.poll(every: .seconds(4)) }
        .inspector(isPresented: $showInspector) {
            if let selected = store.machines.first(where: { $0.id == selectedID }) {
                MachineDetailView(machine: selected)
            } else {
                ContentUnavailableView("No Selection", systemImage: "server.rack", description: Text("Select a machine to inspect it."))
            }
        }
        .onChange(of: selectedID) { _, value in if value != nil { showInspector = true } }
        .sheet(isPresented: $showCreate) { CreateMachineSheet(store: store) }
        .sheet(item: $reconfiguring) { machine in ReconfigureMachineSheet(store: store, machine: machine) }
        .sheet(item: $shellMachine) { machine in MachineTerminalSheet(machineID: machine.id) }
        .confirmationDialog("Delete this machine?", isPresented: deletionBinding, presenting: pendingDeletion) { machine in
            Button("Delete", role: .destructive) { Task { await store.delete(machine) } }
        } message: { machine in
            Text(machine.id)
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func actions(for machine: Machine) -> some View {
        Button { shellMachine = machine } label: { Label("Open Shell", systemImage: "terminal") }
        if !machine.isDefault {
            Button { Task { await store.setDefault(machine) } } label: { Label("Set as Default", systemImage: "star") }
        }
        Button { reconfiguring = machine } label: { Label("Reconfigure…", systemImage: "slider.horizontal.3") }
        if machine.isRunning {
            Button { Task { await store.stop(machine) } } label: { Label("Stop", systemImage: "stop.fill") }
        }
        Divider()
        Button(role: .destructive) { pendingDeletion = machine } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !store.hasLoaded {
            ProgressView().controlSize(.large)
        } else if store.machines.isEmpty {
            ContentUnavailableView("No Machines", systemImage: "server.rack", description: Text("Create a container machine to get started."))
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
    }
}

struct MachineRow: View {
    let machine: Machine

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .foregroundStyle(.tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(machine.id).font(.headline)
                    if machine.isDefault { StatusBadge(text: "Default", tint: .blue) }
                }
                Text("\(machine.cpus.formatted(.number.grouping(.never))) CPU · \(ByteCountFormatStyle(style: .memory).format(Int64(machine.memory)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let ip = machine.ipAddress {
                Text(ip).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            StatusBadge(text: LocalizedStringKey(machine.status.capitalized), tint: machine.isRunning ? .green : .gray)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct MachineDetailView: View {
    let machine: Machine

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    StatusBadge(text: LocalizedStringKey(machine.status.capitalized), tint: machine.isRunning ? .green : .gray)
                }
                LabeledContent("Default", value: machine.isDefault ? "Yes" : "No")
                if let ip = machine.ipAddress { LabeledContent("IP", value: ip) }
                LabeledContent("Created", value: DateText.relative(machine.createdDate))
            }
            Section("Resources") {
                LabeledContent("CPUs", value: machine.cpus.formatted())
                LabeledContent("Memory") { Text(Int64(machine.memory), format: .byteCount(style: .memory)) }
                LabeledContent("Disk") { Text(Int64(machine.diskSize), format: .byteCount(style: .file)) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(machine.id)
    }
}

struct CreateMachineSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: MachineStore

    @State private var image = ""
    @State private var name = ""
    @State private var cpus = ""
    @State private var memory = ""
    @State private var homeMount = "rw"
    @State private var setDefault = false
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Machine") {
                    TextField("Image", text: $image, prompt: Text("alpine:3.22"))
                    TextField("Name", text: $name, prompt: Text("optional"))
                }
                Section("Resources") {
                    TextField("CPUs", text: $cpus, prompt: Text("default"))
                    TextField("Memory", text: $memory, prompt: Text("e.g. 2G (default: half of system)"))
                    Picker("Home mount", selection: $homeMount) {
                        Text("Read/write").tag("rw")
                        Text("Read-only").tag("ro")
                        Text("None").tag("none")
                    }
                }
                Section {
                    Toggle("Set as default", isOn: $setDefault)
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create Machine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "Creating…" : "Create") { Task { await create() } }
                        .disabled(image.isEmpty || isCreating)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 440)
    }

    private func create() async {
        isCreating = true
        error = nil
        do {
            try await store.create(image: image, name: name, cpus: cpus, memory: memory, homeMount: homeMount, setDefault: setDefault)
            dismiss()
        } catch {
            self.error = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            isCreating = false
        }
    }
}

struct ReconfigureMachineSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: MachineStore
    let machine: Machine

    @State private var cpus = ""
    @State private var memory = ""
    @State private var homeMount = ""
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Reconfigure \(machine.id)") {
                    TextField("CPUs", text: $cpus, prompt: Text(machine.cpus.formatted()))
                    TextField("Memory", text: $memory, prompt: Text("e.g. 4G"))
                    Picker("Home mount", selection: $homeMount) {
                        Text("Unchanged").tag("")
                        Text("Read/write").tag("rw")
                        Text("Read-only").tag("ro")
                        Text("None").tag("none")
                    }
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Reconfigure Machine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(isSaving || (cpus.isEmpty && memory.isEmpty && homeMount.isEmpty))
                }
            }
        }
        .frame(minWidth: 460, minHeight: 320)
    }

    private func save() async {
        isSaving = true
        error = nil
        do {
            try await store.reconfigure(machine, cpus: cpus, memory: memory, homeMount: homeMount)
            dismiss()
        } catch {
            self.error = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            isSaving = false
        }
    }
}
