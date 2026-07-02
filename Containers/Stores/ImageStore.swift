import Foundation
import Observation

@Observable
@MainActor
final class ImageStore {
    private(set) var images: [ContainerImage] = []
    private(set) var hasLoaded = false
    var issue: RuntimeIssue?

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func refresh(surfacingErrors: Bool = false) async {
        do {
            let updated = try await client.decode([ContainerImage].self, from: ["image", "ls", "--format", "json"])
            if updated != images {
                images = updated
            }
            if surfacingErrors { issue = nil }
        } catch {
            if surfacingErrors { issue = IssueMapper.issue(for: error, context: .generic(actionTitle: String(localized: "Couldn’t Refresh Images"))) }
        }
        hasLoaded = true
    }

    func poll(every interval: Duration) async {
        while !Task.isCancelled {
            await refresh()
            do { try await Task.sleep(for: interval) } catch { return }
        }
    }

    func tag(source: String, target: String) async throws {
        _ = try await client.data(for: ["image", "tag", source, target])
        await refresh()
    }

    func save(_ image: ContainerImage, to url: URL) async throws {
        _ = try await client.data(for: ["image", "save", image.configuration.name, "-o", url.path])
    }

    func load(from url: URL) async throws {
        _ = try await client.data(for: ["image", "load", "-i", url.path])
        await refresh()
    }

    func delete(_ image: ContainerImage) async {
        await perform(["image", "delete", image.configuration.name], context: .deleteImage(reference: image.configuration.name))
    }

    func prune() async {
        await perform(["image", "prune"], context: .generic(actionTitle: String(localized: "Couldn’t Prune Images")))
    }

    func delete(_ names: [String]) async {
        await performBulk(names.map { ["image", "delete", $0] }) { .deleteImage(reference: $0) }
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
}
