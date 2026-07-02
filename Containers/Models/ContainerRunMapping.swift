import Foundation

nonisolated enum MemoryText {
    /// Renders a byte count in the compact form `container run --memory` accepts:
    /// whole gigabytes as "2G", otherwise whole megabytes as "512M".
    static func compact(_ bytes: Int) -> String {
        guard bytes > 0 else { return "" }
        let gigabyte = 1_073_741_824
        let megabyte = 1_048_576
        if bytes % gigabyte == 0 { return "\(bytes / gigabyte)G" }
        return "\(max(1, bytes / megabyte))M"
    }
}

extension RunConfiguration {
    /// Maps an existing container back into a Run-sheet configuration, diffing environment,
    /// entrypoint, and command against the image's own defaults so only real overrides carry
    /// over. `notes` lists what couldn't map; the caller shows them in the sheet.
    init(duplicating container: Container, imageConfig: ImageRuntimeConfig?, existingIDs: Set<String>, notes: inout [String]) {
        self.init()

        image = container.configuration.image.reference
        name = RunConfiguration.nextFreeName(from: container.id, existing: existingIDs)
        project = container.project ?? ""
        dnsDomain = container.configuration.dns?.domain ?? ""
        readOnly = container.configuration.readOnly

        let imageEnvironment = Set(imageConfig?.env ?? [])
        environment = container.configuration.initProcess.environment
            .filter { !imageEnvironment.contains($0) }
            .compactMap { pair in
                guard let equals = pair.firstIndex(of: "=") else { return KeyValue(key: pair, value: "") }
                return KeyValue(key: String(pair[..<equals]), value: String(pair[pair.index(after: equals)...]))
            }

        ports = container.configuration.publishedPorts.map { port in
            var spec = ""
            if !port.hostAddress.isEmpty && port.hostAddress != "0.0.0.0" && port.hostAddress != "::" {
                spec += "\(port.hostAddress):"
            }
            spec += "\(port.hostPort):\(port.containerPort)"
            if port.proto.lowercased() == "udp" { spec += "/udp" }
            return TextItem(text: spec)
        }

        for mount in container.configuration.mounts {
            if let volumeName = mount.type.volume?.name {
                var spec = "\(volumeName):\(mount.destination)"
                if mount.options.contains("ro") { spec += ":ro" }
                volumes.append(TextItem(text: spec))
            } else if mount.type.bind != nil {
                var spec = "\(mount.source):\(mount.destination)"
                if mount.options.contains("ro") { spec += ":ro" }
                volumes.append(TextItem(text: spec))
            } else if mount.type.tmpfs != nil {
                tmpfs.append(TextItem(text: mount.destination))
            }
        }

        if container.configuration.resources.cpus > 0 {
            cpus = String(container.configuration.resources.cpus)
        }
        if container.configuration.resources.memoryInBytes > 0 {
            memory = MemoryText.compact(container.configuration.resources.memoryInBytes)
        }
        if let networkName = container.configuration.networks.first?.network, networkName != "default" {
            network = networkName
        }

        let reservedKeys: Set<String> = [Container.projectLabelKey, "com.docker.compose.service", "com.docker.compose.project.config_files", "com.docker.compose.project.working_dir", DockerMigrator.migrationLabelKey]
        let imageLabels = imageConfig?.labels ?? [:]
        labels = container.configuration.labels
            .filter { !reservedKeys.contains($0.key) && imageLabels[$0.key] != $0.value }
            .sorted { $0.key < $1.key }
            .map { KeyValue(key: $0.key, value: $0.value) }

        let process = container.configuration.initProcess
        let effectiveArgv = [process.executable] + process.arguments
        if let imageConfig {
            let imageEntrypoint = imageConfig.entrypoint ?? []
            let defaultArgv = imageEntrypoint + (imageConfig.cmd ?? [])
            if effectiveArgv != defaultArgv {
                if !imageEntrypoint.isEmpty, effectiveArgv.starts(with: imageEntrypoint) {
                    command = RunConfiguration.sheetCommand(Array(effectiveArgv.dropFirst(imageEntrypoint.count)))
                } else {
                    entrypoint = process.executable
                    if !process.arguments.isEmpty {
                        command = RunConfiguration.sheetCommand(process.arguments)
                    }
                }
            }
        } else {
            entrypoint = process.executable
            if !process.arguments.isEmpty {
                command = RunConfiguration.sheetCommand(process.arguments)
            }
            notes.append(String(localized: "The command couldn’t be checked against the image’s defaults — review it before running."))
        }

        let userID = process.user.id
        if userID.uid != 0 || userID.gid != 0 {
            user = "\(userID.uid):\(userID.gid)"
        }
        if container.configuration.platform.architecture == "amd64" {
            platform = .intel
            rosetta = container.configuration.rosetta
        }

        notes.append(String(localized: "Not carried over: remove-on-exit, SSH agent forwarding, and init options aren’t recorded in a container’s configuration."))
    }

    /// Joins argv back into the sheet's command field, double-quoting spaced words so the
    /// compose tokenizer splits them back identically.
    nonisolated static func sheetCommand(_ argv: [String]) -> String {
        argv.map { word in
            word.contains(where: \.isWhitespace) ? "\"\(word)\"" : word
        }.joined(separator: " ")
    }

    nonisolated static func nextFreeName(from base: String, existing: Set<String>) -> String {
        var stem = base
        if let dash = base.lastIndex(of: "-"), base[base.index(after: dash)...].allSatisfy(\.isNumber) {
            stem = String(base[..<dash])
        }
        var counter = 2
        while existing.contains("\(stem)-\(counter)") {
            counter += 1
        }
        return "\(stem)-\(counter)"
    }
}

nonisolated enum RunCommandFormatter {
    /// The full `container run …` invocation for an existing container — pasteable into Terminal.
    /// Keeps the container's real name; the argument list is the duplicate mapping's.
    @MainActor
    static func command(for container: Container, imageConfig: ImageRuntimeConfig?) -> String {
        var notes: [String] = []
        var config = RunConfiguration(duplicating: container, imageConfig: imageConfig, existingIDs: [], notes: &notes)
        config.name = container.id
        return ShellQuoting.joined(["container"] + config.arguments)
    }
}
