import Foundation

nonisolated struct ContainerImage: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let configuration: ImageConfiguration
    let variants: [ImageVariant]
}

nonisolated struct ImageConfiguration: Codable, Sendable, Hashable {
    let name: String
    let descriptor: OCIDescriptor
    let creationDate: String
}

nonisolated struct ImageVariant: Codable, Sendable, Hashable {
    let digest: String
    let platform: Platform
    let size: Int
}
