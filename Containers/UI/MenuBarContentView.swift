import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(SystemController.self) private var system
    @Environment(ContainerStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 320)
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
            VStack(alignment: .leading, spacing: 1) {
                Text("Container Desktop").font(.headline)
                Text(statusText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            daemonButton
        }
        .padding(12)
    }

    private var statusText: String {
        switch system.state {
        case .running: "\(appModel.runningCount) running · \(store.containers.count) total"
        case .daemonStopped: "Daemon stopped"
        case .binaryMissing: "container CLI not found"
        case .unknown: "Checking…"
        }
    }

    @ViewBuilder
    private var daemonButton: some View {
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

    @ViewBuilder
    private var content: some View {
        if !appModel.daemonRunning {
            Label("The container daemon is not running.", systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 18)
                .padding(.horizontal, 12)
        } else if running.isEmpty {
            Label("No running containers", systemImage: "shippingbox")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 18)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(running) { container in
                        MenuBarContainerRow(container: container, store: store, openURL: openURL)
                        if container.id != running.last?.id { Divider().padding(.leading, 12) }
                    }
                }
            }
            .frame(maxHeight: 280)
        }
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
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

private struct MenuBarContainerRow: View {
    let container: Container
    let store: ContainerStore
    let openURL: OpenURLAction

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(container.id).font(.callout).lineLimit(1)
                Text(ImageName.short(container.configuration.image.reference))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let port = container.configuration.publishedPorts.first {
                Button {
                    if let url = URL(string: "http://localhost:\(port.hostPort)") { openURL(url) }
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(.borderless)
                .help("Open localhost:\(port.hostPort)")
            }
            Button {
                Task { await store.restart(container) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Restart")
            Button {
                Task { await store.stop(container) }
            } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.borderless)
            .help("Stop")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}
