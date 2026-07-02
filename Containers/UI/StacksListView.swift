import SwiftUI
import AppKit

struct StacksListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(ContainerStore.self) private var store
    @Environment(ContainerStatsStore.self) private var stats
    @State private var searchText = ""
    @State private var selection: String?
    @State private var showInspector = false
    @State private var launchProject: ComposeProject?
    @State private var pendingDeletion: Stack?

    private var stacks: [Stack] {
        let all = Stack.stacks(from: store.containers)
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        decoratedList
            .navigationTitle("Stacks")
            .navigationSubtitle(overallSummary)
            .searchable(text: $searchText, prompt: "Filter stacks")
            .toolbar { toolbarContent }
            .inspector(isPresented: $showInspector) {
                inspectorContent
                    .inspectorColumnWidth(min: 340, ideal: 480, max: 760)
            }
            .onChange(of: selection) { _, value in showInspector = value != nil }
            .onChange(of: store.containers) { _, containers in
                if let selection, !Stack.stacks(from: containers).contains(where: { $0.id == selection }) {
                    self.selection = nil
                }
            }
            .onChange(of: appModel.navigator.stackSelection, initial: true) { _, requested in
                guard let requested else { return }
                selection = requested
                appModel.navigator.stackSelection = nil
            }
            .sheet(item: $launchProject) { project in
                ComposeLaunchSheet(project: project)
            }
            .confirmationDialog(
                "Delete the “\(pendingDeletion?.name ?? "")” stack?",
                isPresented: deletionBinding
            ) {
                Button("Delete \(pendingDeletion?.totalCount ?? 0) Container\((pendingDeletion?.totalCount ?? 0) == 1 ? "" : "s")", role: .destructive) {
                    guard let stack = pendingDeletion else { return }
                    pendingDeletion = nil
                    Task {
                        await store.stop(stack.runningIDs)
                        await store.delete(stack.memberIDs)
                    }
                }
            } message: {
                Text("This stops and permanently deletes its \(pendingDeletion?.totalCount ?? 0) containers. The stack’s network and volumes are kept.")
            }
            .issueAlert(issueBinding) { remedy in
                Task { await appModel.perform(remedy) }
            }
    }

    private var decoratedList: some View {
        List(selection: $selection) {
            ForEach(stacks) { stack in
                StackRow(stack: stack)
                    .tag(stack.id)
            }
        }
        .contextMenu(forSelectionType: String.self) { ids in
            if let name = ids.first, let stack = stacks.first(where: { $0.id == name }) {
                stackMenu(stack)
            }
        }
        .overlay { emptyState }
    }

    @ViewBuilder
    private func stackMenu(_ stack: Stack) -> some View {
        let settled = stack.containers.filter { store.pendingTransitions[$0.id] == nil }
        let running = settled.filter { $0.status?.state == "running" }.map(\.id)
        let stopped = settled.filter { $0.status?.state != "running" }.map(\.id)
        if !stopped.isEmpty {
            Button { Task { await store.start(stopped) } } label: { Label("Start All", systemImage: "play.fill") }
        }
        if !running.isEmpty {
            Button { Task { await store.stop(running) } } label: { Label("Stop All", systemImage: "stop.fill") }
            Button { Task { await store.restart(running) } } label: { Label("Restart All", systemImage: "arrow.clockwise") }
        }
        Divider()
        if stack.configFile != nil {
            Button { relaunch(stack) } label: { Label("Relaunch Stack…", systemImage: "arrow.triangle.2.circlepath") }
            Button { openComposeFile(stack) } label: { Label("Open Compose File", systemImage: "doc.text.magnifyingglass") }
        }
        Button {
            appModel.navigator.area = .containers
            appModel.navigator.containerSelection = Set(stack.memberIDs)
        } label: {
            Label("Show in Containers", systemImage: "shippingbox")
        }
        Divider()
        Button(role: .destructive) { pendingDeletion = stack } label: {
            Label("Delete Stack…", systemImage: "trash")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button {
                Task { await store.refresh(surfacingErrors: true) }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh")
        }
        ToolbarItem {
            Button {
                pickComposeFile()
            } label: {
                Label("Launch Stack", systemImage: "plus")
            }
            .help("Launch Compose Stack…")
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
    private var inspectorContent: some View {
        if let selection, let stack = stacks.first(where: { $0.id == selection }) {
            StackInspector(stack: stack, onRelaunch: { relaunch(stack) }, onOpenComposeFile: { openComposeFile(stack) })
        } else {
            ContentUnavailableView("No Selection", systemImage: "rectangle.3.group", description: Text("Select a stack to inspect it."))
        }
    }

    private var overallSummary: String {
        let all = Stack.stacks(from: store.containers)
        guard !all.isEmpty else { return "" }
        let services = all.reduce(0) { $0 + $1.runningCount }
        let stackWord = all.count == 1 ? String(localized: "1 stack") : String(localized: "\(all.count) stacks")
        guard services > 0 else { return stackWord }
        return "\(stackWord) · \(services) services running"
    }

    @ViewBuilder
    private var emptyState: some View {
        if !store.hasLoaded {
            ProgressView().controlSize(.large)
        } else if stacks.isEmpty && searchText.isEmpty {
            EmptyStateGuide(
                icon: "rectangle.3.group",
                title: "No Stacks",
                message: "A stack runs a whole app — several containers described by one compose file, started together and managed as a unit. Launch one and its services appear here and in Containers.",
                primaryLabel: "Launch Stack…",
                primaryIcon: "plus",
                primaryAction: { pickComposeFile() },
                shortcuts: [
                    KeyboardHint(label: "Launch a Compose stack", keys: "⌘N"),
                    KeyboardHint(label: "Help", keys: "⌘?"),
                    KeyboardHint(label: "Settings", keys: "⌘,"),
                ]
            )
        } else if stacks.isEmpty {
            ContentUnavailableView(
                "No Matches",
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text("No stacks match your filter.")
            )
        }
    }

    private func relaunch(_ stack: Stack) {
        guard let configFile = stack.configFile else { return }
        guard let project = ComposeProject.load(from: configFile) else {
            store.issue = .plain(
                title: String(localized: "The Compose File Can’t Be Found"),
                reason: String(localized: "It was at \(configFile.path) when this stack launched. Move it back, or launch the stack again from its new location.")
            )
            return
        }
        launchProject = project
    }

    private func openComposeFile(_ stack: Stack) {
        guard let configFile = stack.configFile else { return }
        NSWorkspace.shared.activateFileViewerSelecting([configFile])
    }

    private func pickComposeFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = String(localized: "Choose a docker-compose.yml file")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let project = ComposeProject.load(from: url) else {
            store.issue = .plain(
                title: String(localized: "Couldn’t Read the Compose File"),
                reason: String(localized: "No services could be read from that file. Make sure it’s a docker-compose.yml with a services section.")
            )
            return
        }
        launchProject = project
    }

    private var deletionBinding: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }

    private var issueBinding: Binding<RuntimeIssue?> {
        Binding(get: { store.issue }, set: { store.issue = $0 })
    }
}

