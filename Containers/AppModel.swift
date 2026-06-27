import Foundation
import Observation

@Observable
@MainActor
final class AppModel {
    let system = SystemController()
    let containers = ContainerStore()
    let stats = ContainerStatsStore()

    private var pollTask: Task<Void, Never>?
    private var previousStates: [String: String] = [:]
    private var wasDaemonRunning = false

    init() {
        UserDefaults.standard.register(defaults: ["notifyExits": true, "notifyDaemon": true])
    }

    var runningContainers: [Container] {
        containers.containers.filter { $0.status?.state == "running" }
    }

    var runningCount: Int { runningContainers.count }

    var daemonRunning: Bool {
        if case .running = system.state { return true }
        return false
    }

    func startPolling(every interval: Duration = .seconds(3)) {
        guard pollTask == nil else { return }
        stats.start()
        pollTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self else { return }
                await self.containers.refresh()
                if tick.isMultiple(of: 3) { await self.system.refresh() }
                self.processTransitions()
                tick += 1
                do { try await Task.sleep(for: interval) } catch { return }
            }
        }
    }

    private func processTransitions() {
        if UserDefaults.standard.bool(forKey: "notifyDaemon"), wasDaemonRunning, !daemonRunning {
            Notifier.post(
                title: String(localized: "Container daemon stopped"),
                body: String(localized: "The container runtime is no longer running.")
            )
        }
        wasDaemonRunning = daemonRunning

        var current: [String: String] = [:]
        for container in containers.containers {
            current[container.id] = container.status?.state ?? "stopped"
        }

        let notifyExits = UserDefaults.standard.bool(forKey: "notifyExits")
        for (id, previousState) in previousStates where previousState == "running" {
            guard let nowState = current[id], nowState != "running" else { continue }
            if containers.consumeManaged(id) { continue }
            if notifyExits {
                Notifier.post(
                    title: String(localized: "Container exited"),
                    body: String(localized: "\(id) is no longer running.")
                )
            }
        }
        for (id, state) in current where state == "running" {
            _ = containers.consumeManaged(id)
        }
        previousStates = current
    }
}
