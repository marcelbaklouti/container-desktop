import Foundation
import Observation

@Observable
@MainActor
final class MachineStore {
    private(set) var machines: [Machine] = []
    private(set) var hasLoaded = false
    var issue: RuntimeIssue?
    private(set) var pendingStops: Set<String> = []
    private var stopDeadlines: [String: ContinuousClock.Instant] = [:]

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func refresh(surfacingErrors: Bool = false) async {
        do {
            let updated = try await client.decode([Machine].self, from: ["machine", "ls", "--format", "json"])
            if updated != machines {
                machines = updated
            }
            if surfacingErrors { issue = nil }
        } catch {
            if surfacingErrors { issue = IssueMapper.issue(for: error, context: .generic(actionTitle: String(localized: "Couldn’t Refresh Machines"))) }
        }
        reconcileStops()
        hasLoaded = true
    }

    private func reconcileStops() {
        for id in pendingStops {
            guard let machine = machines.first(where: { $0.id == id }) else {
                clearStop(id)
                continue
            }
            if !machine.isRunning {
                clearStop(id)
            } else if let deadline = stopDeadlines[id], deadline < ContinuousClock.now {
                clearStop(id)
                issue = .plain(
                    title: String(localized: "“\(id)” Didn’t Respond"),
                    reason: String(localized: "It didn’t finish stopping.")
                )
            }
        }
    }

    private func clearStop(_ id: String) {
        pendingStops.remove(id)
        stopDeadlines.removeValue(forKey: id)
    }

    func poll(every interval: Duration) async {
        while !Task.isCancelled {
            await refresh()
            do { try await Task.sleep(for: interval) } catch { return }
        }
    }

    func create(image: String, name: String, cpus: String, memory: String, homeMount: String, setDefault: Bool) async throws {
        var arguments = ["machine", "create"]
        if !name.isEmpty { arguments += ["--name", name] }
        if setDefault { arguments.append("--set-default") }
        if !cpus.isEmpty { arguments += ["--cpus", cpus] }
        if !memory.isEmpty { arguments += ["--memory", memory] }
        if !homeMount.isEmpty { arguments += ["--home-mount", homeMount] }
        arguments.append(image)
        _ = try await client.data(for: arguments)
        await refresh()
    }

    func reconfigure(_ machine: Machine, cpus: String, memory: String, homeMount: String) async throws {
        var arguments = ["machine", "set", "--name", machine.id]
        if !cpus.isEmpty { arguments.append("cpus=\(cpus)") }
        if !memory.isEmpty { arguments.append("memory=\(memory)") }
        if !homeMount.isEmpty { arguments.append("home-mount=\(homeMount)") }
        _ = try await client.data(for: arguments)
        await refresh()
    }

    func setDefault(_ machine: Machine) async {
        await perform(["machine", "set-default", machine.id], context: .generic(actionTitle: String(localized: "Couldn’t Set the Default Machine")))
    }

    func stop(_ machine: Machine) async {
        pendingStops.insert(machine.id)
        stopDeadlines[machine.id] = ContinuousClock.now + .seconds(30)
        await perform(["machine", "stop", machine.id], stopping: machine.id, context: .generic(actionTitle: String(localized: "Couldn’t Stop the Machine")))
    }

    func delete(_ machine: Machine) async {
        await perform(["machine", "delete", machine.id], context: .generic(actionTitle: String(localized: "Couldn’t Delete the Machine")))
    }

    func delete(_ ids: [String]) async {
        await performBulk(ids.map { ["machine", "delete", $0] }) { _ in
            .generic(actionTitle: String(localized: "Couldn’t Delete the Machine"))
        }
    }

    private func performBulk(_ commands: [[String]], context: (String) -> IssueMapper.Context) async {
        var firstIssue: RuntimeIssue?
        for command in commands {
            do { _ = try await client.data(for: command) }
            catch {
                if firstIssue == nil { firstIssue = IssueMapper.issue(for: error, context: context(command.last ?? "")) }
            }
        }
        if let firstIssue { issue = firstIssue }
        await refresh()
    }

    private func perform(_ arguments: [String], stopping id: String? = nil, context: IssueMapper.Context) async {
        do {
            _ = try await client.data(for: arguments)
            await refresh()
        } catch {
            if let id { clearStop(id) }
            issue = IssueMapper.issue(for: error, context: context)
        }
    }
}
