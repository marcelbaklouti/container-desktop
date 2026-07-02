import Foundation
import Observation

@Observable
@MainActor
final class RegistryStore {
    private(set) var logins: [RegistryLogin] = []
    private(set) var hasLoaded = false
    var issue: RuntimeIssue?

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func refresh() async {
        do {
            logins = try await client.decode([RegistryLogin].self, from: ["registry", "list", "--format", "json"])
            issue = nil
        } catch {
            issue = IssueMapper.issue(for: error, context: .generic(actionTitle: String(localized: "Couldn’t Read Registry Logins")))
        }
        hasLoaded = true
    }

    func login(server: String, username: String, password: String) async throws {
        _ = try await client.data(
            for: ["registry", "login", "--username", username, "--password-stdin", server],
            input: Data(password.utf8)
        )
        await refresh()
    }

    func logout(_ login: RegistryLogin) async {
        await logout([login.hostname])
    }

    func logout(_ hostnames: [String]) async {
        var firstIssue: RuntimeIssue?
        for hostname in hostnames {
            do { _ = try await client.data(for: ["registry", "logout", hostname]) }
            catch {
                if firstIssue == nil { firstIssue = IssueMapper.issue(for: error, context: .generic(actionTitle: String(localized: "Couldn’t Log Out"))) }
            }
        }
        if let firstIssue { issue = firstIssue }
        await refresh()
    }
}
