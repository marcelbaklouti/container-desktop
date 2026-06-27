import SwiftUI

struct VolumesListView: View {
    @State private var store = VolumeStore()
    @State private var searchText = ""
    @State private var selectedID: String?
    @State private var showInspector = false
    @State private var showCreate = false
    @State private var pendingDeletion: Volume?

    var body: some View {
        List(selection: $selectedID) {
            ForEach(store.volumes.filter { searchText.isEmpty || $0.configuration.name.localizedCaseInsensitiveContains(searchText) }) { volume in
                VolumeRow(volume: volume, usedBytes: store.usedSizes[volume.id])
                    .tag(volume.id)
                    .contextMenu { deleteButton(volume) }
                    .swipeActions(edge: .trailing) { deleteButton(volume) }
            }
        }
        .overlay { emptyState }
        .navigationTitle("Volumes")
        .searchable(text: $searchText, prompt: "Filter volumes")
        .toolbar {
            ToolbarItem {
                Button { Task { await store.prune() } } label: { Label("Prune", systemImage: "wand.and.rays") }
            }
            ToolbarItem {
                Button { showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.trailing") }
            }
            ToolbarItem {
                Button { showCreate = true } label: { Label("Create Volume", systemImage: "plus") }
            }
        }
        .task { await store.poll(every: .seconds(4)) }
        .inspector(isPresented: $showInspector) {
            if let selected = store.volumes.first(where: { $0.id == selectedID }) {
                VolumeDetailView(volume: selected, usedBytes: store.usedSizes[selected.id])
            } else {
                ContentUnavailableView("No Selection", systemImage: "externaldrive", description: Text("Select a volume to inspect it."))
            }
        }
        .onChange(of: selectedID) { _, value in if value != nil { showInspector = true } }
        .sheet(isPresented: $showCreate) { CreateVolumeSheet(store: store) }
        .confirmationDialog("Delete this volume?", isPresented: deletionBinding, presenting: pendingDeletion) { volume in
            Button("Delete", role: .destructive) { Task { await store.delete(volume) } }
        } message: { volume in
            Text(volume.id)
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func deleteButton(_ volume: Volume) -> some View {
        Button(role: .destructive) { pendingDeletion = volume } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !store.hasLoaded {
            ProgressView().controlSize(.large)
        } else if store.volumes.isEmpty {
            ContentUnavailableView("No Volumes", systemImage: "externaldrive")
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
    }
}

struct VolumeRow: View {
    let volume: Volume
    let usedBytes: Int?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(.tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(volume.configuration.name).font(.headline)
                Text("\(volume.configuration.driver) · \(volume.configuration.format)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if let usedBytes {
                    Text(Int64(usedBytes), format: .byteCount(style: .file))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text("of \(ByteCountFormatStyle(style: .file).format(Int64(volume.configuration.sizeInBytes)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct VolumeDetailView: View {
    let volume: Volume
    let usedBytes: Int?

    var body: some View {
        Form {
            Section {
                LabeledContent("Name", value: volume.configuration.name)
                LabeledContent("Driver", value: volume.configuration.driver)
                LabeledContent("Format", value: volume.configuration.format)
                if let usedBytes {
                    LabeledContent("Used") {
                        Text(Int64(usedBytes), format: .byteCount(style: .file))
                    }
                    ProgressView(value: Double(usedBytes), total: Double(max(volume.configuration.sizeInBytes, 1)))
                }
                LabeledContent("Allocated") {
                    Text(Int64(volume.configuration.sizeInBytes), format: .byteCount(style: .file))
                }
                LabeledContent("Created", value: DateText.relative(volume.configuration.creationDate))
            }
            Section("Source") {
                Text(volume.configuration.source)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            if !volume.configuration.labels.isEmpty {
                Section("Labels") {
                    ForEach(volume.configuration.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        LabeledContent(key, value: value)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(volume.configuration.name)
    }
}

struct CreateVolumeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: VolumeStore

    @State private var name = ""
    @State private var size = ""
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Volume") {
                    TextField("Name", text: $name, prompt: Text("my-volume"))
                    TextField("Size", text: $size, prompt: Text("e.g. 10G (optional)"))
                }
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create Volume")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "Creating…" : "Create") { Task { await create() } }
                        .disabled(name.isEmpty || isCreating)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 240)
    }

    private func create() async {
        isCreating = true
        error = nil
        do {
            try await store.create(name: name, size: size)
            dismiss()
        } catch {
            self.error = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            isCreating = false
        }
    }
}
