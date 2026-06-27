import Foundation
import Observation

@Observable
@MainActor
final class ImageStore {
    private(set) var images: [ContainerImage] = []
    private(set) var hasLoaded = false
    private(set) var inUseReferences: Set<String> = []
    var errorMessage: String?

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func refresh() async {
        do {
            let updated = try await client.decode([ContainerImage].self, from: ["image", "ls", "--format", "json"])
            if updated != images {
                images = updated
            }
            if let containers = try? await client.decode([Container].self, from: ["ls", "--all", "--format", "json"]) {
                inUseReferences = Set(containers.map { $0.configuration.image.reference })
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

    func tag(source: String, target: String) async throws {
        _ = try await client.data(for: ["image", "tag", source, target])
        await refresh()
    }

    func delete(_ image: ContainerImage) async { await perform(["image", "delete", image.configuration.name]) }
    func prune() async { await perform(["image", "prune"]) }

    private func perform(_ arguments: [String]) async {
        do {
            _ = try await client.data(for: arguments)
            await refresh()
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
    }
}
