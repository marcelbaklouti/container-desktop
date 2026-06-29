import Foundation
import Observation

@Observable
@MainActor
final class ContainerInstaller {
    /// The `container` release this build of Container Desktop targets. Kept in lockstep with the app's
    /// marketing version so a given app release clearly pairs with a specific runtime release.
    nonisolated static let requiredVersion = "1.0.0"

    enum Phase: Equatable {
        case idle
        case checking
        case downloading(Double)
        case verifying
        case installing
        case finished
        case failed(String)
    }

    enum Availability: Equatable {
        case notInstalled
        case updateRequired(installed: String)
        case updateAvailable(latest: String)
        case upToDate
    }

    private(set) var phase: Phase = .idle
    private(set) var latestVersion: String?

    private var latestPackageURL: URL?
    private let system: SystemController

    init(system: SystemController) {
        self.system = system
    }

    var installedVersion: String? { system.cliVersion }
    var requiredVersion: String { Self.requiredVersion }

    /// The version a fresh install/update would land — the latest known release, otherwise the required one.
    var targetVersion: String { latestVersion ?? Self.requiredVersion }

    var availability: Availability {
        guard let installed = installedVersion else { return .notInstalled }
        if Self.compare(installed, Self.requiredVersion) == .orderedAscending {
            return .updateRequired(installed: installed)
        }
        if let latest = latestVersion, Self.compare(latest, installed) == .orderedDescending {
            return .updateAvailable(latest: latest)
        }
        return .upToDate
    }

    var isUpdateAvailable: Bool {
        availability != .upToDate
    }

    var isBusy: Bool {
        switch phase {
        case .idle, .finished, .failed: false
        default: true
        }
    }

    var phaseDescription: String {
        switch phase {
        case .checking: String(localized: "Checking for the latest release…")
        case .verifying: String(localized: "Verifying Apple’s signature…")
        case .installing: String(localized: "Installing…")
        default: ""
        }
    }

    func checkForUpdates() async {
        guard !isBusy else { return }
        do {
            let release = try await Self.fetchLatestRelease()
            latestVersion = release.version
            latestPackageURL = release.packageURL
        } catch {
            // A failed update check is non-fatal — leave the latest version unknown.
        }
    }

    func installOrUpdate() async {
        guard !isBusy else { return }
        do {
            let release: (version: String, packageURL: URL)
            if let url = latestPackageURL, let version = latestVersion {
                release = (version, url)
            } else {
                phase = .checking
                let fetched = try await Self.fetchLatestRelease()
                latestVersion = fetched.version
                latestPackageURL = fetched.packageURL
                release = (fetched.version, fetched.packageURL)
            }

            phase = .downloading(0)
            // Stage into a fresh, randomly-named 0700 directory so a same-user process can't pre-place or
            // race-swap the file at a predictable path.
            let staging = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: staging) }
            let packageURL = staging.appendingPathComponent("container-installer.pkg")
            let downloaded = try await PackageDownloader().download(from: release.packageURL, to: packageURL) { fraction in
                Task { @MainActor in
                    if case .downloading = self.phase { self.phase = .downloading(fraction) }
                }
            }

            phase = .verifying
            guard try await Self.verifyAppleSignature(downloaded) else {
                phase = .failed(String(localized: "The downloaded installer isn’t signed by Apple, so it wasn’t installed."))
                return
            }

            phase = .installing
            // Re-verify immediately before the privileged install to close the verify→install window.
            guard try await Self.verifyAppleSignature(downloaded) else {
                phase = .failed(String(localized: "The installer changed after verification and wasn’t installed."))
                return
            }
            try await PrivilegedRunner.runCommand(["/usr/sbin/installer", "-pkg", downloaded.path, "-target", "/"])

            await system.refresh()
            // A fresh install leaves the apiserver daemon stopped; start it so the app lands on
            // the running state instead of stranding the user on a separate "Start" step.
            if case .daemonStopped = system.state {
                try? await system.start()
            }
            phase = .finished
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed((error as? RuntimeError)?.localizedMessage ?? error.localizedDescription)
        }
    }

    // MARK: - Release lookup

    private static func fetchLatestRelease() async throws -> (version: String, packageURL: URL) {
        guard let endpoint = URL(string: "https://api.github.com/repos/apple/container/releases/latest") else {
            throw InstallerError.invalidEndpoint
        }
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard let asset = release.assets.first(where: { $0.name.hasSuffix("-installer-signed.pkg") }) else {
            throw InstallerError.noSignedPackage
        }
        // Provenance: only ever download from Apple's official repository over HTTPS.
        guard asset.browserDownloadURL.host == "github.com",
              asset.browserDownloadURL.path.contains("/apple/container/") else {
            throw InstallerError.untrustedSource
        }
        return (release.tagName, asset.browserDownloadURL)
    }

    /// Apple's "Developer ID Installer" team that signs the container runtime packages.
    private static let appleInstallerTeamID = "UPBK2H6LZM"

    private static func verifyAppleSignature(_ package: URL) async throws -> Bool {
        let invocation = ProcessInvocation(
            executableURL: URL(fileURLWithPath: "/usr/sbin/pkgutil"),
            arguments: ["--check-signature", package.path],
            environment: ["LC_ALL": "C", "LANG": "C"]
        )
        let result = try await invocation.run()
        guard result.exitCode == 0 else { return false }
        let output = String(decoding: result.standardOutput, as: UTF8.self)
        // Pin the leaf signer (chain entry "1.") to Apple's exact Developer ID Installer identity: the CN
        // must begin "Developer ID Installer: Apple Inc." AND carry Apple's team ID, and the package must
        // be notarized. A substring like "Snapple Inc.", a different team, or a merely-notarized third
        // party is rejected. LC_ALL=C keeps pkgutil's status strings stable on non-English systems.
        guard let leaf = output.split(separator: "\n").first(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("1.")
        }) else { return false }
        let leafIsApple = leaf.contains("Developer ID Installer: Apple Inc.")
            && leaf.contains("(\(appleInstallerTeamID))")
        let notarized = output.contains("trusted by the Apple notary service")
        return leafIsApple && notarized
    }

    nonisolated static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}

private nonisolated enum InstallerError: Error {
    case invalidEndpoint
    case noSignedPackage
    case untrustedSource
}

nonisolated struct GitHubRelease: Decodable {
    let tagName: String
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}

nonisolated final class PackageDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<URL, any Error>?
    private var progress: (@Sendable (Double) -> Void)?
    private var destination = FileManager.default.temporaryDirectory.appendingPathComponent("download")

    func download(from url: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        self.progress = progress
        self.destination = destination
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progress?(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let destination = self.destination
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            continuation?.resume(returning: destination)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
        session.finishTasksAndInvalidate()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let error else { return }
        continuation?.resume(throwing: error)
        continuation = nil
        session.finishTasksAndInvalidate()
    }
}
