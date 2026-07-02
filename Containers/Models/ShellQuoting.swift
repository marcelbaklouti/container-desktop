import Foundation

nonisolated enum ShellQuoting {
    /// POSIX-safe single quoting: wrap in single quotes, replacing every embedded single quote
    /// with `'\''`. Used verbatim for privileged execution, where quoting must never be skipped.
    static func alwaysQuoted(_ word: String) -> String {
        "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Human-readable quoting for commands shown to or copied for the user: safe words stay bare,
    /// everything else falls back to strict single-quoting.
    static func quoted(_ word: String) -> String {
        guard !word.isEmpty else { return "''" }
        let safe = word.allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber || "@%_+=:,./-".contains(character))
        }
        return safe ? word : alwaysQuoted(word)
    }

    static func joined(_ argv: [String]) -> String {
        argv.map(quoted).joined(separator: " ")
    }
}
