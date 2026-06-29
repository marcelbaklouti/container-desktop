import AppKit
import Observation

@Observable
@MainActor
final class AppUpdater {
    /// The public GitHub repository (owner/name) that hosts Container Desktop releases.
    /// Releases must be tagged with the version (e.g. `1.1.0` or `v1.1.0`) and attach the notarized `.dmg`.
    static let repository = "marcelbaklouti/container-desktop"

    /// The update must be signed by this Apple Developer team, as defense-in-depth on top of the
    /// TLS-pinned GitHub download and Gatekeeper notarization check.
    static let signingTeam = "YW883T2H46"

    enum Phase: Equatable {
        case idle
        case checking
        case downloading(Double)
        case installing
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var latestVersion: String?
    private var assetURL: URL?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var isUpdateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return ContainerInstaller.compare(latest, currentVersion) == .orderedDescending
    }

    var isBusy: Bool {
        switch phase {
        case .idle, .failed: false
        default: true
        }
    }

    func checkForUpdates() async {
        guard !isBusy else { return }
        phase = .checking
        defer { if case .checking = phase { phase = .idle } }

        guard let endpoint = URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest") else { return }
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            // 404 simply means no published release yet — leave the latest version unknown.
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            latestVersion = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
            assetURL = release.assets.first(where: { $0.name.hasSuffix(".dmg") })?.browserDownloadURL
        } catch {
            // A failed update check is non-fatal.
        }
    }

    func downloadUpdate() async {
        guard !isBusy else { return }
        guard let url = assetURL else {
            await checkForUpdates()
            return
        }
        guard url.host == "github.com", url.path.contains("/\(Self.repository)/") else {
            phase = .failed(String(localized: "The update came from an unexpected location and wasn’t downloaded."))
            return
        }
        phase = .downloading(0)
        do {
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent("Container Desktop.dmg")
            let dmg = try await PackageDownloader().download(from: url, to: destination) { fraction in
                Task { @MainActor in
                    if case .downloading = self.phase { self.phase = .downloading(fraction) }
                }
            }
            try await installAndRelaunch(fromDMG: dmg)
        } catch {
            phase = .failed((error as? RuntimeError)?.localizedMessage ?? error.localizedDescription)
        }
    }

    /// Mounts the downloaded DMG, copies and verifies the new app, then hands off to a detached
    /// helper that waits for this process to quit, swaps the bundle in place, and relaunches.
    private func installAndRelaunch(fromDMG dmg: URL) async throws {
        phase = .installing

        let mountPoint = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        let attach = try await run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-noverify", "-noautoopen", "-mountpoint", mountPoint.path])
        guard attach.code == 0 else {
            phase = .failed(String(localized: "Couldn’t open the downloaded update."))
            return
        }

        func detach() async { _ = try? await run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"]) }

        guard let mountedApp = ((try? FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)) ?? [])
            .first(where: { $0.pathExtension == "app" }) else {
            await detach()
            phase = .failed(String(localized: "The update didn’t contain an app."))
            return
        }

        let staging = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let stagedApp = staging.appendingPathComponent(mountedApp.lastPathComponent)
        let copy = try await run("/usr/bin/ditto", [mountedApp.path, stagedApp.path])
        await detach()
        guard copy.code == 0 else {
            phase = .failed(String(localized: "Couldn’t prepare the update."))
            return
        }

        guard try await isTrustedBuild(stagedApp) else {
            try? FileManager.default.removeItem(at: staging)
            phase = .failed(String(localized: "The update isn’t signed by the expected developer, so it wasn’t installed."))
            return
        }

        let destination = Bundle.main.bundleURL
        let parent = destination.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parent.path) else {
            // Can't replace the running app in place (e.g. not the owner) — fall back to the manual drag.
            NSWorkspace.shared.open(dmg)
            phase = .idle
            return
        }

        try launchSwapHelper(stagedApp: stagedApp, destination: destination, scriptDirectory: staging)
        NSApp.terminate(nil)
    }

    /// True only if the staged app is a valid, notarized build signed by our team.
    private func isTrustedBuild(_ app: URL) async throws -> Bool {
        let verify = try await run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        guard verify.code == 0 else { return false }
        let info = try await run("/usr/bin/codesign", ["-dvv", app.path])
        guard (info.out + info.err).contains("TeamIdentifier=\(Self.signingTeam)") else { return false }
        let assess = try await run("/usr/sbin/spctl", ["--assess", "--type", "execute", app.path])
        return assess.code == 0
    }

    private func launchSwapHelper(stagedApp: URL, destination: URL, scriptDirectory: URL) throws {
        let script = """
        #!/bin/bash
        SOURCE="$1"; DEST="$2"; PID="$3"
        while /bin/kill -0 "$PID" 2>/dev/null; do /bin/sleep 0.3; done
        /bin/sleep 0.5
        /usr/bin/ditto "$SOURCE" "$DEST.update" || exit 1
        /bin/rm -rf "$DEST"
        /bin/mv "$DEST.update" "$DEST"
        /usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null
        /usr/bin/open "$DEST"
        /bin/rm -rf "$SOURCE"
        """
        let helper = scriptDirectory.appendingPathComponent("update-helper.sh")
        try script.write(to: helper, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [helper.path, stagedApp.path, destination.path, String(ProcessInfo.processInfo.processIdentifier)]
        try task.run()
    }

    private func run(_ tool: String, _ arguments: [String]) async throws -> (code: Int32, out: String, err: String) {
        let result = try await ProcessInvocation(executableURL: URL(fileURLWithPath: tool), arguments: arguments).run()
        return (result.exitCode,
                String(decoding: result.standardOutput, as: UTF8.self),
                String(decoding: result.standardError, as: UTF8.self))
    }
}
