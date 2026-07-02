import Foundation
import Observation

@Observable
@MainActor
final class Navigator {
    var area: Area? = .containers
    var containerSelection: Set<String> = []
}

@Observable
@MainActor
final class AppModel {
    let system = SystemController()
    let containers = ContainerStore()
    let stats = ContainerStatsStore()
    let installer: ContainerInstaller
    let updater = AppUpdater()
    let navigator = Navigator()

    private var pollTask: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?
    private var previousStates: [String: String] = [:]
    private var wasDaemonRunning = false

    init() {
        installer = ContainerInstaller(system: system)
        UserDefaults.standard.register(defaults: [
            "notifyExits": true,
            "notifyDaemon": true,
            "notifyUpdates": true,
            "autoDownloadUpdates": true,
        ])
    }

    var runningContainers: [Container] {
        containers.containers.filter { $0.status?.state == "running" }
    }

    var runningCount: Int { runningContainers.count }

    var daemonRunning: Bool {
        if case .running = system.state { return true }
        return false
    }

    /// Checks for an app update on launch and daily after that: notify once per version, stage
    /// the download in the background when allowed, and wait for the user to restart — nothing
    /// ever quits the app on its own.
    func startUpdateCycle() {
        guard updateTask == nil else { return }
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.runUpdatePass()
                try? await Task.sleep(for: .seconds(24 * 3600))
            }
        }
    }

    private func runUpdatePass() async {
        await updater.checkForUpdates()
        guard updater.isUpdateAvailable, let version = updater.latestVersion else { return }
        let defaults = UserDefaults.standard
        let notify = defaults.bool(forKey: "notifyUpdates")
        let autoDownload = defaults.bool(forKey: "autoDownloadUpdates")

        if autoDownload, case .idle = updater.phase {
            await updater.stageUpdate()
        }

        guard notify else { return }
        if case .readyToInstall(let staged) = updater.phase {
            if defaults.string(forKey: "notifiedStagedVersion") != staged {
                defaults.set(staged, forKey: "notifiedStagedVersion")
                Notifier.post(
                    title: String(localized: "Update ready to install"),
                    body: String(localized: "Restart Container Desktop to update to \(staged).")
                )
            }
        } else if defaults.string(forKey: "notifiedAvailableVersion") != version {
            defaults.set(version, forKey: "notifiedAvailableVersion")
            Notifier.post(
                title: String(localized: "Update available"),
                body: String(localized: "Container Desktop \(version) is available to download.")
            )
        }
    }

    func perform(_ remedy: RuntimeIssue.Remedy) async {
        switch remedy {
        case let .stopContainers(ids):
            await containers.stop(ids)
        case let .stopAndDeleteContainer(id):
            await containers.stop([id])
            await containers.delete([id])
        case let .revealContainers(ids):
            navigator.area = .containers
            if !ids.isEmpty { navigator.containerSelection = Set(ids) }
        case .startDaemon:
            try? await system.start()
        case .none:
            break
        }
    }

    func startPolling(every interval: Duration = .seconds(3)) {
        guard pollTask == nil else { return }
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
