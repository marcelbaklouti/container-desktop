import SwiftUI

struct ContainerDetailView: View {
    let container: Container

    var body: some View {
        Form {
            Section {
                LabeledContent("Image", value: ImageName.short(container.configuration.image.reference))
                LabeledContent("Created", value: DateText.relative(container.configuration.creationDate))
                if let started = container.status?.startedDate, let uptime = DateText.uptime(since: started) {
                    LabeledContent("Uptime", value: uptime)
                }
                LabeledContent("Platform", value: "\(container.configuration.platform.os)/\(container.configuration.platform.architecture)")
                LabeledContent("Runtime", value: container.configuration.runtimeHandler)
                if let state = container.status?.state {
                    LabeledContent("State") {
                        StatusBadge(text: LocalizedStringKey(state.capitalized), tint: state == "running" ? .green : .gray)
                    }
                }
            }

            if !container.configuration.publishedPorts.isEmpty {
                Section("Ports") {
                    ForEach(container.configuration.publishedPorts, id: \.self) { port in
                        LabeledContent(port.display) {
                            Text(port.hostAddress).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Command") {
                LabeledContent("Executable", value: container.configuration.initProcess.executable)
                if !container.configuration.initProcess.arguments.isEmpty {
                    LabeledContent("Arguments", value: container.configuration.initProcess.arguments.joined(separator: " "))
                }
                LabeledContent("Working directory", value: container.configuration.initProcess.workingDirectory)
            }

            Section("Resources") {
                LabeledContent("CPUs", value: container.configuration.resources.cpus.formatted())
                LabeledContent("Memory") {
                    Text(Int64(container.configuration.resources.memoryInBytes), format: .byteCount(style: .memory))
                }
            }

            if let networks = container.status?.networks, !networks.isEmpty {
                Section("Network") {
                    ForEach(networks, id: \.network) { network in
                        if let hostname = network.hostname {
                            LabeledContent("Hostname", value: hostname)
                        }
                        if let ipv4 = network.ipv4Address {
                            LabeledContent("IPv4", value: ipv4)
                        }
                        if let ipv6 = network.ipv6Address {
                            LabeledContent("IPv6", value: ipv6)
                        }
                        if let mac = network.macAddress {
                            LabeledContent("MAC", value: mac)
                        }
                    }
                }
            }

            if !container.configuration.initProcess.environment.isEmpty {
                Section("Environment") {
                    ForEach(container.configuration.initProcess.environment, id: \.self) { variable in
                        Text(variable)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }

            if !container.configuration.labels.isEmpty {
                Section("Labels") {
                    ForEach(container.configuration.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        LabeledContent(key, value: value)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(container.id)
    }
}
