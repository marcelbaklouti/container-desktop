import Foundation

nonisolated struct RegistryLogin: Codable, Sendable, Identifiable, Hashable {
    let hostname: String
    let username: String?

    var id: String { hostname }
}
