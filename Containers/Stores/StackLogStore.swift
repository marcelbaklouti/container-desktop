import Foundation
import Observation

/// Multiplexes one `container logs` stream per stack member into a single shared buffer.
/// Streams run only while a combined-logs surface is visible: the owning view calls
/// `setMembers` as the stack changes and `stop()` on disappear, so no subprocess outlives it.
@Observable
@MainActor
final class StackLogStore {
    let buffer: LogBuffer
    private(set) var serviceColorIndex: [String: Int] = [:]

    nonisolated struct Member: Equatable, Sendable {
        let id: String
        let service: String
        let isRunning: Bool
    }

    private var tasks: [String: Task<Void, Never>] = [:]
    private var memberStates: [String: Bool] = [:]
    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI(), buffer: LogBuffer = LogBuffer()) {
        self.client = client
        self.buffer = buffer
    }

    func setMembers(_ members: [Member]) {
        let currentIDs = Set(members.map(\.id))
        for (id, task) in tasks where !currentIDs.contains(id) {
            task.cancel()
            tasks[id] = nil
            memberStates[id] = nil
        }

        let services = Set(members.map(\.service)).sorted()
        serviceColorIndex = Dictionary(uniqueKeysWithValues: services.enumerated().map { ($0.element, $0.offset) })

        for member in members {
            if let previous = memberStates[member.id], previous == member.isRunning { continue }
            tasks[member.id]?.cancel()
            memberStates[member.id] = member.isRunning
            start(member)
        }
    }

    func stop() {
        for task in tasks.values { task.cancel() }
        tasks = [:]
        memberStates = [:]
    }

    func clear() {
        buffer.clear()
    }

    private func start(_ member: Member) {
        tasks[member.id] = Task { [weak self] in
            guard let self else { return }
            do {
                do {
                    try await self.consume(self.arguments(for: member, withTail: true), service: member.service)
                } catch let error as RuntimeError {
                    guard case .commandFailed = error, !Task.isCancelled else { throw error }
                    try await self.consume(self.arguments(for: member, withTail: false), service: member.service)
                }
                if member.isRunning, !Task.isCancelled {
                    self.buffer.append(String(localized: "— log stream ended"), prefix: member.service)
                    self.buffer.flushNow()
                }
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled {
                    let message = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
                    self.buffer.append(String(localized: "— \(message)"), prefix: member.service)
                    self.buffer.flushNow()
                }
            }
            self.buffer.flushNow()
        }
    }

    private nonisolated func arguments(for member: Member, withTail: Bool) -> [String] {
        var arguments = ["logs"]
        if member.isRunning { arguments.append("--follow") }
        if withTail { arguments += ["-n", "200"] }
        arguments.append(member.id)
        return arguments
    }

    private func consume(_ arguments: [String], service: String) async throws {
        let output = try await client.lines(for: arguments)
        for try await line in output {
            buffer.append(line, prefix: service)
        }
    }
}
