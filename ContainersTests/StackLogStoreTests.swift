import Testing
import Foundation
@testable import Containers

private final class ScriptedLogClient: RuntimeClient, @unchecked Sendable {
    private let lock = NSLock()
    private var scripts: [String: [String]] = [:]
    private var failTailFor: Set<String> = []
    private(set) var requestedArguments: [[String]] = []

    func script(_ id: String, lines: [String]) {
        lock.withLock { scripts[id] = lines }
    }

    func failTail(for id: String) {
        lock.withLock { _ = failTailFor.insert(id) }
    }

    func data(for arguments: [String], input: Data?) async throws -> Data {
        Data()
    }

    func decode<Value>(_ type: Value.Type, from arguments: [String]) async throws -> Value where Value: Decodable & Sendable {
        throw RuntimeError.decodingFailed(arguments: arguments, message: "unscripted")
    }

    func lines(for arguments: [String]) async throws -> AsyncThrowingStream<String, any Error> {
        let (id, hasTail, shouldFailTail, lines): (String, Bool, Bool, [String]) = lock.withLock {
            requestedArguments.append(arguments)
            let id = arguments.last ?? ""
            let hasTail = arguments.contains("-n")
            return (id, hasTail, failTailFor.contains(id), scripts[id] ?? [])
        }
        if hasTail && shouldFailTail {
            throw RuntimeError.commandFailed(arguments: arguments, exitCode: 1, message: "tail unsupported")
        }
        _ = id
        return AsyncThrowingStream { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }
    }
}

@MainActor
struct StackLogStoreTests {

    @Test func mergesMemberStreamsWithServicePrefixes() async throws {
        let client = ScriptedLogClient()
        client.script("web-1", lines: ["hello from web"])
        client.script("db-1", lines: ["hello from db"])
        let store = StackLogStore(client: client, buffer: LogBuffer(capacity: 100, flushInterval: .milliseconds(1)))

        store.setMembers([
            .init(id: "web-1", service: "web", isRunning: true),
            .init(id: "db-1", service: "db", isRunning: true),
        ])
        try await Task.sleep(for: .milliseconds(80))

        let texts = store.buffer.entries
        #expect(texts.contains { $0.prefix == "web" && $0.text == "hello from web" })
        #expect(texts.contains { $0.prefix == "db" && $0.text == "hello from db" })
        #expect(texts.contains { $0.prefix == "web" && $0.text.contains("log stream ended") })
        store.stop()
    }

    @Test func colorIndexesAreStableBySortedServiceName() async throws {
        let store = StackLogStore(client: ScriptedLogClient(), buffer: LogBuffer(capacity: 10, flushInterval: .milliseconds(1)))
        store.setMembers([
            .init(id: "1", service: "zeta", isRunning: false),
            .init(id: "2", service: "alpha", isRunning: false),
        ])
        #expect(store.serviceColorIndex["alpha"] == 0)
        #expect(store.serviceColorIndex["zeta"] == 1)
        store.setMembers([
            .init(id: "2", service: "alpha", isRunning: false),
            .init(id: "1", service: "zeta", isRunning: false),
        ])
        #expect(store.serviceColorIndex["alpha"] == 0)
        store.stop()
    }

    @Test func fallsBackWithoutTailWhenTailRejected() async throws {
        let client = ScriptedLogClient()
        client.script("svc-1", lines: ["after fallback"])
        client.failTail(for: "svc-1")
        let store = StackLogStore(client: client, buffer: LogBuffer(capacity: 10, flushInterval: .milliseconds(1)))

        store.setMembers([.init(id: "svc-1", service: "svc", isRunning: false)])
        try await Task.sleep(for: .milliseconds(80))

        #expect(store.buffer.entries.contains { $0.text == "after fallback" })
        store.stop()
    }

    @Test func stateChangeRestartsStreamAndRemovalCancels() async throws {
        let client = ScriptedLogClient()
        client.script("app-1", lines: ["run one"])
        let store = StackLogStore(client: client, buffer: LogBuffer(capacity: 100, flushInterval: .milliseconds(1)))

        store.setMembers([.init(id: "app-1", service: "app", isRunning: false)])
        try await Task.sleep(for: .milliseconds(50))
        let firstCount = client.requestedArguments.count
        #expect(firstCount == 1)

        store.setMembers([.init(id: "app-1", service: "app", isRunning: false)])
        try await Task.sleep(for: .milliseconds(30))
        #expect(client.requestedArguments.count == firstCount)

        store.setMembers([.init(id: "app-1", service: "app", isRunning: true)])
        try await Task.sleep(for: .milliseconds(50))
        #expect(client.requestedArguments.count == firstCount + 1)
        #expect(client.requestedArguments.last?.contains("--follow") == true)

        store.setMembers([])
        try await Task.sleep(for: .milliseconds(30))
        store.setMembers([.init(id: "app-1", service: "app", isRunning: true)])
        try await Task.sleep(for: .milliseconds(50))
        #expect(client.requestedArguments.count == firstCount + 2)
        store.stop()
    }
}
