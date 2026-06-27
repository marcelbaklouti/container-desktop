import Foundation

nonisolated enum ImageName {
    /// Shortens a fully-qualified image reference for display by dropping the
    /// default `docker.io/` registry and the `library/` namespace of official
    /// images. Other registries (ghcr.io, quay.io, …) are kept intact.
    static func short(_ reference: String) -> String {
        var result = reference
        if result.hasPrefix("docker.io/") {
            result.removeFirst("docker.io/".count)
            if result.hasPrefix("library/") {
                result.removeFirst("library/".count)
            }
        }
        return result
    }
}
