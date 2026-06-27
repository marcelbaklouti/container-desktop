import SwiftUI

struct NetworksListView: View {
    @State private var store = NetworkStore()
    @State private var selectedID: String?
    @State private var showInspector = false
    @State private var showCreate = false
    @State private var pendingDeletion: Network?

    var body: some View {
        List(selection: $selectedID) {
            ForEach(store.networks) { network in
                NetworkRow(network: network)
                    .tag(network.id)
                    .contextMenu { deleteButton(network) }
                    .swipeActions(edge: .trailing) { deleteButton(network) }
            }
        }
        .overlay { emptyState }
        .navigationTitle("Networks")
        .toolbar {
            ToolbarItem {
                Button { Task { await store.prune() } } label: { Label("Prune", systemImage: "wand.and.rays") }
            }
            ToolbarItem {
                Button { showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.trailing") }
            }
            ToolbarItem {
                Button { showCreate = true } label: { Label("Create Network", systemImage: "plus") }
            }
        }
        .task { await store.poll(every: .seconds(4)) }
        .inspector(isPresented: $showInspector) {
            if let selected = store.networks.first(where: { $0.id == selectedID }) {
                NetworkDetailView(network: selected)
            } else {
                ContentUnavailableView("No Selection", systemImage: "network", description: Text("Select a network to inspect it."))
            }
        }
        .onChange(of: selectedID) { _, value in if value != nil { showInspector = true } }
        .sheet(isPresented: $showCreate) { CreateNetworkSheet(store: store) }
        .confirmationDialog("Delete this network?", isPresented: deletionBinding, presenting: pendingDeletion) { network in
            Button("Delete", role: .destructive) { Task { await store.delete(network) } }
        } message: { network in
            Text(network.id)
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func deleteButton(_ network: Network) -> some View {
        if !network.isBuiltin {
            Button(role: .destructive) { pendingDeletion = network } label: { Label("Delete", systemImage: "trash") }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !store.hasLoaded {
            ProgressView().controlSize(.large)
        } else if store.networks.isEmpty {
            ContentUnavailableView("No Networks", systemImage: "network")
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
    }
}

struct NetworkRow: View {
    let network: Network

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "network")
                .foregroundStyle(.tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(network.configuration.name).font(.headline)
                Text(network.status?.ipv4Subnet ?? network.configuration.mode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if network.isBuiltin {
                StatusBadge(text: "Built-in", tint: .gray)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct NetworkDetailView: View {
    let network: Network

    var body: some View {
        Form {
            Section {
                LabeledContent("Name", value: network.configuration.name)
                LabeledContent("Mode", value: network.configuration.mode)
                LabeledContent("Plugin", value: network.configuration.plugin)
                LabeledContent("Created", value: DateText.relative(network.configuration.creationDate))
            }
            if let status = network.status {
                Section("Addressing") {
                    if let subnet = status.ipv4Subnet { LabeledContent("IPv4 subnet", value: subnet) }
                    if let gateway = status.ipv4Gateway { LabeledContent("IPv4 gateway", value: gateway) }
                    if let v6 = status.ipv6Subnet { LabeledContent("IPv6 subnet", value: v6) }
                }
            }
            if !network.configuration.labels.isEmpty {
                Section("Labels") {
                    ForEach(network.configuration.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        LabeledContent(key, value: value)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(network.configuration.name)
    }
}

struct CreateNetworkSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: NetworkStore

    @State private var name = ""
    @State private var subnet = ""
    @State private var subnetV6 = ""
    @State private var internalOnly = false
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Network") {
                    TextField("Name", text: $name, prompt: Text("my-network"))
                    TextField("Subnet", text: $subnet, prompt: Text("10.10.0.0/24 (optional)"))
                    TextField("IPv6 subnet", text: $subnetV6, prompt: Text("optional"))
                    Toggle("Host-only (internal)", isOn: $internalOnly)
                }
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create Network")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "Creating…" : "Create") { Task { await create() } }
                        .disabled(name.isEmpty || isCreating)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 320)
    }

    private func create() async {
        isCreating = true
        error = nil
        do {
            try await store.create(name: name, subnet: subnet, subnetV6: subnetV6, internalOnly: internalOnly)
            dismiss()
        } catch {
            self.error = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            isCreating = false
        }
    }
}
