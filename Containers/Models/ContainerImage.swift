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

    var hostVariant: ImageVariant? {
        realPlatforms.first(where: { $0.platform.architecture == "arm64" }) ?? realPlatforms.first
    }

    var displaySize: Int {
        hostVariant?.size ?? 0
    }

    var hostHistory: [ImageHistoryEntry] {
        hostVariant?.config?.history ?? []
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
    let config: ImageVariantConfig?
}

nonisolated struct ImageVariantConfig: Codable, Sendable, Hashable {
    let history: [ImageHistoryEntry]?
}

nonisolated struct ImageHistoryEntry: Codable, Sendable, Hashable {
    let created: String?
    let createdBy: String?
    let comment: String?
    let emptyLayer: Bool?

    enum CodingKeys: String, CodingKey {
        case created, comment
        case createdBy = "created_by"
        case emptyLayer = "empty_layer"
    }
}
