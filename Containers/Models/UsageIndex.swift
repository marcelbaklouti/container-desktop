import Foundation

/// Cross-references between resources and the containers using them, derived from the shared
/// container list — the single source both the inspectors and the delete confirmations read.
nonisolated enum UsageIndex {
    static func containersMounting(_ volumeName: String, in containers: [Container]) -> [Container] {
        containers.filter { container in
            container.configuration.mounts.contains { $0.type.volume?.name == volumeName }
        }
    }

    static func containersAttached(_ networkName: String, in containers: [Container]) -> [Container] {
        containers.filter { container in
            container.configuration.networks.contains { $0.network == networkName }
        }
    }
}
