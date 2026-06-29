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
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
    }

    @discardableResult
    func add(domain: String, localhost: String) async -> Bool {
        guard DNSStore.isValidDomain(domain) else {
            errorMessage = String(localized: "Enter a valid domain — letters, numbers, dots, and hyphens only.")
            return false
        }
        guard localhost.isEmpty || DNSStore.isValidAddress(localhost) else {
            errorMessage = String(localized: "Enter a valid IP address.")
            return false
        }
        var arguments = ["system", "dns", "create"]
        if !localhost.isEmpty { arguments += ["--localhost", localhost] }
        arguments.append(domain)
        return await runPrivileged(arguments)
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

    @discardableResult
    private func runPrivileged(_ arguments: [String]) async -> Bool {
        do {
            try await PrivilegedRunner.run(arguments)
            errorMessage = nil
            await refresh()
            return true
        } catch is CancellationError {
            errorMessage = String(localized: "Authorization was cancelled.")
            return false
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            return false
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
