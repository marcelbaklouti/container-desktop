import Foundation

nonisolated struct DockerContainer: Codable, Sendable, Identifiable, Hashable {
    nonisolated struct State: Codable, Sendable, Hashable {
        let status: String
        let running: Bool

        enum CodingKeys: String, CodingKey {
            case status = "Status"
            case running = "Running"
        }
    }

    nonisolated struct Config: Codable, Sendable, Hashable {
        let image: String
        let env: [String]?
        let cmd: [String]?
        let entrypoint: [String]?
        let labels: [String: String]?
        let workingDir: String?
        let user: String?

        enum CodingKeys: String, CodingKey {
            case image = "Image"
            case env = "Env"
            case cmd = "Cmd"
            case entrypoint = "Entrypoint"
            case labels = "Labels"
            case workingDir = "WorkingDir"
            case user = "User"
        }
    }

    nonisolated struct PortBinding: Codable, Sendable, Hashable {
        let hostIP: String?
        let hostPort: String?

        enum CodingKeys: String, CodingKey {
            case hostIP = "HostIp"
            case hostPort = "HostPort"
        }
    }

    nonisolated struct RestartPolicy: Codable, Sendable, Hashable {
        let name: String?

        enum CodingKeys: String, CodingKey {
            case name = "Name"
        }
    }

    nonisolated struct HostConfig: Codable, Sendable, Hashable {
        let binds: [String]?
        let portBindings: [String: [PortBinding]?]?
        let restartPolicy: RestartPolicy?
        let memory: Int?
        let nanoCPUs: Int?
        let networkMode: String?

        enum CodingKeys: String, CodingKey {
            case binds = "Binds"
            case portBindings = "PortBindings"
            case restartPolicy = "RestartPolicy"
            case memory = "Memory"
            case nanoCPUs = "NanoCpus"
            case networkMode = "NetworkMode"
        }
    }

    nonisolated struct Mount: Codable, Sendable, Hashable {
        let type: String
        let name: String?
        let source: String?
        let destination: String
        let rw: Bool?

        enum CodingKeys: String, CodingKey {
            case type = "Type"
            case name = "Name"
            case source = "Source"
            case destination = "Destination"
            case rw = "RW"
        }
    }

    let id: String
    let name: String
    let state: State
    let config: Config
    let hostConfig: HostConfig
    let mounts: [Mount]

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case state = "State"
        case config = "Config"
        case hostConfig = "HostConfig"
        case mounts = "Mounts"
    }

    var displayName: String {
        name.hasPrefix("/") ? String(name.dropFirst()) : name
    }

    var project: String? {
        config.labels?[Container.projectLabelKey]
    }

    var isRunning: Bool { state.running }

    var namedVolumeMounts: [Mount] {
        mounts.filter { $0.type == "volume" && $0.name != nil }
    }
}

nonisolated struct DockerImage: Codable, Sendable {
    nonisolated struct Config: Codable, Sendable {
        let env: [String]?
        let cmd: [String]?
        let entrypoint: [String]?
        let labels: [String: String]?
        let workingDir: String?
        let user: String?

        enum CodingKeys: String, CodingKey {
            case env = "Env"
            case cmd = "Cmd"
            case entrypoint = "Entrypoint"
            case labels = "Labels"
            case workingDir = "WorkingDir"
            case user = "User"
        }
    }

    let config: Config
    let repoDigests: [String]?
    let size: Int?

    enum CodingKeys: String, CodingKey {
        case config = "Config"
        case repoDigests = "RepoDigests"
        case size = "Size"
    }

    /// A locally built image has no repo digests; anything pulled from a registry keeps at
    /// least one, which makes this the reliable "can we re-pull it?" signal.
    var isRegistryResolvable: Bool {
        repoDigests?.isEmpty == false
    }
}
