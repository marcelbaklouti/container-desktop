import Foundation
import Observation

@Observable
@MainActor
final class VolumeStore {
    private(set) var volumes: [Volume] = []
    private(set) var hasLoaded = false
    var errorMessage: String?

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func refresh() async {
        do {
            let updated = try await client.decode([Volume].self, from: ["volume", "ls", "--format", "json"])
            if updated != volumes {
                volumes = updated
            }
            errorMessage = nil
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
        hasLoaded = true
    }

    func poll(every interval: Duration) async {
        while !Task.isCancelled {
            await refresh()
            do { try await Task.sleep(for: interval) } catch { return }
        }
    }

    func create(name: String, size: String) async throws {
        var arguments = ["volume", "create"]
        if !size.isEmpty { arguments += ["-s", size] }
        arguments.append(name)
        _ = try await client.data(for: arguments)
        await refresh()
    }

    func delete(_ volume: Volume) async { await perform(["volume", "delete", volume.id]) }
    func prune() async { await perform(["volume", "prune"]) }

    private func perform(_ arguments: [String]) async {
        do {
            _ = try await client.data(for: arguments)
            await refresh()
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
    }
}
