import SwiftUI

struct RunContainerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: ContainerStore
    @State private var config = RunConfiguration()
    @State private var advancedExpanded = false
    @State private var isRunning = false
    @State private var error: String?
    @State private var dnsDomains: [String] = []
    @AppStorage("defaultCPUs") private var defaultCPUs = ""
    @AppStorage("defaultMemory") private var defaultMemory = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Image") {
                    TextField("Image", text: $config.image, prompt: Text("alpine:latest"))
                    TextField("Name", text: $config.name, prompt: Text("optional"))
                    TextField("Project", text: $config.project, prompt: Text("optional, groups containers"))
                    TextField("Command", text: $config.command, prompt: Text("optional, e.g. sleep 3600"))
                }

                Section("Resources") {
                    TextField("CPUs", text: $config.cpus, prompt: Text("e.g. 2"))
                    TextField("Memory", text: $config.memory, prompt: Text("e.g. 512M, 1G"))
                    TextField("Network", text: $config.network, prompt: Text("default"))
                    if !dnsDomains.isEmpty {
                        Picker("DNS domain", selection: $config.dnsDomain) {
                            Text("None").tag("")
                            ForEach(dnsDomains, id: \.self) { domain in
                                Text(domain).tag(domain)
                            }
                        }
                    }
                }

                Section("Environment") {
                    ForEach($config.environment) { $variable in
                        HStack {
                            TextField("Name", text: $variable.key)
                            TextField("Value", text: $variable.value)
                            removeButton("Remove Variable") { config.environment.removeAll { $0.id == variable.id } }
                        }
                    }
                    addButton("Add Variable") { config.environment.append(KeyValue()) }
                }

                Section("Ports") {
                    ForEach($config.ports) { $port in
                        HStack {
                            TextField("8080:80", text: $port.text)
                            removeButton("Remove Port") { config.ports.removeAll { $0.id == port.id } }
                        }
                    }
                    addButton("Add Port") { config.ports.append(TextItem()) }
                }

                Section("Volumes") {
                    ForEach($config.volumes) { $volume in
                        HStack {
                            TextField("name:/path", text: $volume.text)
                            removeButton("Remove Volume") { config.volumes.removeAll { $0.id == volume.id } }
                        }
                    }
                    addButton("Add Volume") { config.volumes.append(TextItem()) }
                }

                Section("Options") {
                    Toggle("Run detached", isOn: $config.detach)
                    Toggle("Remove on exit", isOn: $config.removeOnExit)
                    Toggle("Read-only root filesystem", isOn: $config.readOnly)
                }

                Section {
                    DisclosureGroup("Advanced", isExpanded: $advancedExpanded) {
                        TextField("Entrypoint", text: $config.entrypoint, prompt: Text("e.g. /bin/sh"))
                        TextField("User", text: $config.user, prompt: Text("name or uid:gid"))
                        if !config.user.isEmpty && !RunConfiguration.isValidUser(config.user) {
                            validationCaption("Use letters, numbers, or uid:gid.")
                        }
                        TextField("Working Directory", text: $config.workingDirectory, prompt: Text("/app"))
                        if !config.workingDirectory.isEmpty && !config.workingDirectory.hasPrefix("/") {
                            validationCaption("Container paths start with /.")
                        }

                        ForEach($config.labels) { $label in
                            HStack {
                                TextField("Label", text: $label.key)
                                TextField("Value", text: $label.value)
                                removeButton("Remove Label") { config.labels.removeAll { $0.id == label.id } }
                            }
                        }
                        if config.labels.contains(where: { $0.key == Container.projectLabelKey }) {
                            validationCaption("Use the Project field above.")
                        }
                        addButton("Add Label") { config.labels.append(KeyValue()) }

                        ForEach($config.tmpfs) { $path in
                            HStack {
                                TextField("/tmp/cache", text: $path.text)
                                removeButton("Remove tmpfs Path") { config.tmpfs.removeAll { $0.id == path.id } }
                            }
                        }
                        addButton("Add tmpfs Path") { config.tmpfs.append(TextItem()) }

                        Picker("Platform", selection: $config.platform) {
                            Text("Apple Silicon (arm64)").tag(RunPlatform.appleSilicon)
                            Text("Intel (amd64)").tag(RunPlatform.intel)
                        }
                        if config.platform == .intel {
                            Toggle("Run with Rosetta", isOn: $config.rosetta)
                            Text("Rosetta translates Intel-only images so they run at near-native speed on Apple Silicon.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Toggle("Forward SSH Agent", isOn: $config.forwardSSHAgent)
                        Text("Lets the container use your Mac’s SSH keys — for example to clone private repositories — without copying them in.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Run Container")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRunning ? "Running…" : "Run") {
                        Task { await run() }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(config.image.isEmpty || isRunning || !config.isValid)
                }
            }
        }
        .onAppear {
            if config.cpus.isEmpty { config.cpus = defaultCPUs }
            if config.memory.isEmpty { config.memory = defaultMemory }
            if config.hasAdvancedValues { advancedExpanded = true }
        }
        .task { await loadDomains() }
        .frame(minWidth: 540, minHeight: 620)
    }

    private func validationCaption(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.red)
    }

    private func removeButton(_ label: LocalizedStringKey, _ action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "minus.circle.fill")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(label)
        .accessibilityLabel(label)
    }

    private func addButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle")
        }
    }

    private func loadDomains() async {
        let dns = DNSStore()
        await dns.refresh()
        dnsDomains = dns.domains
    }

    private func run() async {
        isRunning = true
        error = nil
        do {
            try await store.create(arguments: config.arguments)
            dismiss()
        } catch {
            self.error = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            isRunning = false
        }
    }
}

