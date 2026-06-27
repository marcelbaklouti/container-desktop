import Foundation

nonisolated struct Volume: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let configuration: VolumeConfiguration
}

nonisolated struct VolumeConfiguration: Codable, Sendable, Hashable {
    let name: String
    let driver: String
    let format: String
    let source: String
    let sizeInBytes: Int
    let creationDate: String
    let labels: [String: String]
}
