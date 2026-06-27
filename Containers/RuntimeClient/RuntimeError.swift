import Foundation

nonisolated enum RuntimeError: Error, Sendable, Equatable {
    case binaryNotFound
    case daemonNotRunning
    case commandFailed(arguments: [String], exitCode: Int32, message: String)
    case decodingFailed(arguments: [String], message: String)

    var localizedMessage: String {
        switch self {
        case .binaryNotFound:
            String(localized: "The container tool could not be found.")
        case .daemonNotRunning:
            String(localized: "The container system is not running.")
        case let .commandFailed(_, _, message):
            message.isEmpty ? String(localized: "The container command failed.") : message
        case let .decodingFailed(_, message):
            message
        }
    }
}
