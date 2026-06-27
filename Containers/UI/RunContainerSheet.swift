import SwiftUI

struct RunContainerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: ContainerStore
    @State private var config = RunConfiguration()
    @State private var isRunning = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Image") {
                    TextField("Image", text: $config.image, prompt: Text("alpine:latest"))
                    TextField("Name", text: $config.name, prompt: Text("optional"))
                    TextField("Command", text: $config.command, prompt: Text("optional, e.g. sleep 3600"))
                }

                Section("Resources") {
                    TextField("CPUs", text: $config.cpus, prompt: Text("e.g. 2"))
                    TextField("Memory", text: $config.memory, prompt: Text("e.g. 512M, 1G"))
                    TextField("Network", text: $config.network, prompt: Text("default"))
                }

                Section("Environment") {
                    ForEach($config.environment) { $variable in
                        HStack {
                            TextField("KEY", text: $variable.key)
                            TextField("value", text: $variable.value)
                            removeButton { config.environment.removeAll { $0.id == variable.id } }
                        }
                    }
                    addButton("Add Variable") { config.environment.append(KeyValue()) }
                }

                Section("Ports") {
                    ForEach($config.ports) { $port in
                        HStack {
                            TextField("8080:80", text: $port.text)
                            removeButton { config.ports.removeAll { $0.id == port.id } }
                        }
                    }
                    addButton("Add Port") { config.ports.append(TextItem()) }
                }

                Section("Volumes") {
                    ForEach($config.volumes) { $volume in
                        HStack {
                            TextField("name:/path", text: $volume.text)
                            removeButton { config.volumes.removeAll { $0.id == volume.id } }
                        }
                    }
                    addButton("Add Volume") { config.volumes.append(TextItem()) }
                }

                Section("Options") {
                    Toggle("Run detached", isOn: $config.detach)
                    Toggle("Remove on exit", isOn: $config.removeOnExit)
                    Toggle("Read-only root filesystem", isOn: $config.readOnly)
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
                    .disabled(config.image.isEmpty || isRunning)
                }
            }
        }
        .frame(minWidth: 540, minHeight: 620)
    }

    private func removeButton(_ action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "minus.circle.fill")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }

    private func addButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle")
        }
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

struct RunConfiguration {
    var image = ""
    var name = ""
    var command = ""
    var cpus = ""
    var memory = ""
    var network = ""
    var environment: [KeyValue] = []
    var ports: [TextItem] = []
    var volumes: [TextItem] = []
    var detach = true
    var removeOnExit = false
    var readOnly = false

    var arguments: [String] {
        var arguments = ["run"]
        if detach { arguments.append("--detach") }
        if removeOnExit { arguments.append("--rm") }
        if readOnly { arguments.append("--read-only") }
        if !name.isEmpty { arguments += ["--name", name] }
        if !cpus.isEmpty { arguments += ["--cpus", cpus] }
        if !memory.isEmpty { arguments += ["--memory", memory] }
        if !network.isEmpty { arguments += ["--network", network] }
        for variable in environment where !variable.key.isEmpty {
            arguments += ["--env", "\(variable.key)=\(variable.value)"]
        }
        for port in ports where !port.text.isEmpty {
            arguments += ["--publish", port.text]
        }
        for volume in volumes where !volume.text.isEmpty {
            arguments += ["--volume", volume.text]
        }
        arguments.append(image)
        if !command.isEmpty {
            arguments += command.split(separator: " ").map(String.init)
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
