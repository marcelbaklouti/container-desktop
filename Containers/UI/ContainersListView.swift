import SwiftUI
import AppKit

struct ContainersListView: View {
    @Environment(ContainerStore.self) private var store
    @Environment(ContainerStatsStore.self) private var stats
    @State private var searchText = ""
    @State private var runningOnly = false
    @State private var pendingDeletion: Container?
    @State private var showRunSheet = false
    @State private var selectedContainerID: String?
    @State private var showInspector = false
    @State private var pendingCopy: Container?
    @State private var launchProject: ComposeProject?
    @Environment(\.openURL) private var openURL

    private var visibleContainers: [Container] {
        let base = runningOnly ? store.containers.filter { $0.status?.state == "running" } : store.containers
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.id.localizedCaseInsensitiveContains(searchText)
                || $0.configuration.image.reference.localizedCaseInsensitiveContains(searchText)
        }
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
                        HStack {
                            Text(title)
                            Spacer()
                            if let summary = groupSummary(group) {
                                Text(summary)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .overlay { emptyState }
        .navigationTitle("Containers")
        .navigationSubtitle(overallSummary)
        .searchable(text: $searchText, prompt: "Filter containers")
        .toolbar {
            ToolbarItemGroup {
                Toggle(isOn: $runningOnly) {
                    Label("Running Only", systemImage: "line.3.horizontal.decrease.circle")
                }
                .help("Show Running Containers Only")

                Button {
                    Task { await store.refresh(surfacingErrors: true) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh")
            }
            ToolbarItemGroup {
                Button {
                    pickComposeFile()
                } label: {
                    Label("Launch Stack", systemImage: "square.stack.3d.up")
                }
                .help("Launch Compose Stack")

                Button {
                    showRunSheet = true
                } label: {
                    Label("Run Container", systemImage: "plus")
                }
                .help("Run Container")
            }
            ToolbarItem {
                Button {
                    showInspector.toggle()
                } label: {
                    Label(showInspector ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.right")
                }
                .help(showInspector ? "Hide Inspector" : "Show Inspector")
            }
        }
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
        .sheet(item: $launchProject) { project in
            ComposeLaunchSheet(project: project)
        }
        .inspector(isPresented: $showInspector) {
            Group {
                if let selected = store.containers.first(where: { $0.id == selectedContainerID }) {
                    ContainerInspector(container: selected)
                } else {
                    ContentUnavailableView("No Selection", systemImage: "shippingbox", description: Text("Select a container to inspect it."))
                }
            }
            .inspectorColumnWidth(min: 300, ideal: 340, max: 520)
        }
        .onChange(of: selectedContainerID) { _, value in
            showInspector = value != nil
        }
        .onChange(of: store.containers) { _, items in
            if let id = selectedContainerID, !items.contains(where: { $0.id == id }) {
                selectedContainerID = nil
            }
        }
    }

    private var overallSummary: String {
        let runningIDs = store.containers.filter { $0.status?.state == "running" }.map(\.id)
        guard !runningIDs.isEmpty else { return "" }
        let memBytes = stats.totalMemory(for: runningIDs)
        guard memBytes > 0 else { return "\(runningIDs.count) running" }
        let cpu = String(format: "%.0f%%", stats.totalCPU(for: runningIDs))
        let mem = ByteCountFormatStyle(style: .memory).format(Int64(memBytes))
        return "\(runningIDs.count) running · \(cpu) CPU · \(mem)"
    }

    private func groupSummary(_ group: ContainerGroup) -> String? {
        let runningIDs = group.containers.filter { $0.status?.state == "running" }.map(\.id)
        guard !runningIDs.isEmpty else { return nil }
        let memBytes = stats.totalMemory(for: runningIDs)
        guard memBytes > 0 else { return nil }
        let cpu = String(format: "%.0f%%", stats.totalCPU(for: runningIDs))
        let mem = ByteCountFormatStyle(style: .memory).format(Int64(memBytes))
        return "\(cpu) · \(mem)"
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
        if !container.configuration.publishedPorts.isEmpty {
            Divider()
            ForEach(container.configuration.publishedPorts, id: \.self) { port in
                Button {
                    if let url = URL(string: "http://localhost:\(port.hostPort)") { openURL(url) }
                } label: {
                    Label("Open localhost:\(String(port.hostPort))", systemImage: "arrow.up.right")
                }
            }
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

    private func pickComposeFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = String(localized: "Choose a docker-compose.yml file")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let project = ComposeProject.load(from: url) else {
            store.errorMessage = String(localized: "Could not read services from that compose file.")
            return
        }
        launchProject = project
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
    @Environment(ContainerStatsStore.self) private var stats

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(.tint)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(container.id)
                    .font(.headline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if let liveStats {
                    Text(liveStats)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let uptime {
                    Text(uptime)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            StatusBadge(text: stateText, tint: stateTint)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(container.id)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        var parts = [state.capitalized, ImageName.short(container.configuration.image.reference)]
        if let liveStats { parts.append(liveStats) }
        return parts.joined(separator: ", ")
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

    private var liveStats: String? {
        guard state == "running", let cpu = stats.cpu(for: container.id) else { return nil }
        let cpuText = String(format: "%.0f%%", cpu)
        guard let mem = stats.memory(for: container.id) else { return cpuText }
        return "\(cpuText) · \(ByteCountFormatStyle(style: .memory).format(Int64(mem)))"
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
