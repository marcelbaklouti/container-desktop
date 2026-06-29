import Foundation

nonisolated struct RegistryLogin: Codable, Sendable, Identifiable, Hashable {
    let hostname: String
    let username: String?

    var id: String { hostname }

    // `registry list --format json` emits the hostname under the `name` key.
    private enum CodingKeys: String, CodingKey {
        case hostname = "name"
        case username
    }
}