private struct StackRow: View {
    let stack: Stack
    @Environment(ContainerStore.self) private var store
    @Environment(ContainerStatsStore.self) private var stats

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.3.group")
                .foregroundStyle(.tint)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(stack.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(servicesSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let liveStats {
                Text(liveStats)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if stack.containers.contains(where: { store.pendingTransitions[$0.id] != nil }) {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }
            StatusBadge(text: badgeText, tint: badgeTint)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stack.name)
        .accessibilityValue(servicesSummary)
    }

    private var servicesSummary: String {
        stack.totalCount == 1
            ? String(localized: "\(stack.runningCount) of 1 service running")
            : String(localized: "\(stack.runningCount) of \(stack.totalCount) services running")
    }

    private var liveStats: String? {
        let running = stack.runningIDs
        guard !running.isEmpty else { return nil }
        let memBytes = stats.totalMemory(for: running)
        guard memBytes > 0 else { return nil }
        let cpu = String(format: "%.0f%%", stats.totalCPU(for: running))
        return "\(cpu) · \(ByteCountFormatStyle(style: .memory).format(Int64(memBytes)))"
    }

    private var badgeText: LocalizedStringKey {
        switch stack.aggregateState {
        case .running: "Running"
        case .partial: LocalizedStringKey(String(localized: "\(stack.runningCount) of \(stack.totalCount)"))
        case .stopped: "Stopped"
        }
    }

    private var badgeTint: Color {
        switch stack.aggregateState {
        case .running: .green
        case .partial: .orange
        case .stopped: .gray
        }
    }
}
