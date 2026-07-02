import Foundation
import Observation

@Observable
@MainActor
final class SystemController {
    nonisolated enum RuntimeState: Sendable, Equatable {
        case unknown
        case binaryMissing
        case daemonStopped
        case running(version: String)
    }

    nonisolated enum DaemonTransition: Sendable, Equatable {
        case starting
        case stopping
    }

    private(set) var state: RuntimeState = .unknown
    private(set) var transition: DaemonTransition?
    private(set) var status: SystemStatus?
    private(set) var diskUsage: DiskUsage?
    private(set) var cliVersion: String?
    private(set) var versionWarning: String?

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func refresh() async {
        do {
            let output = try await client.data(for: ["--version"])
            cliVersion = Self.parseVersion(String(decoding: output, as: UTF8.self))
        } catch RuntimeError.binaryNotFound {
            state = .binaryMissing
            status = nil
            diskUsage = nil
            versionWarning = nil
            return
        } catch {
            cliVersion = nil
        }

        do {
            let systemStatus = try await client.decode(SystemStatus.self, from: ["system", "status", "--format", "json"])
            status = systemStatus
            if systemStatus.isRunning {
                state = .running(version: cliVersion ?? "unknown")
                evaluateCompatibility(apiServerVersion: systemStatus.apiServerVersion)
                await refreshDiskUsage()
            } else {
                state = .daemonStopped
                diskUsage = nil
                versionWarning = nil
            }
        } catch RuntimeError.binaryNotFound {
            state = .binaryMissing
            status = nil
            diskUsage = nil
            versionWarning = nil
        } catch RuntimeError.daemonNotRunning {
            state = .daemonStopped
            status = nil
            diskUsage = nil
            versionWarning = nil
        } catch {
            state = .daemonStopped
            status = nil
            diskUsage = nil
        }
    }

    /// `system start` returns while the daemon is still booting, so poll until it reports
    /// running before declaring success — surfacing an error any earlier is a false alarm.
    func start() async throws {
        transition = .starting
        defer { transition = nil }
        _ = try await client.data(for: ["system", "start"])
        let deadline = ContinuousClock.now + .seconds(15)
        while ContinuousClock.now < deadline {
            await refresh()
            if case .running = state { return }
            try await Task.sleep(for: .milliseconds(500))
        }
        await refresh()
        if case .running = state { return }
        throw RuntimeError.commandFailed(
            arguments: ["system", "start"],
            exitCode: 0,
            message: String(localized: "The container system didn’t report ready in time.")
        )
    }

    func stop() async throws {
        transition = .stopping
        defer { transition = nil }
        _ = try await client.data(for: ["system", "stop"])
        let deadline = ContinuousClock.now + .seconds(5)
        while ContinuousClock.now < deadline {
            await refresh()
            guard case .running = state else { return }
            try await Task.sleep(for: .milliseconds(500))
        }
        await refresh()
    }

    private func refreshDiskUsage() async {
        diskUsage = try? await client.decode(DiskUsage.self, from: ["system", "df", "--format", "json"])
    }

    private func evaluateCompatibility(apiServerVersion: String?) {
        guard let cliVersion,
              let apiServerVersion,
              let apiVersion = Self.parseVersion(apiServerVersion) else {
            versionWarning = nil
            return
        }
        let cliMajorMinor = cliVersion.split(separator: ".").prefix(2).joined(separator: ".")
        let apiMajorMinor = apiVersion.split(separator: ".").prefix(2).joined(separator: ".")
        versionWarning = cliMajorMinor == apiMajorMinor
            ? nil
            : "Installed CLI \(cliVersion) and apiserver \(apiVersion) differ; some actions may misbehave."
    }

    private nonisolated static func parseVersion(_ text: String) -> String? {
        guard let match = text.firstMatch(of: /\d+\.\d+\.\d+/) else {
            return nil
        }
        return String(match.output)
    }
}
