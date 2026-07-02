import SwiftUI

struct StackInspector: View {
    let stack: Stack
    var onRelaunch: () -> Void = {}
    var onOpenComposeFile: () -> Void = {}
    @State private var tab: StackTab = .services

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $tab) {
                ForEach(StackTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)

            Divider()

            switch tab {
            case .services:
                StackServicesView(stack: stack)
            case .details:
                StackDetailsView(stack: stack, onRelaunch: onRelaunch, onOpenComposeFile: onOpenComposeFile)
            }
        }
    }
}

enum StackTab: String, CaseIterable, Identifiable {
    case services
    case details

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .services: "Services"
        case .details: "Details"
        }
    }
}

private struct StackServicesView: View {
    let stack: Stack
    @Environment(AppModel.self) private var appModel
    @Environment(ContainerStore.self) private var store
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                ForEach(stack.containers) { container in
                    serviceRow(container)
                        .contextMenu { serviceMenu(container) }
                }
            } footer: {
                Text("Services start in dependency order when you relaunch the stack.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func serviceRow(_ container: Container) -> some View {
        let transition = store.pendingTransitions[container.id]
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(container.serviceName ?? container.id)
                    .font(.callout.weight(.semibold))
                if container.serviceName != nil {
                    Text(container.id)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if !container.configuration.publishedPorts.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(container.configuration.publishedPorts, id: \.self) { port in
                            Button("localhost:\(String(port.hostPort))") {
                                if let url = URL(string: "http://localhost:\(port.hostPort)") { openURL(url) }
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            if let transition {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
                StatusBadge(text: transitionText(transition), tint: transition == .stopping ? .orange : .blue)
            } else {
                StatusBadge(
                    text: container.status?.state == "running" ? "Running" : "Stopped",
                    tint: container.status?.state == "running" ? .green : .gray
                )
                if container.status?.state == "running" {
                    Button { Task { await store.restart(container) } } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless)
                        .help("Restart \(container.serviceName ?? container.id)")
                    Button { Task { await store.stop(container) } } label: { Image(systemName: "stop.fill") }
                        .buttonStyle(.borderless)
                        .help("Stop \(container.serviceName ?? container.id)")
                } else {
                    Button { Task { await store.start(container) } } label: { Image(systemName: "play.fill") }
                        .buttonStyle(.borderless)
                        .help("Start \(container.serviceName ?? container.id)")
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(container.serviceName ?? container.id)
    }

    @ViewBuilder
    private func serviceMenu(_ container: Container) -> some View {
        if container.status?.state == "running" {
            Button { Task { await store.kill(container) } } label: { Label("Kill", systemImage: "bolt.fill") }
        }
        Button {
            appModel.navigator.area = .containers
            appModel.navigator.containerSelection = [container.id]
        } label: {
            Label("Show in Containers", systemImage: "shippingbox")
        }
    }

    private func transitionText(_ transition: ContainerTransition) -> LocalizedStringKey {
        switch transition {
        case .starting: "Starting…"
        case .stopping: "Stopping…"
        case .restarting: "Restarting…"
        }
    }
}

private struct StackDetailsView: View {
    let stack: Stack
    let onRelaunch: () -> Void
    let onOpenComposeFile: () -> Void
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Name", value: stack.name)
                LabeledContent("Services", value: stack.totalCount.formatted(.number.grouping(.never)))
                LabeledContent("State") {
                    StatusBadge(text: stateText, tint: stateTint)
                }
                if let created = earliestCreation {
                    LabeledContent("Created", value: DateText.relative(created))
                }
            }
            if let configFile = stack.configFile {
                Section("Compose File") {
                    Text(configFile.path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    HStack {
                        Button("Show in Finder") { onOpenComposeFile() }
                        Button("Relaunch Stack…") { onRelaunch() }
                    }
                }
            }
            if !networks.isEmpty {
                Section("Networks") {
                    ForEach(networks, id: \.self) { network in
                        Button(network) {
                            appModel.navigator.area = .networks
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            if !volumes.isEmpty {
                Section("Volumes") {
                    ForEach(volumes, id: \.self) { volume in
                        Button(volume) {
                            appModel.navigator.area = .volumes
                        }
                        .buttonStyle(.link)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .textSelection(.enabled)
    }

    private var stateText: LocalizedStringKey {
        switch stack.aggregateState {
        case .running: "Running"
        case .partial: LocalizedStringKey(String(localized: "\(stack.runningCount) of \(stack.totalCount) running"))
        case .stopped: "Stopped"
        }
    }

    private var stateTint: Color {
        switch stack.aggregateState {
        case .running: .green
        case .partial: .orange
        case .stopped: .gray
        }
    }

    private var networks: [String] {
        Array(Set(stack.containers.flatMap { $0.configuration.networks.map(\.network) })).sorted()
    }

    private var volumes: [String] {
        Array(Set(stack.containers.flatMap { container in
            container.configuration.mounts.compactMap { $0.type.volume?.name }
        })).sorted()
    }

    private var earliestCreation: String? {
        stack.containers.map(\.configuration.creationDate).sorted().first
    }
}
