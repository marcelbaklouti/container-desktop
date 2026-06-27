import SwiftUI
import AppKit

struct ContainersListView: View {
    @State private var store = ContainerStore()
    @State private var runningOnly = false
    @State private var pendingDeletion: Container?
    @State private var showRunSheet = false
    @State private var selectedContainerID: String?
    @State private var showInspector = false
    @State private var pendingCopy: Container?

    private var visibleContainers: [Container] {
        runningOnly ? store.containers.filter { $0.status?.state == "running" } : store.containers
    }

    private struct ContainerGroup: Identifiable {
        let id: String
        let title: String?
        let containers: [Container]
    }

    private var containerGroups: [ContainerGroup] {
        let grouped = Dictionary(grouping: visibleContainers) { $0.project ?? "" }
        var groups: [ContainerGroup] = []
        for project in grouped.keys.filter({ !$0.isEmpty }).sorted() {
            let containers = (grouped[project] ?? []).sorted { $0.id < $1.id }
            groups.append(ContainerGroup(id: project, title: project, containers: containers))
        }
        if let standalone = grouped[""], !standalone.isEmpty {
            let title: String? = groups.isEmpty ? nil : "Standalone"
            groups.append(ContainerGroup(id: "__standalone__", title: title, containers: standalone.sorted { $0.id < $1.id }))
        }
        return groups
    }

    @ViewBuilder
    private func row(_ container: Container) -> some View {
        ContainerRow(container: container)
            .tag(container.id)
            .contextMenu { actions(for: container) }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    pendingDeletion = container
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    var body: some View {
        List(selection: $selectedContainerID) {
            ForEach(containerGroups) { group in
                Section {
                    ForEach(group.containers) { container in
                        row(container)
                    }
                } header: {
                    if let title = group.title {
                        Text(title)
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
            ToolbarItem {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
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
        .sheet(item: $pendingCopy) { container in
            CopyFilesSheet(store: store, container: container)
        }
        .inspector(isPresented: $showInspector) {
            if let selected = store.containers.first(where: { $0.id == selectedContainerID }) {
                ContainerInspector(container: selected)
            } else {
                ContentUnavailableView("No Selection", systemImage: "shippingbox", description: Text("Select a container to inspect it."))
            }
        }
        .onChange(of: selectedContainerID) { _, newValue in
            if newValue != nil { showInspector = true }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !store.hasLoaded {
            ProgressView().controlSize(.large)
        } else if visibleContainers.isEmpty {
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
        Button { pendingCopy = container } label: { Label("Copy Files…", systemImage: "doc.on.doc") }
        Button { exportFilesystem(container) } label: { Label("Export Filesystem…", systemImage: "arrow.down.doc") }
        Divider()
        Button(role: .destructive) {
            pendingDeletion = container
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func exportFilesystem(_ container: Container) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(container.id).tar"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                try await store.export(container, to: url)
            } catch {
                store.errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            }
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
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let uptime {
                Text(uptime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            StatusBadge(text: stateText, tint: stateTint)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        let image = ImageName.short(container.configuration.image.reference)
        let ports = container.configuration.publishedPorts
        guard !ports.isEmpty else { return image }
        let portText = ports.map { "\($0.hostPort)→\($0.containerPort)" }.joined(separator: ", ")
        return "\(image) · \(portText)"
    }

    private var uptime: String? {
        guard state == "running", let started = container.status?.startedDate else { return nil }
        return DateText.uptime(since: started).map { "Up \($0)" }
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
