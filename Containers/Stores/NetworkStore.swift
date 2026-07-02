import Foundation
import Observation

@Observable
@MainActor
final class NetworkStore {
    private(set) var networks: [Network] = []
    private(set) var hasLoaded = false
    var issue: RuntimeIssue?

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func refresh(surfacingErrors: Bool = false) async {
        do {
            let updated = try await client.decode([Network].self, from: ["network", "ls", "--format", "json"])
            if updated != networks {
                networks = updated
            }
            if surfacingErrors { issue = nil }
        } catch {
            if surfacingErrors { issue = IssueMapper.issue(for: error, context: .generic(actionTitle: String(localized: "Couldn’t Refresh Networks"))) }
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

    func delete(_ network: Network) async {
        await perform(["network", "delete", network.id], context: .deleteNetwork(name: network.configuration.name, attachedTo: []))
    }

    func prune() async {
        await perform(["network", "prune"], context: .generic(actionTitle: String(localized: "Couldn’t Prune Networks")))
    }

    func delete(_ ids: [String], attachedContainers: [String: [String]] = [:]) async {
        await performBulk(ids.map { ["network", "delete", $0] }) {
            .deleteNetwork(name: $0, attachedTo: attachedContainers[$0] ?? [])
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
}
