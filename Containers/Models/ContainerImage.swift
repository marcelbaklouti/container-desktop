import Foundation

nonisolated struct ContainerImage: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let configuration: ImageConfiguration
    let variants: [ImageVariant]

    var shortDigest: String {
        let hex = configuration.descriptor.digest.split(separator: ":").last.map(String.init) ?? configuration.descriptor.digest
        return String(hex.prefix(12))
    }

    var realPlatforms: [ImageVariant] {
        variants.filter { $0.platform.os != "unknown" }
    }

    var displaySize: Int {
        if let host = realPlatforms.first(where: { $0.platform.architecture == "arm64" }) {
            return host.size
        }
        return realPlatforms.first?.size ?? 0
    }
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
