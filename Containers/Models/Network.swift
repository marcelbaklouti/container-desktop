import Foundation

nonisolated struct Network: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let configuration: NetworkConfiguration
    let status: NetworkStatus?
}

nonisolated struct NetworkConfiguration: Codable, Sendable, Hashable {
    let name: String
    let mode: String
    let plugin: String
    let creationDate: String
    let labels: [String: String]
}

nonisolated struct NetworkStatus: Codable, Sendable, Hashable {
    let ipv4Gateway: String?
    let ipv4Subnet: String?
    let ipv6Subnet: String?
}
