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

    func data(for arguments: [String], input: Data?) async throws -> Data {
        let result = try await ProcessInvocation(executableURL: try binaryURL(), arguments: arguments, input: input).run()
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

    /// Locates the `container` binary for PRIVILEGED (root) execution. Unlike the unprivileged lookup this
    /// ignores the inherited `$PATH` (which a same-user process can poison) and only accepts a binary in a
    /// trusted system directory whose file and parent directory are root-owned and not writable by group
    /// or others — so the GUI never runs an attacker-replaceable binary as root.
    nonisolated static func locateBinary(privileged: Bool) -> URL? {
        guard privileged else { return locateBinary() }
        let trusted = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin"]
        let fileManager = FileManager.default
        for directory in trusted {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("container")
            guard fileManager.isExecutableFile(atPath: candidate.path) else { continue }
            if isTrustedForRoot(candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private nonisolated static func isTrustedForRoot(_ path: String) -> Bool {
        func rootOwnedNotWritable(_ target: String) -> Bool {
            var info = stat()
            guard lstat(target, &info) == 0 else { return false }
            let groupOrOtherWritable = (info.st_mode & mode_t(S_IWGRP | S_IWOTH)) != 0
            return info.st_uid == 0 && !groupOrOtherWritable
        }
        let parent = (path as NSString).deletingLastPathComponent
        return rootOwnedNotWritable(path) && rootOwnedNotWritable(parent)
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