nonisolated enum RunPlatform: String, Hashable {
    case appleSilicon
    case intel
}

struct RunConfiguration {
    var image = ""
    var name = ""
    var project = ""
    var command = ""
    var cpus = ""
    var memory = ""
    var network = ""
    var dnsDomain = ""
    var environment: [KeyValue] = []
    var ports: [TextItem] = []
    var volumes: [TextItem] = []
    var detach = true
    var removeOnExit = false
    var readOnly = false
    var entrypoint = ""
    var user = ""
    var workingDirectory = ""
    var labels: [KeyValue] = []
    var tmpfs: [TextItem] = []
    var platform = RunPlatform.appleSilicon
    var rosetta = true
    var forwardSSHAgent = false

    var hasAdvancedValues: Bool {
        !entrypoint.isEmpty || !user.isEmpty || !workingDirectory.isEmpty
            || labels.contains { !$0.key.isEmpty } || tmpfs.contains { !$0.text.isEmpty }
            || platform == .intel || forwardSSHAgent
    }

    var isValid: Bool {
        (user.isEmpty || RunConfiguration.isValidUser(user))
            && (workingDirectory.isEmpty || workingDirectory.hasPrefix("/"))
            && !labels.contains { $0.key == Container.projectLabelKey }
    }

    nonisolated static func isValidUser(_ value: String) -> Bool {
        value.allSatisfy { $0.isLetter || $0.isNumber || "_.:-".contains($0) }
    }

    var arguments: [String] {
        var arguments = ["run"]
        if detach { arguments.append("--detach") }
        if removeOnExit { arguments.append("--rm") }
        if readOnly { arguments.append("--read-only") }
        if !name.isEmpty { arguments += ["--name", name] }
        if !cpus.isEmpty { arguments += ["--cpus", cpus] }
        if !memory.isEmpty { arguments += ["--memory", memory] }
        if !network.isEmpty { arguments += ["--network", network] }
        if !dnsDomain.isEmpty { arguments += ["--dns-domain", dnsDomain] }
        if !entrypoint.isEmpty { arguments += ["--entrypoint", entrypoint] }
        if !user.isEmpty { arguments += ["--user", user] }
        if !workingDirectory.isEmpty { arguments += ["--workdir", workingDirectory] }
        if platform == .intel {
            arguments += ["--arch", "amd64"]
            if rosetta { arguments.append("--rosetta") }
        }
        if forwardSSHAgent { arguments.append("--ssh") }
        for variable in environment where !variable.key.isEmpty {
            arguments += ["--env", "\(variable.key)=\(variable.value)"]
        }
        for port in ports where !port.text.isEmpty {
            arguments += ["--publish", port.text]
        }
        for volume in volumes where !volume.text.isEmpty {
            arguments += ["--volume", volume.text]
        }
        for path in tmpfs where !path.text.isEmpty {
            arguments += ["--tmpfs", path.text]
        }
        for label in labels where !label.key.isEmpty && label.key != Container.projectLabelKey {
            arguments += ["--label", "\(label.key)=\(label.value)"]
        }
        if !project.isEmpty {
            arguments += ["--label", "\(Container.projectLabelKey)=\(project)"]
        }
        arguments.append("--")
        arguments.append(image)
        if !command.isEmpty {
            arguments += ComposeParser.tokenize(command)
        }
        return arguments
    }
}

struct KeyValue: Identifiable, Hashable {
    let id = UUID()
    var key = ""
    var value = ""
}

struct TextItem: Identifiable, Hashable {
    let id = UUID()
    var text = ""
}
