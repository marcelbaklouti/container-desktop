import Foundation
import Observation

@Observable
@MainActor
final class NetworkStore {
    private(set) var networks: [Network] = []
    private(set) var hasLoaded = false
    var errorMessage: String?

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func refresh() async {
        do {
            let updated = try await client.decode([Network].self, from: ["network", "ls", "--format", "json"])
            if updated != networks {
                networks = updated
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

    func create(name: String, subnet: String, subnetV6: String, internalOnly: Bool) async throws {
        var arguments = ["network", "create"]
        if internalOnly { arguments.append("--internal") }
        if !subnet.isEmpty { arguments += ["--subnet", subnet] }
        if !subnetV6.isEmpty { arguments += ["--subnet-v6", subnetV6] }
        arguments.append(name)
        _ = try await client.data(for: arguments)
        await refresh()
    }

    func delete(_ network: Network) async { await perform(["network", "delete", network.id]) }
    func prune() async { await perform(["network", "prune"]) }

    private func perform(_ arguments: [String]) async {
        do {
            _ = try await client.data(for: arguments)
            await refresh()
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
    }
}
