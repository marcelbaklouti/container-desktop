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

        do {
            for volume in project.namedVolumes {
                try await createToleratingExisting(["volume", "create", volume])
            }
            try await createToleratingExisting(["network", "create", project.networkName])
        } catch {
            let message = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            for index in progress.indices { progress[index].step = .failed(message) }
            isLaunching = false
            finished = true
            return
        }

        for index in order.indices {
            let service = order[index]
            guard service.image != nil else {
                progress[index].step = .failed(String(localized: "“\(service.displayName)” has no image (build: services aren’t supported yet)."))
                continue
            }
            progress[index].step = .running
            let identifier = service.containerIdentifier(in: project)
            _ = try? await client.data(for: ["stop", identifier])
            _ = try? await client.data(for: ["delete", identifier])
            do {
                _ = try await client.data(for: service.runArguments(in: project))
                progress[index].step = .done
            } catch {
                let message = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
                progress[index].step = .failed(message)
            }
        }

        isLaunching = false
        finished = true
    }

    /// Creates a project resource, tolerating the "already exists" error so re-launching
    /// a stack is idempotent, but surfacing any other failure (e.g. daemon down).
    private func createToleratingExisting(_ arguments: [String]) async throws {
        do {
            _ = try await client.data(for: arguments)
        } catch let RuntimeError.commandFailed(_, _, message)
            where message.localizedCaseInsensitiveContains("already exists") {
        }
    }
}
