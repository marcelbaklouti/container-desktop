import Foundation

nonisolated enum PrivilegedRunner {
    static func run(_ arguments: [String]) async throws {
        guard let binary = ContainerCLI.locateBinary() else {
            throw RuntimeError.binaryNotFound
        }
        try await runCommand([binary.path] + arguments)
    }

    /// Runs an arbitrary command (absolute executable path + arguments) with administrator privileges.
    static func runCommand(_ command: [String]) async throws {
        let shellCommand = command.map { "'\($0)'" }.joined(separator: " ")
        let appleScript = "do shell script \"\(shellCommand)\" with administrator privileges"
        let invocation = ProcessInvocation(
            executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", appleScript]
        )
        let result = try await invocation.run()
        guard result.exitCode == 0 else {
            let message = String(decoding: result.standardError, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if message.contains("-128") || message.localizedCaseInsensitiveContains("cancel") {
                throw CancellationError()
            }
            throw RuntimeError.commandFailed(arguments: command, exitCode: result.exitCode, message: message)
        }
    }
}
