import Foundation
import Observation

@Observable
@MainActor
final class VolumeStore {
    private(set) var volumes: [Volume] = []
    private(set) var hasLoaded = false
    var errorMessage: String?
    private(set) var usedSizes: [String: Int] = [:]

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func refresh(surfacingErrors: Bool = false) async {
        do {
            let updated = try await client.decode([Volume].self, from: ["volume", "ls", "--format", "json"])
            if updated != volumes {
                volumes = updated
            }
            usedSizes = Dictionary(uniqueKeysWithValues: updated.compactMap { volume in
                VolumeStore.usedBytes(path: volume.configuration.source).map { (volume.id, $0) }
            })
            if surfacingErrors { errorMessage = nil }
        } catch {
            if surfacingErrors { errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription }
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
    func delete(_ ids: [String]) async { await performBulk(ids.map { ["volume", "delete", $0] }) }

    private func performBulk(_ commands: [[String]]) async {
        var firstError: String?
        for command in commands {
            do { _ = try await client.data(for: command) }
            catch { if firstError == nil { firstError = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription } }
        }
        if let firstError { errorMessage = firstError }
        await refresh()
    }

    private func perform(_ arguments: [String]) async {
        do {
            _ = try await client.data(for: arguments)
            await refresh()
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
    }

    nonisolated static func usedBytes(path: String) -> Int? {
        var info = stat()
        guard lstat(path, &info) == 0 else { return nil }
        return Int(info.st_blocks) * 512
    }
}
