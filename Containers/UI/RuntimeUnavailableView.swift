import SwiftUI

struct RuntimeUnavailableView: View {
    @Environment(SystemController.self) private var system
    @Environment(ContainerInstaller.self) private var installer
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            action
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .navigationTitle("Container Desktop")
        .task {
            if case .binaryMissing = system.state {
                await installer.checkForUpdates()
            }
        }
    }

    @ViewBuilder
    private var action: some View {
        switch system.state {
        case .daemonStopped:
            Button {
                Task { await start() }
            } label: {
                Label(isWorking ? "Starting…" : "Start Container System", systemImage: "play.fill")
            }
            .buttonStyle(.glassProminent)
            .disabled(isWorking)
        case .binaryMissing:
            VStack(spacing: 10) {
                installAction
                Link(destination: releaseURL) {
                    Label("Install Manually", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.glass)
                if case let .failed(message) = installer.phase {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var installAction: some View {
        switch installer.phase {
        case .idle, .failed:
            Button {
                Task { await installer.installOrUpdate() }
            } label: {
                Label("Install container \(installer.targetVersion)", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.glassProminent)
        case .downloading(let fraction):
            VStack(spacing: 4) {
                ProgressView(value: fraction).frame(width: 240)
                Text("Downloading container… \(String(Int(fraction * 100)))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .finished:
            Label("Installed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        default:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(installer.phaseDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var releaseURL: URL {
        URL(string: "https://github.com/apple/container/releases") ?? URL(fileURLWithPath: "/")
    }

    private var symbol: String {
        switch system.state {
        case .binaryMissing: "exclamationmark.triangle.fill"
        default: "stop.circle"
        }
    }

    private var title: LocalizedStringKey {
        switch system.state {
        case .binaryMissing: "The container tool isn’t installed"
        default: "The container system is stopped"
        }
    }

    private var message: LocalizedStringKey {
        switch system.state {
        case .binaryMissing:
            "Install Apple’s container command-line tool to manage containers, images, and volumes from here."
        default:
            "Start the container system to manage your containers, images, networks, and volumes."
        }
    }

    private func start() async {
        isWorking = true
        errorMessage = nil
        do {
            try await system.start()
        } catch {
            errorMessage = String(localized: "Couldn’t start the container system.")
        }
        isWorking = false
    }
}
