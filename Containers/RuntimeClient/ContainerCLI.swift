import Foundation

actor ContainerCLI: RuntimeClient {
    private let searchDirectories: [String]
    private var cachedBinary: URL?

    init(searchDirectories: [String] = ContainerCLI.defaultSearchDirectories) {
        self.searchDirectories = searchDirectories
    }

    nonisolated static var defaultSearchDirectories: [String] {
        var directories = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin"]
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            directories.append(contentsOf: path.split(separator: ":").map(String.init))
        }
        return directories
    }

    func data(for arguments: [String]) async throws -> Data {
        let result = try await invocation(for: arguments).run()
        guard result.exitCode == 0 else {
            throw ContainerCLI.failure(arguments: arguments, result: result)
        }
        return result.standardOutput
    }

    func decode<Value>(_ type: Value.Type, from arguments: [String]) async throws -> Value where Value: Decodable & Sendable {
        let payload = try await data(for: arguments)
        do {
            return try JSONDecoder().decode(Value.self, from: payload)
        } catch {
            throw RuntimeError.decodingFailed(arguments: arguments, message: String(describing: error))
        }
    }

    func lines(for arguments: [String]) async throws -> AsyncThrowingStream<String, any Error> {
        try invocation(for: arguments).stream()
    }

    private func invocation(for arguments: [String]) throws -> ProcessInvocation {
        ProcessInvocation(executableURL: try binaryURL(), arguments: arguments)
    }

    nonisolated static func locateBinary(in directories: [String] = ContainerCLI.defaultSearchDirectories) -> URL? {
        let fileManager = FileManager.default
        for directory in directories {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("container")
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private func binaryURL() throws -> URL {
        if let cachedBinary {
            return cachedBinary
        }
        guard let url = ContainerCLI.locateBinary(in: searchDirectories) else {
            throw RuntimeError.binaryNotFound
        }
        cachedBinary = url
        return url
    }

    private nonisolated static func failure(arguments: [String], result: ProcessResult) -> RuntimeError {
        let message = String(decoding: result.standardError, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if message.contains("XPC connection error") || message.contains("system service has been started") {
            return .daemonNotRunning
        }
        return .commandFailed(arguments: arguments, exitCode: result.exitCode, message: message)
    }
}
