import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(SystemController.self) private var system
    @Environment(ContainerStore.self) private var store
    @Environment(ContainerStatsStore.self) private var stats
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow
    @State private var listHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            updateRow
            Divider()
            footer
        }
        .frame(minWidth: 320)
        .onAppear { stats.start() }
        .onDisappear { stats.stop() }
    }

    @ViewBuilder
    private var updateRow: some View {
        switch appModel.updater.phase {
        case .readyToInstall(let version):
            Divider()
            HStack(spacing: 8) {
                Label("Update available — \(version)", systemImage: "arrow.down.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Restart to Update") {
                    Task { await appModel.updater.installStagedUpdate() }
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        case .downloading(let fraction):
            Divider()
            HStack(spacing: 8) {
                ProgressView(value: fraction)
                Text("Downloading update…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .layoutPriority(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        default:
            EmptyView()
        }
    }

    private var running: [Container] {
        appModel.runningContainers.sorted { $0.id < $1.id }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appModel.daemonRunning ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Container Desktop").font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .appAnimation(statusText)
            }
            Spacer()
            daemonButton
        }
        .padding(12)
    }

    private var statusText: String {
        switch system.transition {
        case .starting: return String(localized: "Starting the container system…")
        case .stopping: return String(localized: "Stopping the container system…")
        case nil: break
        }
        switch system.state {
        case .running:
            let running = appModel.runningContainers.map(\.id)
            guard !running.isEmpty else { return String(localized: "No running containers") }
            let memBytes = stats.totalMemory(for: running)
            guard memBytes > 0 else { return "\(running.count) running" }
            let cpu = String(format: "%.0f%%", stats.totalCPU(for: running))
            let mem = ByteCountFormatStyle(style: .memory).format(Int64(memBytes))
            return "\(running.count) running · \(cpu) · \(mem)"
        case .daemonStopped: return String(localized: "Daemon stopped")
        case .binaryMissing: return String(localized: "container CLI not found")
        case .unknown: return String(localized: "Checking…")
        }
    }

    @ViewBuilder
    private var daemonButton: some View {
        if system.transition != nil {
            ProgressView()
                .controlSize(.small)
        } else {
            switch system.state {
            case .running:
                Button("Stop") { Task { try? await system.stop() } }
                    .controlSize(.small)
            case .daemonStopped:
                Button("Start") { Task { try? await system.start() } }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !appModel.daemonRunning {
            VStack(spacing: 10) {
                if system.transition == .starting {
                    ProgressView()
                        .controlSize(.small)
                    Text("Starting the container system…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Label("The container system is stopped.", systemImage: "stop.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Start") { Task { try? await system.start() } }
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
        } else if running.isEmpty {
            Label("No running containers", systemImage: "shippingbox")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 18)
        } else {
            // ScrollView has no intrinsic height, so inside the self-sizing MenuBarExtra(.window)
            // it collapses to zero — measure the content and bound the height explicitly.
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(runningGroups, id: \.id) { group in
                        if let title = group.title {
                            stackHeader(title: title, containers: group.containers)
                        }
                        ForEach(group.containers) { container in
                            MenuBarContainerRow(container: container, store: store, openURL: openURL)
                            if container.id != group.containers.last?.id { Divider().padding(.leading, 12) }
                        }
                        if group.id != runningGroups.last?.id { Divider() }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
            }
            .frame(height: min(listHeight, 320))
        }
    }

    private struct RunningGroup: Identifiable {
        let id: String
        let title: String?
        let containers: [Container]
    }

    private var runningGroups: [RunningGroup] {
        let grouped = Dictionary(grouping: running) { $0.project ?? "" }
        var groups: [RunningGroup] = []
        for project in grouped.keys.filter({ !$0.isEmpty }).sorted() {
            groups.append(RunningGroup(id: project, title: project, containers: grouped[project] ?? []))
        }
        if let standalone = grouped[""], !standalone.isEmpty {
            groups.append(RunningGroup(id: "__standalone__", title: nil, containers: standalone))
        }
        return groups
    }

    @ViewBuilder
    private func stackHeader(title: String, containers: [Container]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.3.group")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await store.stop(containers.map(\.id)) }
            } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Stop all in \(title)")
            .accessibilityLabel("Stop all in \(title)")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            Button("Open Container Desktop") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding(12)
    }
}

private struct MenuBarContainerRow: View {
    let container: Container
    let store: ContainerStore
    let openURL: OpenURLAction
    @Environment(ContainerStatsStore.self) private var stats

    private var subtitle: String {
        let image = ImageName.short(container.configuration.image.reference)
        guard let cpu = stats.cpu(for: container.id) else { return image }
        let cpuText = String(format: "%.0f%%", cpu)
        guard let mem = stats.memory(for: container.id) else { return "\(image) · \(cpuText)" }
        return "\(image) · \(cpuText) · \(ByteCountFormatStyle(style: .memory).format(Int64(mem)))"
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(container.id).font(.callout).lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if store.pendingTransitions[container.id] != nil {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(transitionLabel)
            } else {
                if let port = container.configuration.publishedPorts.first {
                    Button {
                        if let url = URL(string: "http://localhost:\(port.hostPort)") { openURL(url) }
                    } label: {
                        Image(systemName: "arrow.up.right")
                    }
                    .buttonStyle(.borderless)
                    .help("Open localhost:\(String(port.hostPort))")
                    .accessibilityLabel("Open port \(String(port.hostPort)) in browser")
                }
                Button {
                    Task { await store.restart(container) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Restart")
                .accessibilityLabel("Restart \(container.id)")
                Button {
                    Task { await store.stop(container) }
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderless)
                .help("Stop")
                .accessibilityLabel("Stop \(container.id)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var transitionLabel: String {
        switch store.pendingTransitions[container.id] {
        case .starting: String(localized: "Starting \(container.id)")
        case .stopping: String(localized: "Stopping \(container.id)")
        case .restarting: String(localized: "Restarting \(container.id)")
        case nil: ""
        }
    }
}
