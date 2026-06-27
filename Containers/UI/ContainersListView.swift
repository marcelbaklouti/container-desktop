import SwiftUI

struct ContainersListView: View {
    @State private var store = ContainerStore()
    @State private var runningOnly = false
    @State private var pendingDeletion: Container?
    @State private var showRunSheet = false

    private var visibleContainers: [Container] {
        runningOnly ? store.containers.filter { $0.status?.state == "running" } : store.containers
    }

    var body: some View {
        List {
            ForEach(visibleContainers) { container in
                ContainerRow(container: container)
                    .contextMenu { actions(for: container) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDeletion = container
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .overlay { emptyState }
        .navigationTitle("Containers")
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $runningOnly) {
                    Label("Running only", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem {
                Button {
                    showRunSheet = true
                } label: {
                    Label("Run Container", systemImage: "plus")
                }
            }
        }
        .task { await store.poll(every: .seconds(3)) }
        .confirmationDialog(
            "Delete this container?",
            isPresented: deletionBinding,
            presenting: pendingDeletion
        ) { container in
            Button("Delete", role: .destructive) {
                Task { await store.delete(container) }
            }
        } message: { container in
            Text(container.id)
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .sheet(isPresented: $showRunSheet) {
            RunContainerSheet(store: store)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if store.hasLoaded && visibleContainers.isEmpty {
            ContentUnavailableView {
                Label("No Containers", systemImage: "shippingbox")
            } description: {
                Text(runningOnly ? "No running containers." : "Run a container to see it here.")
            }
        }
    }

    @ViewBuilder
    private func actions(for container: Container) -> some View {
        if container.status?.state == "running" {
            Button { Task { await store.stop(container) } } label: { Label("Stop", systemImage: "stop.fill") }
            Button { Task { await store.restart(container) } } label: { Label("Restart", systemImage: "arrow.clockwise") }
            Button { Task { await store.kill(container) } } label: { Label("Kill", systemImage: "bolt.fill") }
        } else {
            Button { Task { await store.start(container) } } label: { Label("Start", systemImage: "play.fill") }
        }
        Divider()
        Button(role: .destructive) {
            pendingDeletion = container
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
    }
}

struct ContainerRow: View {
    let container: Container

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(.tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(container.id)
                    .font(.headline)
                Text(container.configuration.image.reference)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let address = container.status?.networks.first?.ipv4Address {
                Text(address)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            StatusBadge(text: stateText, tint: stateTint)
        }
        .padding(.vertical, 4)
    }

    private var state: String {
        container.status?.state ?? "stopped"
    }

    private var stateText: LocalizedStringKey {
        switch state {
        case "running": "Running"
        case "stopped": "Stopped"
        default: LocalizedStringKey(state.capitalized)
        }
    }

    private var stateTint: Color {
        switch state {
        case "running": .green
        case "stopped": .gray
        default: .orange
        }
    }
}
