import Foundation
import Observation

@Observable
@MainActor
final class ComposeLauncher {
    enum Step: Equatable {
        case pending
        case running
        case done
        case failed(String)
    }

    struct ServiceProgress: Identifiable {
        let id: String
        let name: String
        var step: Step
    }

    private(set) var progress: [ServiceProgress] = []
    private(set) var isLaunching = false
    private(set) var finished = false

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func launch(_ project: ComposeProject) async {
        guard !isLaunching else { return }
        isLaunching = true
        finished = false

        let order = project.runOrder()
        progress = order.map { ServiceProgress(id: $0.name, name: $0.displayName, step: .pending) }

        for volume in project.namedVolumes {
            _ = try? await client.data(for: ["volume", "create", volume])
        }
        _ = try? await client.data(for: ["network", "create", project.networkName])

        for index in order.indices {
            progress[index].step = .running
            do {
                _ = try await client.data(for: order[index].runArguments(in: project))
                progress[index].step = .done
            } catch {
                let message = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
                progress[index].step = .failed(message)
            }
        }

        isLaunching = false
        finished = true
    }
}
