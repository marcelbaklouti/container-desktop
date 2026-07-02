import Foundation
import Observation

nonisolated struct MigrationFailure: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

nonisolated private struct DockerDiskUsage: Decodable, Sendable {
    nonisolated struct VolumeEntry: Decodable, Sendable {
        let name: String
        let size: String?

        enum CodingKeys: String, CodingKey {
            case name = "Name"
            case size = "Size"
        }
    }

    let volumes: [VolumeEntry]?

    enum CodingKeys: String, CodingKey {
        case volumes = "Volumes"
    }
}

@Observable
@MainActor
final class DockerMigrator {
    enum Phase: Equatable {
        case waiting
        case transferringImage
        case copyingVolume(String)
        case creating
        case switchingOver
        case done
        case skipped(String)
        case failed(String)
    }

    struct Item: Identifiable {
        let id: String
        let name: String
        let project: String?
        var phase: Phase
        var notes: [String]
    }

    nonisolated static let migrationLabelKey = "desktop.container.migrated-from"
    nonisolated static let helperImage = "alpine:3"

    private(set) var availability: DockerAvailability = .notInstalled
    private(set) var candidates: [DockerContainer] = []
    private(set) var volumeSizes: [String: String] = [:]
    private(set) var items: [Item] = []
    private(set) var isMigrating = false
    private(set) var finished = false
    var stopOriginals = true

    private let docker: DockerCLI
    private let client: any RuntimeClient
    private var cancelRequested = false

    init(client: any RuntimeClient = ContainerCLI(), docker: DockerCLI = DockerCLI()) {
        self.client = client
        self.docker = docker
    }

    var doneCount: Int {
        items.filter { $0.phase == .done }.count
    }

    var failedCount: Int {
        items.reduce(0) { count, item in
            if case .failed = item.phase { return count + 1 }
            return count
        }
    }

    func cancel() {
        cancelRequested = true
    }

    func loadCandidates() async {
        availability = await docker.availability()
        guard availability == .ready else {
            candidates = []
            return
        }
        do {
            let output = try await docker.data(for: ["ps", "-aq"])
            let ids = String(decoding: output, as: UTF8.self)
                .split(whereSeparator: \.isNewline)
                .map(String.init)
            guard !ids.isEmpty else {
                candidates = []
                return
            }
            candidates = try await docker.decode([DockerContainer].self, from: ["inspect"] + ids)
                .sorted { $0.displayName < $1.displayName }
            await loadVolumeSizes()
        } catch {
            candidates = []
        }
    }

    func migrate(_ selected: [DockerContainer]) async {
        guard !isMigrating, !selected.isEmpty else { return }
        isMigrating = true
        finished = false
        cancelRequested = false
        items = selected.map { Item(id: $0.id, name: $0.displayName, project: $0.project, phase: .waiting, notes: []) }

        let existing = (try? await client.decode([Container].self, from: ["ls", "--all", "--format", "json"])) ?? []
        var localReferences = Set(((try? await client.decode([ContainerImage].self, from: ["image", "ls", "--format", "json"])) ?? []).map(\.configuration.name))

        for index in items.indices {
            if cancelRequested {
                for rest in index..<items.count where items[rest].phase == .waiting {
                    items[rest].phase = .skipped(String(localized: "Cancelled"))
                }
                break
            }
            let container = selected[index]
            do {
                try await migrateOne(container, at: index, existing: existing, localReferences: &localReferences)
            } catch let failure as MigrationFailure {
                items[index].phase = .failed(failure.message)
            } catch let error as DockerError {
                items[index].phase = .failed(error.localizedMessage)
            } catch {
                items[index].phase = .failed((error as? RuntimeError)?.localizedMessage ?? error.localizedDescription)
            }
        }

        isMigrating = false
        finished = true
    }

