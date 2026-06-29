import Foundation
import Observation

@Observable
@MainActor
final class RegistryStore {
    private(set) var logins: [RegistryLogin] = []
    private(set) var hasLoaded = false
    var errorMessage: String?

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func refresh() async {
        do {
            logins = try await client.decode([RegistryLogin].self, from: ["registry", "list", "--format", "json"])
            errorMessage = nil
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
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
        var firstError: String?
        for hostname in hostnames {
            do { _ = try await client.data(for: ["registry", "logout", hostname]) }
            catch { if firstError == nil { firstError = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription } }
        }
        if let firstError { errorMessage = firstError }
        await refresh()
    }
}
