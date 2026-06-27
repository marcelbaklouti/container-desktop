import Foundation

nonisolated protocol RuntimeClient: Sendable {
    func data(for arguments: [String]) async throws -> Data
    func decode<Value>(_ type: Value.Type, from arguments: [String]) async throws -> Value where Value: Decodable & Sendable
    func lines(for arguments: [String]) async throws -> AsyncThrowingStream<String, any Error>
}