    private func migrateOne(_ container: DockerContainer, at index: Int, existing: [Container], localReferences: inout Set<String>) async throws {
        let name = container.displayName

        if let match = existing.first(where: { $0.id == name }) {
            if match.configuration.labels[Self.migrationLabelKey] == "docker" {
                items[index].phase = .skipped(String(localized: "Already migrated"))
            } else {
                items[index].phase = .failed(String(localized: "A container named “\(name)” already exists here."))
            }
            return
        }

        let imageInfo = try? await docker.decode([DockerImage].self, from: ["image", "inspect", container.config.image]).first

        items[index].phase = .transferringImage
        try await ensureImage(container.config.image, info: imageInfo, at: index, localReferences: &localReferences)

        let volumes = container.namedVolumeMounts
        if !volumes.isEmpty {
            try await ensureHelperImage(localReferences: &localReferences)
            try await ensureDockerHelperImage()
            for mount in volumes {
                guard let volumeName = mount.name else { continue }
                if cancelRequested {
                    items[index].phase = .skipped(String(localized: "Cancelled"))
                    return
                }
                items[index].phase = .copyingVolume(volumeName)
                try await copyVolume(volumeName, at: index)
            }
        }

        if cancelRequested {
            items[index].phase = .skipped(String(localized: "Cancelled"))
            return
        }

        items[index].phase = .creating
        let plan = Self.createArguments(for: container, imageDefaults: imageInfo)
        items[index].notes.append(contentsOf: plan.notes)
        do {
            _ = try await client.data(for: plan.arguments)
        } catch let RuntimeError.commandFailed(_, _, message) where message.contains("invalid label format") {
            let essential = Self.createArguments(for: container, imageDefaults: imageInfo, essentialLabelsOnly: true)
            _ = try await client.data(for: essential.arguments)
            items[index].notes.append(String(localized: "Some labels weren’t accepted by Apple’s runtime and were left behind; Compose grouping is preserved."))
        }

        if container.isRunning {
            if stopOriginals {
                items[index].phase = .switchingOver
                _ = try await docker.data(for: ["stop", container.id])
                do {
                    _ = try await client.data(for: ["start", name])
                } catch {
                    _ = try? await docker.data(for: ["start", container.id])
                    items[index].notes.append(String(localized: "Starting here failed, so the Docker original was restarted."))
                    throw error
                }
            } else {
                items[index].notes.append(String(localized: "Created stopped — stop the Docker original, then start it here."))
            }
        } else {
            items[index].notes.append(String(localized: "Created stopped, matching its state in Docker."))
        }

        items[index].phase = .done
    }

