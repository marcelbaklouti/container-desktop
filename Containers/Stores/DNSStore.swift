import Foundation
import Observation

@Observable
@MainActor
final class DNSStore {
    private(set) var domains: [String] = []
    var errorMessage: String?

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func refresh() async {
        do {
            let data = try await client.data(for: ["system", "dns", "list", "--format", "json"])
            domains = DNSStore.parseDomains(data)
        } catch {
            domains = []
        }
    }

    func add(domain: String, localhost: String) async {
        var arguments = ["system", "dns", "create"]
        if !localhost.isEmpty { arguments += ["--localhost", localhost] }
        arguments.append(domain)
        await runPrivileged(arguments)
    }

    func remove(domain: String) async {
        await runPrivileged(["system", "dns", "delete", domain])
    }

    private func runPrivileged(_ arguments: [String]) async {
        do {
            try await PrivilegedRunner.run(arguments)
            errorMessage = nil
            await refresh()
        } catch is CancellationError {
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
    }

    private nonisolated static func parseDomains(_ data: Data) -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        if let strings = json as? [String] { return strings.sorted() }
        if let objects = json as? [[String: Any]] {
            return objects.compactMap { ($0["domain"] ?? $0["name"]) as? String }.sorted()
        }
        return []
    }
}
