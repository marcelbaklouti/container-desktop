import Foundation

nonisolated enum RuntimeError: Error, Sendable, Equatable {
    case binaryNotFound
    case daemonNotRunning
    case commandFailed(arguments: [String], exitCode: Int32, message: String)
    case decodingFailed(arguments: [String], message: String)
}
