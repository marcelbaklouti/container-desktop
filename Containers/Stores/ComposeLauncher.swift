import Foundation
import Observation

@Observable
@MainActor
final class ComposeLauncher {
    enum Phase: Equatable {
        case waiting
        case pulling
        case starting
        case running
        case failed(String)
    }

    struct ServiceProgress: Identifiable {
        let id: String
        let name: String
        var phase: Phase
    }

    private(set) var progress: [ServiceProgress] = []
    private(set) var isLaunching = false
    private(set) var finished = false

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    var runningCount: Int {
        progress.filter { $0.phase == .running }.count
    }

    var failedCount: Int {
        progress.reduce(0) { count, item in
            if case .failed = item.phase { return count + 1 }
            return count
        }
    }

    func launch(_ project: ComposeProject) async {
        guard !isLaunching else { return }
        isLaunching = true
        finished = false

        let order = project.runOrder()
        progress = order.map { ServiceProgress(id: $0.name, name: $0.displayName, phase: .waiting) }

        do {
            for volume in project.namedVolumes {
                try await createToleratingExisting(["volume", "create", volume])
            }
            try await createToleratingExisting(["network", "create", project.networkName])
        } catch {
            let message = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            for index in progress.indices { progress[index].phase = .failed(message) }
            isLaunching = false
            finished = true
            return
        }

        for index in order.indices {
            let service = order[index]
            guard let image = service.image else {
                progress[index].phase = .failed(String(localized: "No image specified — build: services aren’t supported yet."))
                continue
            }

            // Re-create cleanly so re-launching a stack is idempotent.
            let identifier = service.containerIdentifier(in: project)
            _ = try? await client.data(for: ["stop", identifier])
            _ = try? await client.data(for: ["delete", identifier])

            // Pull explicitly so the row can show a distinct "Pulling…" phase; the run is the
            // arbiter, so a pull failure (e.g. the image is already local) is non-fatal here.
            progress[index].phase = .pulling
            _ = try? await client.data(for: ["image", "pull", image])

            progress[index].phase = .starting
            do {
                _ = try await client.data(for: service.runArguments(in: project))
                progress[index].phase = .running
            } catch {
                progress[index].phase = .failed((error as? RuntimeError)?.localizedMessage ?? error.localizedDescription)
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
