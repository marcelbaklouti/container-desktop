import Foundation

nonisolated enum PrivilegedRunner {
    static func run(_ arguments: [String]) async throws {
        guard let binary = ContainerCLI.locateBinary(privileged: true) else {
            throw RuntimeError.binaryNotFound
        }
        try await runCommand([binary.path] + arguments)
    }

    /// Runs an arbitrary command (absolute executable path + arguments) with administrator privileges.
    static func runCommand(_ command: [String]) async throws {
        let invocation = ProcessInvocation(
            executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", appleScript(for: command)]
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

    /// Builds the AppleScript handed to `osascript -e`. Each argument is POSIX single-quoted so shell
    /// metacharacters and embedded quotes stay inert, then the assembled command is escaped for the
    /// AppleScript string literal. This two-layer escaping is what stops an argument value from breaking
    /// out of the quoting and executing as root.
    static func appleScript(for command: [String]) -> String {
        let shellCommand = command.map(posixQuoted).joined(separator: " ")
        return "do shell script \"\(appleScriptEscaped(shellCommand))\" with administrator privileges"
    }

    /// POSIX-safe single quoting: wrap in single quotes, replacing every embedded single quote with the
    /// sequence `'\''` (close quote, escaped literal quote, reopen quote).
    static func posixQuoted(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Escapes a string for inclusion inside an AppleScript double-quoted literal (backslash first, then
    /// double quote — order matters).
    private static func appleScriptEscaped(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
