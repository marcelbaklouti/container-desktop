import SwiftUI
import AppKit

struct ContainerDetailView: View {
    let container: Container
    @Environment(\.openURL) private var openURL

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
                if let hostname = container.hostname {
                    LabeledContent("Hostname") {
                        HStack(spacing: 10) {
                            Button(hostname) {
                                if let url = hostnameURL { openURL(url) }
                            }
                            .buttonStyle(.link)
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(hostname, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                            .help("Copy hostname")
                        }
                    }
                }
            }

            if !container.configuration.publishedPorts.isEmpty {
                Section("Ports") {
                    ForEach(container.configuration.publishedPorts, id: \.self) { port in
                        LabeledContent(port.display) {
                            HStack(spacing: 10) {
                                Button("localhost:\(port.hostPort)") {
                                    if let url = URL(string: "http://localhost:\(port.hostPort)") { openURL(url) }
                                }
                                .buttonStyle(.link)
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString("localhost:\(port.hostPort)", forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                .help("Copy address")
                            }
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

            if !container.configuration.mounts.isEmpty {
                Section("Mounts") {
                    ForEach(container.configuration.mounts, id: \.self) { mount in
                        LabeledContent(mount.destination) {
                            Text(mount.sourceLabel).foregroundStyle(.secondary)
                        }
                    }
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

    private var hostnameURL: URL? {
        guard let hostname = container.hostname else { return nil }
        if let port = container.configuration.publishedPorts.first?.containerPort {
            return URL(string: "http://\(hostname):\(port)")
        }
        return URL(string: "http://\(hostname)")
    }
}
