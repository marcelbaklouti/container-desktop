import Foundation
import Observation

nonisolated enum ContainerTransition: Sendable, Equatable {
    case starting
    case stopping
    case restarting

    func isSatisfied(by state: String) -> Bool {
        switch self {
        case .starting, .restarting: state == "running"
        case .stopping: state != "running"
        }
    }
}

@Observable
@MainActor
final class ContainerStore {
    private(set) var containers: [Container] = []
    private(set) var hasLoaded = false
    var errorMessage: String?
    private(set) var recentlyManaged: Set<String> = []
    private(set) var pendingTransitions: [String: ContainerTransition] = [:]
    private var transitionDeadlines: [String: ContinuousClock.Instant] = [:]

    private let client: any RuntimeClient
    private let transitionTimeout: Duration

    init(client: any RuntimeClient = ContainerCLI(), transitionTimeout: Duration = .seconds(30)) {
        self.client = client
        self.transitionTimeout = transitionTimeout
    }

    /// `surfacingErrors` is only set by an explicit user refresh; the background poll leaves
    /// `errorMessage` untouched so a transient read failure can't re-present (or clobber) the
    /// modal alert every few seconds.
    func refresh(surfacingErrors: Bool = false) async {
        do {
            let updated = try await client.decode([Container].self, from: ["ls", "--all", "--format", "json"])
            if updated != containers {
                containers = updated
            }
            if surfacingErrors { errorMessage = nil }
        } catch {
            if surfacingErrors { errorMessage = Self.describe(error) }
        }
        reconcileTransitions()
        hasLoaded = true
    }

    /// Optimistic lifecycle state: rows show Starting…/Stopping… immediately, and the badge
    /// settles once the poll observes the target state (or the 30s deadline passes).
    private func beginTransition(_ id: String, _ transition: ContainerTransition) {
        pendingTransitions[id] = transition
        transitionDeadlines[id] = ContinuousClock.now + transitionTimeout
    }

    private func clearTransition(_ id: String) {
        pendingTransitions.removeValue(forKey: id)
        transitionDeadlines.removeValue(forKey: id)
    }

    private func reconcileTransitions() {
        guard !pendingTransitions.isEmpty else { return }
        let statesByID = Dictionary(uniqueKeysWithValues: containers.map { ($0.id, $0.status?.state ?? "stopped") })
        for (id, transition) in pendingTransitions {
            guard let state = statesByID[id] else {
                clearTransition(id)
                continue
            }
            if transition.isSatisfied(by: state) {
                clearTransition(id)
            } else if let deadline = transitionDeadlines[id], deadline < ContinuousClock.now {
                clearTransition(id)
                let verb = transition == .stopping ? String(localized: "stopping") : String(localized: "starting")
                errorMessage = String(localized: "\(id) didn’t finish \(verb) — check its logs.")
            }
        }
    }

    func poll(every interval: Duration) async {
        while !Task.isCancelled {
            await refresh()
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }
        }
    }

    func start(_ container: Container) async {
        beginTransition(container.id, .starting)
        await perform(["start", container.id], transitioning: [container.id])
    }

    func stop(_ container: Container) async {
        markManaged(container.id)
        beginTransition(container.id, .stopping)
        await perform(["stop", container.id], transitioning: [container.id])
    }

    func kill(_ container: Container) async {
        markManaged(container.id)
        beginTransition(container.id, .stopping)
        await perform(["kill", container.id], transitioning: [container.id])
    }

    func delete(_ container: Container) async { await perform(["delete", container.id]) }

    func markManaged(_ id: String) { recentlyManaged.insert(id) }

    func consumeManaged(_ id: String) -> Bool {
        recentlyManaged.remove(id) != nil
    }

    func create(arguments: [String]) async throws {
        _ = try await client.data(for: arguments)
        await refresh()
    }

    func export(_ container: Container, to url: URL) async throws {
        _ = try await client.data(for: ["export", container.id, "--output", url.path])
    }

    func copyFiles(source: String, destination: String) async throws {
        _ = try await client.data(for: ["copy", source, destination])
    }

    func restart(_ container: Container) async {
        markManaged(container.id)
        beginTransition(container.id, .restarting)
        await perform(["stop", container.id], transitioning: [container.id])
        beginTransition(container.id, .restarting)
        await perform(["start", container.id], transitioning: [container.id])
    }

    // Bulk actions for multi-select and Compose groups: run all, refresh once, surface the first error.
    func start(_ ids: [String]) async {
        ids.forEach { beginTransition($0, .starting) }
        await performBulk(ids.map { ["start", $0] })
    }
    func delete(_ ids: [String]) async { await performBulk(ids.map { ["delete", $0] }) }
    func stop(_ ids: [String]) async {
        ids.forEach { markManaged($0); beginTransition($0, .stopping) }
        await performBulk(ids.map { ["stop", $0] })
    }
    func restart(_ ids: [String]) async {
        ids.forEach { markManaged($0); beginTransition($0, .restarting) }
        await performBulk(ids.flatMap { [["stop", $0], ["start", $0]] })
    }

    private func performBulk(_ commands: [[String]]) async {
        var firstError: String?
        for command in commands {
            do { _ = try await client.data(for: command) }
            catch {
                if let id = command.last { clearTransition(id) }
                if firstError == nil { firstError = Self.describe(error) }
            }
        }
        if let firstError { errorMessage = firstError }
        await refresh()
    }

    private func perform(_ arguments: [String], transitioning ids: [String] = []) async {
        do {
            _ = try await client.data(for: arguments)
            await refresh()
        } catch {
            ids.forEach { clearTransition($0) }
            errorMessage = Self.describe(error)
        }
    }

    private nonisolated static func describe(_ error: any Error) -> String {
        (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
    }
}
