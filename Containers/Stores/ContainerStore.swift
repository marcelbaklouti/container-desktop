import Foundation
import Observation

@Observable
@MainActor
final class ContainerStore {
    private(set) var containers: [Container] = []
    private(set) var hasLoaded = false
    var errorMessage: String?
    private(set) var recentlyManaged: Set<String> = []

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    /// `surfacingErrors` is only set by an explicit user refresh; the background poll leaves
    /// `errorMessage` untouched so a transient read failure can't re-present (or clobber) the
    /// modal alert every few seconds.
    func refresh(surfacingErrors: Bool = false) async {
        do {
            let updated = try await client.decode([Container].self, from: ["ls", "--all", "--format", "json"])
            if updated != containers {
                containers = updated
            }
            if surfacingErrors { errorMessage = nil }
        } catch {
            if surfacingErrors { errorMessage = Self.describe(error) }
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
    func stop(_ container: Container) async { markManaged(container.id); await perform(["stop", container.id]) }
    func kill(_ container: Container) async { markManaged(container.id); await perform(["kill", container.id]) }
    func delete(_ container: Container) async { await perform(["delete", container.id]) }

    func markManaged(_ id: String) { recentlyManaged.insert(id) }

    func consumeManaged(_ id: String) -> Bool {
        recentlyManaged.remove(id) != nil
    }

    func create(arguments: [String]) async throws {
        _ = try await client.data(for: arguments)
        await refresh()
    }

    func export(_ container: Container, to url: URL) async throws {
        _ = try await client.data(for: ["export", container.id, "--output", url.path])
    }

    func copyFiles(source: String, destination: String) async throws {
        _ = try await client.data(for: ["copy", source, destination])
    }

    func restart(_ container: Container) async {
        markManaged(container.id)
        await perform(["stop", container.id])
        await perform(["start", container.id])
    }

    // Bulk actions for multi-select and Compose groups: run all, refresh once, surface the first error.
    func start(_ ids: [String]) async { await performBulk(ids.map { ["start", $0] }) }
    func delete(_ ids: [String]) async { await performBulk(ids.map { ["delete", $0] }) }
    func stop(_ ids: [String]) async {
        ids.forEach { markManaged($0) }
        await performBulk(ids.map { ["stop", $0] })
    }
    func restart(_ ids: [String]) async {
        ids.forEach { markManaged($0) }
        await performBulk(ids.flatMap { [["stop", $0], ["start", $0]] })
    }

    private func performBulk(_ commands: [[String]]) async {
        var firstError: String?
        for command in commands {
            do { _ = try await client.data(for: command) }
            catch { if firstError == nil { firstError = Self.describe(error) } }
        }
        if let firstError { errorMessage = firstError }
        await refresh()
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
