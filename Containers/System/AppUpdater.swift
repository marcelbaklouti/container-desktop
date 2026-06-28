import AppKit
import Observation

@Observable
@MainActor
final class AppUpdater {
    /// The public GitHub repository (owner/name) that hosts Container Desktop releases.
    /// Releases must be tagged with the version (e.g. `1.1.0` or `v1.1.0`) and attach the notarized `.dmg`.
    static let repository = "marcelbaklouti/container-desktop"

    enum Phase: Equatable {
        case idle
        case checking
        case downloading(Double)
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
            // Open the disk image so the user can drag the new app to Applications (Developer ID + notarized).
            NSWorkspace.shared.open(dmg)
            phase = .idle
        } catch {
            phase = .failed((error as? RuntimeError)?.localizedMessage ?? error.localizedDescription)
        }
    }
}
