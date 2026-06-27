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
                    LabeledContent("Services", value: project.services.count.formatted())
                    if !project.namedVolumes.isEmpty {
                        LabeledContent("Volumes", value: project.namedVolumes.joined(separator: ", "))
                    }
                    LabeledContent("Network", value: project.networkName)
                }

                Section("Services") {
                    ForEach(rows) { row in
                        ComposeServiceRow(row: row, service: service(named: row.id))
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Launch Stack")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(launcher.finished ? "Close" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(launcher.isLaunching ? "Launching…" : "Launch") {
                        Task { await launcher.launch(project) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(launcher.isLaunching || launcher.finished)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 440)
    }

    private var rows: [ComposeLauncher.ServiceProgress] {
        if launcher.progress.isEmpty {
            return project.runOrder().map { ComposeLauncher.ServiceProgress(id: $0.name, name: $0.displayName, step: .pending) }
        }
        return launcher.progress
    }

    private func service(named name: String) -> ComposeService? {
        project.services.first { $0.name == name }
    }
}

private struct ComposeServiceRow: View {
    let row: ComposeLauncher.ServiceProgress
    let service: ComposeService?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                statusIcon
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name).font(.callout)
                    if let image = service?.image {
                        Text(ImageName.short(image))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let ports = service?.ports, !ports.isEmpty {
                    Text(ports.joined(separator: ", "))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            if case let .failed(message) = row.step {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch row.step {
        case .pending:
            Image(systemName: "circle.dotted").foregroundStyle(.secondary)
        case .running:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }
}
