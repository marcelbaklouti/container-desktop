import SwiftUI
import AppKit

struct ContainersListView: View {
    @Environment(ContainerStore.self) private var store
    @Environment(ContainerStatsStore.self) private var stats
    @State private var searchText = ""
    @State private var runningOnly = false
    @State private var pendingDeletion: [Container] = []
    @State private var showRunSheet = false
    @State private var selection: Set<String> = []
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
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    pendingDeletion = [container]
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    var body: some View {
        decoratedList
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
                inspectorContent
                    .inspectorColumnWidth(min: 300, ideal: 340, max: 520)
            }
            .onChange(of: selection) { _, value in
                showInspector = value.count == 1
            }
            .onChange(of: store.containers) { _, items in
                let trimmed = selection.intersection(Set(items.map(\.id)))
                if trimmed != selection { selection = trimmed }
            }
    }

    private var decoratedList: some View {
        List(selection: $selection) {
            ForEach(containerGroups) { group in
                Section {
                    ForEach(group.containers) { container in
                        row(container)
                    }
                } header: {
                    sectionHeader(group)
                }
            }
        }
        .contextMenu(forSelectionType: String.self) { ids in
            bulkMenu(ids)
        }
        .overlay { emptyState }
        .navigationTitle("Containers")
        .navigationSubtitle(overallSummary)
        .searchable(text: $searchText, prompt: "Filter containers")
        .toolbar { toolbarContent }
        .confirmationDialog(
            pendingDeletion.count == 1 ? "Delete this container?" : "Delete \(pendingDeletion.count) containers?",
            isPresented: deletionBinding
        ) {
            Button("Delete", role: .destructive) {
                let ids = pendingDeletion.map(\.id)
                pendingDeletion = []
                Task { await store.delete(ids) }
            }
        } message: {
            Text(pendingDeletion.count == 1 ? (pendingDeletion.first?.id ?? "") : "This permanently deletes \(pendingDeletion.count) containers.")
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if selection.count == 1, let id = selection.first, let selected = store.containers.first(where: { $0.id == id }) {
            ContainerInspector(container: selected)
        } else if selection.count > 1 {
            ContentUnavailableView("\(selection.count) Selected", systemImage: "shippingbox", description: Text("Select a single container to inspect it."))
        } else {
            ContentUnavailableView("No Selection", systemImage: "shippingbox", description: Text("Select a container to inspect it."))
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
        } else if store.containers.isEmpty {
            EmptyStateGuide(
                icon: "shippingbox",
                title: "No Containers",
                message: "A container packages an app with everything it needs and runs it in isolation — start as many as you like, and throw them away when you're done.",
                primaryLabel: "Run a Container",
                primaryIcon: "plus",
                primaryAction: { showRunSheet = true },
                secondaryLabel: "Launch Stack",
                secondaryIcon: "square.stack.3d.up",
                secondaryAction: { pickComposeFile() },
                shortcuts: [
                    KeyboardHint(label: "Run a container", keys: "⌘N"),
                    KeyboardHint(label: "Launch a Compose stack", keys: "⇧⌘N"),
                    KeyboardHint(label: "Help", keys: "⌘?"),
                    KeyboardHint(label: "Settings", keys: "⌘,"),
                ]
            )
        } else if visibleContainers.isEmpty {
            ContentUnavailableView(
                "No Matches",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text(runningOnly ? "No running containers." : "No containers match your filter.")
            )
        }
    }

    /// Context menu for the current selection (one or many). SwiftUI passes the effective
    /// target set, so the same menu serves single-click and multi-select.
    @ViewBuilder
    private func bulkMenu(_ ids: Set<String>) -> some View {
        let selected = store.containers.filter { ids.contains($0.id) }
        let running = selected.filter { $0.status?.state == "running" }
        let stopped = selected.filter { $0.status?.state != "running" }
        if !stopped.isEmpty {
            Button { Task { await store.start(stopped.map(\.id)) } } label: { Label(actionLabel("Start", stopped.count), systemImage: "play.fill") }
        }
        if !running.isEmpty {
            Button { Task { await store.stop(running.map(\.id)) } } label: { Label(actionLabel("Stop", running.count), systemImage: "stop.fill") }
            Button { Task { await store.restart(running.map(\.id)) } } label: { Label(actionLabel("Restart", running.count), systemImage: "arrow.clockwise") }
        }
        if selected.count == 1, let container = selected.first {
            if container.status?.state == "running" {
                Button { Task { await store.kill(container) } } label: { Label("Kill", systemImage: "bolt.fill") }
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
        }
        if !selected.isEmpty {
            Divider()
            Button(role: .destructive) { pendingDeletion = selected } label: { Label(actionLabel("Delete", selected.count), systemImage: "trash") }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button {
                showRunSheet = true
            } label: {
                Label("Run Container", systemImage: "plus")
            }
            .help("Run Container")
            .keyboardShortcut("n", modifiers: .command)
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

    @ViewBuilder
    private func sectionHeader(_ group: ContainerGroup) -> some View {
        if let title = group.title {
            HStack(spacing: 10) {
                Text(title)
                if let summary = groupSummary(group) {
                    Text(summary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                groupActions(group)
            }
        }
    }

    /// Start/Stop the whole Compose group from its section header.
    @ViewBuilder
    private func groupActions(_ group: ContainerGroup) -> some View {
        if group.id != "__standalone__" {
            let running = group.containers.filter { $0.status?.state == "running" }.map(\.id)
            let stopped = group.containers.filter { $0.status?.state != "running" }.map(\.id)
            HStack(spacing: 8) {
                if !stopped.isEmpty {
                    Button { Task { await store.start(stopped) } } label: { Image(systemName: "play.fill") }
                        .help("Start all in \(group.title ?? "this group")")
                }
                if !running.isEmpty {
                    Button { Task { await store.stop(running) } } label: { Image(systemName: "stop.fill") }
                        .help("Stop all in \(group.title ?? "this group")")
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .imageScale(.small)
        }
    }

    private func actionLabel(_ verb: String, _ count: Int) -> String {
        count == 1 ? verb : "\(verb) \(count)"
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
        Binding(get: { !pendingDeletion.isEmpty }, set: { if !$0 { pendingDeletion = [] } })
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
