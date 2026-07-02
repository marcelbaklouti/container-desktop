import Foundation
import Observation

@Observable
@MainActor
final class VolumeStore {
    private(set) var volumes: [Volume] = []
    private(set) var hasLoaded = false
    var issue: RuntimeIssue?
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
            if surfacingErrors { issue = nil }
        } catch {
            if surfacingErrors { issue = IssueMapper.issue(for: error, context: .generic(actionTitle: String(localized: "Couldn’t Refresh Volumes"))) }
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

    func delete(_ volume: Volume) async {
        await perform(["volume", "delete", volume.id], context: .deleteVolume(name: volume.configuration.name, mountedBy: []))
    }

    func prune() async {
        await perform(["volume", "prune"], context: .generic(actionTitle: String(localized: "Couldn’t Prune Volumes")))
    }

    func delete(_ ids: [String], mountedBy: [String: [String]] = [:]) async {
        await performBulk(ids.map { ["volume", "delete", $0] }) {
            .deleteVolume(name: $0, mountedBy: mountedBy[$0] ?? [])
        }
    }

    private func performBulk(_ commands: [[String]], context: (String) -> IssueMapper.Context) async {
        var firstIssue: RuntimeIssue?
        for command in commands {
            do { _ = try await client.data(for: command) }
            catch {
                if firstIssue == nil { firstIssue = IssueMapper.issue(for: error, context: context(command.last ?? "")) }
            }
        }
        if let firstIssue { issue = firstIssue }
        await refresh()
    }

    private func perform(_ arguments: [String], context: IssueMapper.Context) async {
        do {
            _ = try await client.data(for: arguments)
            await refresh()
        } catch {
            issue = IssueMapper.issue(for: error, context: context)
        }
    }

    nonisolated static func usedBytes(path: String) -> Int? {
        var info = stat()
        guard lstat(path, &info) == 0 else { return nil }
        return Int(info.st_blocks) * 512
    }
}