    private func ensureImage(_ reference: String, info: DockerImage?, at index: Int, localReferences: inout Set<String>) async throws {
        if Self.imageIsPresent(reference, in: localReferences) {
            items[index].notes.append(String(localized: "Image was already present."))
            return
        }
        if let size = info?.size {
            try ensureScratchCapacity(bytes: size)
        }
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("DockerMigration", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let tar = scratch.appendingPathComponent("image.tar")

        var transferred = false
        if (try? await docker.data(for: ["save", reference, "-o", tar.path])) != nil {
            do {
                _ = try await client.data(for: ["image", "load", "-i", tar.path])
                transferred = true
            } catch {
                if (try? await client.data(for: ["image", "load", "--force", "-i", tar.path])) != nil {
                    transferred = true
                    items[index].notes.append(String(localized: "The image archive needed lenient loading."))
                }
            }
        }

        if !transferred {
            guard info?.isRegistryResolvable == true else {
                throw MigrationFailure(String(localized: "The image “\(reference)” exists only in Docker and couldn’t be transferred."))
            }
            _ = try await client.data(for: ["image", "pull", reference])
            items[index].notes.append(String(localized: "Image was pulled from its registry."))
        }
        localReferences.insert(Self.canonicalReference(reference))
    }

    private func copyVolume(_ name: String, at index: Int) async throws {
        do {
            _ = try await client.data(for: ["volume", "create", name])
        } catch let RuntimeError.commandFailed(_, _, message) where message.localizedCaseInsensitiveContains("already exists") {
            items[index].notes.append(String(localized: "Volume “\(name)” already existed; Docker’s files were merged in."))
        }

        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("DockerMigration", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        _ = try await docker.data(for: [
            "run", "--rm",
            "-v", "\(name):/src:ro",
            "-v", "\(scratch.path):/out",
            Self.helperImage,
            "tar", "-cf", "/out/volume.tar", "-C", "/src", ".",
        ])
        let tar = scratch.appendingPathComponent("volume.tar")
        let copiedBytes = (try? FileManager.default.attributesOfItem(atPath: tar.path)[.size] as? Int) ?? nil
        _ = try await client.data(for: [
            "run", "--rm",
            "-v", "\(name):/dst",
            "-v", "\(scratch.path):/tar",
            "--",
            Self.helperImage,
            "tar", "-xf", "/tar/volume.tar", "-C", "/dst",
        ])
        if let copiedBytes {
            let formatted = ByteCountFormatStyle(style: .file).format(Int64(copiedBytes))
            items[index].notes.append(String(localized: "Copied volume “\(name)” (\(formatted))."))
        }
    }

    private func ensureHelperImage(localReferences: inout Set<String>) async throws {
        guard !Self.imageIsPresent(Self.helperImage, in: localReferences) else { return }
        _ = try await client.data(for: ["image", "pull", Self.helperImage])
        localReferences.insert(Self.canonicalReference(Self.helperImage))
    }

    private func ensureDockerHelperImage() async throws {
        if (try? await docker.data(for: ["image", "inspect", Self.helperImage])) != nil { return }
        _ = try await docker.data(for: ["pull", Self.helperImage])
    }

    private func ensureScratchCapacity(bytes: Int) throws {
        let values = try? FileManager.default.temporaryDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let available = values?.volumeAvailableCapacityForImportantUsage else { return }
        let required = Int64(bytes) + 500_000_000
        if available < required {
            let needed = ByteCountFormatStyle(style: .file).format(required)
            throw MigrationFailure(String(localized: "Not enough free disk space to transfer — about \(needed) is needed temporarily."))
        }
    }

    private func loadVolumeSizes() async {
        guard let usage = try? await docker.decode(DockerDiskUsage.self, from: ["system", "df", "-v", "--format", "json"]) else { return }
        volumeSizes = Dictionary(uniqueKeysWithValues: (usage.volumes ?? []).compactMap { entry in
            entry.size.map { (entry.name, $0) }
        })
    }

    /// Docker Desktop reports bind sources as paths inside its Linux VM, where the Mac's
    /// filesystem is mounted at /host_mnt — strip that prefix to get back to the host path.
    nonisolated static func normalizedHostPath(_ source: String) -> String {
        source.hasPrefix("/host_mnt/") ? String(source.dropFirst("/host_mnt".count)) : source
    }

    /// Apple's runtime canonicalizes references on load (`alpine:latest` becomes
    /// `docker.io/library/alpine:latest`), so presence checks normalize the same way.
    nonisolated static func canonicalReference(_ reference: String) -> String {
        let withTag = reference.contains(":") || reference.contains("@") ? reference : "\(reference):latest"
        let firstSegment = withTag.split(separator: "/").first.map(String.init) ?? withTag
        let hasRegistry = firstSegment.contains(".") || firstSegment.contains(":") || firstSegment == "localhost"
        if !withTag.contains("/") { return "docker.io/library/\(withTag)" }
        if !hasRegistry { return "docker.io/\(withTag)" }
        return withTag
    }

    nonisolated static func imageIsPresent(_ reference: String, in references: Set<String>) -> Bool {
        let canonical = canonicalReference(reference)
        return references.contains(reference) || references.contains(canonical)
    }

    nonisolated static func createArguments(for container: DockerContainer, imageDefaults: DockerImage?, essentialLabelsOnly: Bool = false) -> (arguments: [String], notes: [String]) {
        var args = ["create", "--name", container.displayName]
        var notes: [String] = []

        let defaultEnvironment = Set(imageDefaults?.config.env ?? [])
        for pair in container.config.env ?? [] where !defaultEnvironment.contains(pair) {
            args += ["-e", pair]
        }

        for (spec, bindings) in (container.hostConfig.portBindings ?? [:]).sorted(by: { $0.key < $1.key }) {
            guard let bindings, !bindings.isEmpty else { continue }
            let parts = spec.split(separator: "/", maxSplits: 1)
            let containerPort = String(parts.first ?? "")
            let proto = parts.count > 1 ? String(parts[1]) : "tcp"
            for binding in bindings {
                guard let hostPort = binding.hostPort, !hostPort.isEmpty else { continue }
                var mapping = ""
                if let ip = binding.hostIP, !ip.isEmpty, ip != "0.0.0.0", ip != "::" {
                    mapping += "\(ip):"
                }
                mapping += "\(hostPort):\(containerPort)"
                if proto == "udp" { mapping += "/udp" }
                args += ["-p", mapping]
            }
        }

        for mount in container.mounts {
            switch mount.type {
            case "volume":
                guard let volumeName = mount.name else { continue }
                var spec = "\(volumeName):\(mount.destination)"
                if mount.rw == false { spec += ":ro" }
                args += ["-v", spec]
            case "bind":
                guard let source = mount.source else { continue }
                let hostPath = normalizedHostPath(source)
                guard FileManager.default.fileExists(atPath: hostPath) else {
                    notes.append(String(localized: "Bind mount to \(mount.destination) was skipped — \(hostPath) doesn’t exist on this Mac."))
                    continue
                }
                var spec = "\(hostPath):\(mount.destination)"
                if mount.rw == false { spec += ":ro" }
                args += ["-v", spec]
            case "tmpfs":
                args += ["--tmpfs", mount.destination]
            default:
                notes.append(String(localized: "Mount “\(mount.destination)” of type \(mount.type) wasn’t carried over."))
            }
        }

        let imageWorkingDir = imageDefaults?.config.workingDir ?? ""
        if let workingDir = container.config.workingDir, !workingDir.isEmpty, workingDir != imageWorkingDir {
            args += ["--workdir", workingDir]
        }
        let imageUser = imageDefaults?.config.user ?? ""
        if let user = container.config.user, !user.isEmpty, user != imageUser {
            args += ["--user", user]
        }

        let imageEntrypoint = imageDefaults?.config.entrypoint ?? []
        let entrypoint = container.config.entrypoint ?? []
        var entrypointOverridden = false
        if !entrypoint.isEmpty, entrypoint != imageEntrypoint {
            args += ["--entrypoint", entrypoint.joined(separator: " ")]
            entrypointOverridden = true
            if entrypoint.count > 1 {
                notes.append(String(localized: "The entrypoint was flattened to a single string."))
            }
        }

        if let nano = container.hostConfig.nanoCPUs, nano > 0 {
            let cpus = max(1, Int((Double(nano) / 1_000_000_000).rounded()))
            args += ["--cpus", String(cpus)]
        }
        if let memory = container.hostConfig.memory, memory > 0 {
            args += ["--memory", String(memory)]
        }

        let imageLabels = imageDefaults?.config.labels ?? [:]
        let essentialKeys = [Container.projectLabelKey, "com.docker.compose.service"]
        for (key, value) in (container.config.labels ?? [:]).sorted(by: { $0.key < $1.key }) where imageLabels[key] != value {
            if essentialLabelsOnly && !essentialKeys.contains(key) { continue }
            args += ["--label", "\(key)=\(value)"]
        }
        args += ["--label", "\(migrationLabelKey)=docker"]

        if let policy = container.hostConfig.restartPolicy?.name, !policy.isEmpty, policy != "no" {
            notes.append(String(localized: "The restart policy “\(policy)” isn’t supported by Apple’s runtime and was dropped."))
        }
        if let mode = container.hostConfig.networkMode, !mode.isEmpty, mode != "default", mode != "bridge" {
            notes.append(String(localized: "Attached to the default network — Docker’s “\(mode)” network doesn’t carry over."))
        }

        args.append("--")
        args.append(container.config.image)

        let imageCmd = imageDefaults?.config.cmd ?? []
        let cmd = container.config.cmd ?? []
        if !cmd.isEmpty, entrypointOverridden || cmd != imageCmd {
            args += cmd
        }

        return (args, notes)
    }
}
