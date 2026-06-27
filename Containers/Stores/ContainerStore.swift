import Foundation
import Observation

@Observable
@MainActor
final class ContainerStore {
    private(set) var containers: [Container] = []
    private(set) var hasLoaded = false
    var errorMessage: String?

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func refresh() async {
        do {
            let updated = try await client.decode([Container].self, from: ["ls", "--all", "--format", "json"])
            if updated != containers {
                containers = updated
            }
            errorMessage = nil
        } catch {
            errorMessage = Self.describe(error)
        }
        hasLoaded = true
    }

    func poll(every interval: Duration) async {
        while !Task.isCancelled {
            await refresh()
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }
        }
    }

    func start(_ container: Container) async { await perform(["start", container.id]) }
    func stop(_ container: Container) async { await perform(["stop", container.id]) }
    func kill(_ container: Container) async { await perform(["kill", container.id]) }
    func delete(_ container: Container) async { await perform(["delete", container.id]) }

    func create(arguments: [String]) async throws {
        _ = try await client.data(for: arguments)
        await refresh()
    }

    func restart(_ container: Container) async {
        await perform(["stop", container.id])
        await perform(["start", container.id])
    }

    private func perform(_ arguments: [String]) async {
        do {
            _ = try await client.data(for: arguments)
            await refresh()
        } catch {
            errorMessage = Self.describe(error)
        }
    }

    private nonisolated static func describe(_ error: any Error) -> String {
        (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
    }
}
