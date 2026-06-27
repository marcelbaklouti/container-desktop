import SwiftUI

struct RuntimeUnavailableView: View {
    @Environment(SystemController.self) private var system
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
            Link(destination: URL(string: "https://github.com/apple/container")!) {
                Label("Installation Instructions", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.glass)
        default:
            EmptyView()
        }
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
