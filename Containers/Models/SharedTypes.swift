import Foundation

nonisolated struct OCIDescriptor: Codable, Sendable, Hashable {
    let digest: String
    let mediaType: String
    let size: Int
}

nonisolated struct Platform: Codable, Sendable, Hashable {
    let architecture: String
    let os: String
    let variant: String?
}
