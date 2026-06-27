import Foundation

nonisolated struct Machine: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let status: String
    let createdDate: String
    let ipAddress: String?
    let cpus: Int
    let memory: Int
    let diskSize: Int
    let isDefault: Bool

    var isRunning: Bool { status == "running" }

    enum CodingKeys: String, CodingKey {
        case id, status, createdDate, ipAddress, cpus, memory, diskSize
        case isDefault = "default"
    }
}
