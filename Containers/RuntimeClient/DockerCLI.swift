import Foundation

nonisolated enum DockerError: Error, Sendable, Equatable {
    case notInstalled
    case daemonNotRunning
    case commandFailed(arguments: [String], exitCode: Int32, message: String)

    var localizedMessage: String {
        switch self {
        case .notInstalled:
            String(localized: "Docker isn’t installed.")
        case .daemonNotRunning:
            String(localized: "Docker is installed but not running — start Docker Desktop, then try again.")
        case let .commandFailed(_, _, message):
            message.isEmpty ? String(localized: "The docker command failed.") : message
        }
    }
}

nonisolated enum DockerAvailability: Sendable, Equatable {
    case notInstalled
    case daemonStopped
    case ready
}

/// A deliberately separate actor from ContainerCLI: Docker lives in different places
/// (including Docker Desktop's ~/.docker/bin), speaks a different error vocabulary, and is
/// only ever consumed by the migration feature.
actor DockerCLI {
    nonisolated static var defaultSearchDirectories: [String] {
        var directories = ["/usr/local/bin", "/opt/homebrew/bin"]
        directories.append((NSHomeDirectory() as NSString).appendingPathComponent(".docker/bin"))
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            directories.append(contentsOf: path.split(separator: ":").map(String.init))
        }
        return directories
    }

    private let searchDirectories: [String]
    private var cachedBinary: URL?

    init(searchDirectories: [String] = DockerCLI.defaultSearchDirectories) {
        self.searchDirectories = searchDirectories
    }

    nonisolated static func locateBinary(in directories: [String] = defaultSearchDirectories) -> URL? {
        for directory in directories {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("docker")
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    func availability() async -> DockerAvailability {
        guard binaryURL() != nil else { return .notInstalled }
        do {
            _ = try await data(for: ["info", "--format", "{{.ServerVersion}}"])
            return .ready
        } catch {
            return .daemonStopped
        }
    }

    /// GUI apps inherit a minimal PATH, but docker shells out to credential helpers like
    /// docker-credential-desktop (Docker.app's Resources/bin, ~/.docker/bin) for every pull —
    /// without these directories on PATH, any docker pull fails with "error getting credentials".
    nonisolated static var subprocessEnvironment: [String: String] {
        var directories = [
            "/Applications/Docker.app/Contents/Resources/bin",
            (NSHomeDirectory() as NSString).appendingPathComponent(".docker/bin"),
            "/usr/local/bin",
            "/opt/homebrew/bin",
        ]
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            directories.append(contentsOf: path.split(separator: ":").map(String.init))
        }
        var seen = Set<String>()
        let merged = directories.filter { seen.insert($0).inserted }
        return ["PATH": merged.joined(separator: ":")]
    }

    func data(for arguments: [String]) async throws -> Data {
        guard let binary = binaryURL() else { throw DockerError.notInstalled }
        let result: ProcessResult
        do {
            result = try await ProcessInvocation(executableURL: binary, arguments: arguments, environment: Self.subprocessEnvironment).run()
        } catch RuntimeError.binaryNotFound {
            throw DockerError.notInstalled
        }
        guard result.exitCode == 0 else {
            let stderr = String(decoding: result.standardError, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if stderr.contains("Cannot connect to the Docker daemon") || stderr.contains("Is the docker daemon running") {
                throw DockerError.daemonNotRunning
            }
            throw DockerError.commandFailed(arguments: arguments, exitCode: result.exitCode, message: stderr)
        }
        return result.standardOutput
    }

    func decode<Value>(_ type: Value.Type, from arguments: [String]) async throws -> Value where Value: Decodable & Sendable {
        let data = try await data(for: arguments)
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            throw DockerError.commandFailed(arguments: arguments, exitCode: 0, message: String(localized: "Couldn’t read Docker’s response."))
        }
    }

    private func binaryURL() -> URL? {
        if let cachedBinary { return cachedBinary }
        cachedBinary = Self.locateBinary(in: searchDirectories)
        return cachedBinary
    }
}
