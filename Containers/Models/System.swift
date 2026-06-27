import Foundation

nonisolated struct SystemStatus: Codable, Sendable, Hashable {
    let status: String
    let apiServerVersion: String?
    let apiServerCommit: String?
    let apiServerBuild: String?
    let apiServerAppName: String?
    let appRoot: String?
    let installRoot: String?

    var isRunning: Bool {
        status == "running"
    }
}

nonisolated struct DiskUsage: Codable, Sendable, Hashable {
    let containers: DiskUsageEntry
    let images: DiskUsageEntry
    let volumes: DiskUsageEntry
}

nonisolated struct DiskUsageEntry: Codable, Sendable, Hashable {
    let total: Int
    let active: Int
    let sizeInBytes: Int
    let reclaimable: Int
}
