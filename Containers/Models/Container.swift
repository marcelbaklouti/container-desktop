import Foundation

nonisolated struct Container: Codable, Sendable, Identifiable, Hashable {
    static let projectLabelKey = "com.docker.compose.project"

    let id: String
    let configuration: ContainerConfiguration
    let status: ContainerStatus?

    var project: String? {
        configuration.labels[Container.projectLabelKey]
    }
}

nonisolated struct ContainerConfiguration: Codable, Sendable, Hashable {
    let id: String
    let creationDate: String
    let image: ContainerImageReference
    let initProcess: ContainerProcess
    let resources: ContainerResources
    let networks: [ContainerNetworkAttachment]
    let publishedPorts: [PublishedPort]
    let mounts: [ContainerMount]
    let labels: [String: String]
    let platform: Platform
    let runtimeHandler: String
    let readOnly: Bool
    let rosetta: Bool
}

nonisolated struct ContainerImageReference: Codable, Sendable, Hashable {
    let reference: String
    let descriptor: OCIDescriptor
}

nonisolated struct ContainerProcess: Codable, Sendable, Hashable {
    let executable: String
    let arguments: [String]
    let environment: [String]
    let workingDirectory: String
    let terminal: Bool
    let user: ContainerProcessUser
}

nonisolated struct ContainerProcessUser: Codable, Sendable, Hashable {
    let id: ContainerProcessUserID
}

nonisolated struct ContainerProcessUserID: Codable, Sendable, Hashable {
    let uid: Int
    let gid: Int
}

nonisolated struct ContainerResources: Codable, Sendable, Hashable {
    let cpus: Int
    let memoryInBytes: Int
    let cpuOverhead: Int
}

nonisolated struct ContainerNetworkAttachment: Codable, Sendable, Hashable {
    let network: String
}

nonisolated struct PublishedPort: Codable, Sendable, Hashable {
    let hostAddress: String
    let hostPort: Int
    let containerPort: Int
    let proto: String

    var display: String { "\(hostPort):\(containerPort)/\(proto)" }
}

nonisolated struct ContainerMount: Codable, Sendable, Hashable {
    let destination: String
    let source: String
    let options: [String]
    let type: MountType

    var sourceLabel: String {
        if let name = type.volume?.name { return "volume: \(name)" }
        return source
    }
}

nonisolated struct MountType: Codable, Sendable, Hashable {
    let volume: MountVolume?
    let bind: MountEmpty?
    let tmpfs: MountEmpty?
}

nonisolated struct MountVolume: Codable, Sendable, Hashable {
    let name: String
    let format: String?
}

nonisolated struct MountEmpty: Codable, Sendable, Hashable {}

nonisolated struct ContainerStatus: Codable, Sendable, Hashable {
    let state: String
    let startedDate: String?
    let networks: [ContainerNetworkStatus]
}

nonisolated struct ContainerNetworkStatus: Codable, Sendable, Hashable {
    let network: String
    let hostname: String?
    let ipv4Address: String?
    let ipv4Gateway: String?
    let ipv6Address: String?
    let macAddress: String?
    let mtu: Int?
}
