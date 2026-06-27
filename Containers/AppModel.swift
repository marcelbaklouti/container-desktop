import AppKit
import Observation

@Observable
@MainActor
final class AppModel {
    let system = SystemController()
    let containers = ContainerStore()
    let stats = ContainerStatsStore()

    private var pollTask: Task<Void, Never>?

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
                self.updateDockBadge()
                tick += 1
                do { try await Task.sleep(for: interval) } catch { return }
            }
        }
    }

    private func updateDockBadge() {
        let count = runningCount
        NSApp.dockTile.badgeLabel = count > 0 ? String(count) : nil
    }
}
