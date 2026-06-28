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
        guard DNSStore.isValidDomain(domain) else {
            errorMessage = String(localized: "Enter a valid domain — letters, numbers, dots, and hyphens only.")
            return
        }
        guard localhost.isEmpty || DNSStore.isValidAddress(localhost) else {
            errorMessage = String(localized: "Enter a valid IP address.")
            return
        }
        var arguments = ["system", "dns", "create"]
        if !localhost.isEmpty { arguments += ["--localhost", localhost] }
        arguments.append(domain)
        await runPrivileged(arguments)
    }

    nonisolated static func isValidDomain(_ value: String) -> Bool {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.")
        guard (1...253).contains(value.count), value.allSatisfy({ allowed.contains($0) }) else { return false }
        return !value.hasPrefix("-") && !value.hasSuffix("-")
            && !value.hasPrefix(".") && !value.hasSuffix(".") && !value.contains("..")
    }

    nonisolated static func isValidAddress(_ value: String) -> Bool {
        let allowed = Set("0123456789abcdefABCDEF.:")
        return (1...45).contains(value.count) && value.allSatisfy { allowed.contains($0) }
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
