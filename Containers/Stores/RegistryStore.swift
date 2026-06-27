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
        do {
            _ = try await client.data(for: ["registry", "logout", login.hostname])
            await refresh()
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
    }
}
