import SwiftUI

struct ComposeLaunchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let project: ComposeProject
    @State private var launcher = ComposeLauncher()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Project", value: project.name)
                    LabeledContent("Network", value: project.networkName)
                    if !project.namedVolumes.isEmpty {
                        LabeledContent("Volumes", value: project.namedVolumes.joined(separator: ", "))
                    }
                }

                Section {
                    ForEach(rows) { row in
                        ComposeServiceRow(row: row, service: service(named: row.id))
                    }
                } header: {
                    HStack {
                        Text("Services")
                        Spacer()
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(summaryColor)
                            .textCase(nil)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Launch Stack")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(launcher.finished ? "Done" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !launcher.finished {
                        Button {
                            Task { await launcher.launch(project) }
                        } label: {
                            if launcher.isLaunching {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small)
                                    Text("Launching…")
                                }
                            } else {
                                Text("Launch")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(launcher.isLaunching)
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 460)
        .interactiveDismissDisabled(launcher.isLaunching)
    }

    private var rows: [ComposeLauncher.ServiceProgress] {
        launcher.progress.isEmpty
            ? project.runOrder().map { ComposeLauncher.ServiceProgress(id: $0.name, name: $0.displayName, phase: .waiting) }
            : launcher.progress
    }

    private var summary: String {
        let total = rows.count
        if launcher.finished {
            return launcher.failedCount == 0
                ? "All \(total) running"
                : "\(launcher.runningCount) running · \(launcher.failedCount) failed"
        }
        if launcher.isLaunching {
            return "\(launcher.runningCount) of \(total) ready"
        }
        return "\(total)"
    }

    private var summaryColor: Color {
        guard launcher.finished else { return .secondary }
        return launcher.failedCount == 0 ? .green : .orange
    }

    private func service(named name: String) -> ComposeService? {
        project.services.first { $0.name == name }
    }
}

private struct ComposeServiceRow: View {
    let row: ComposeLauncher.ServiceProgress
    let service: ComposeService?

    var body: some View {
        HStack(spacing: 11) {
            statusIcon
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(row.name).font(.callout.weight(.medium))
                    Spacer(minLength: 8)
                    if let ports = service?.ports, !ports.isEmpty {
                        Text(ports.joined(separator: ", "))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                if case let .failed(message) = row.phase {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.name)
        .accessibilityValue(statusText)
    }

    private var statusText: String {
        switch row.phase {
        case .waiting: service?.image.map(ImageName.short) ?? String(localized: "Waiting")
        case .pulling: String(localized: "Pulling image…")
        case .starting: String(localized: "Starting…")
        case .running: String(localized: "Running")
        case .failed: String(localized: "Failed")
        }
    }

    private var statusColor: Color {
        switch row.phase {
        case .waiting, .pulling, .starting: .secondary
        case .running: .green
        case .failed: .red
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch row.phase {
        case .waiting:
            Image(systemName: "circle.dotted").foregroundStyle(.tertiary)
        case .pulling, .starting:
            ProgressView().controlSize(.small)
        case .running:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }
}
