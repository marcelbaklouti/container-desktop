import SwiftUI

struct SystemAreaView: View {
    @Environment(SystemController.self) private var system
    @State private var isRefreshing = false

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("State") {
                    StatusBadge(text: "Running", tint: .green)
                }
                if let version = system.cliVersion {
                    LabeledContent("CLI version", value: version)
                }
                if let apiVersion = system.status?.apiServerVersion {
                    LabeledContent("apiserver", value: apiVersion)
                }
                if let warning = system.versionWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            if let usage = system.diskUsage {
                Section("Disk usage") {
                    diskRow("Images", entry: usage.images)
                    diskRow("Containers", entry: usage.containers)
                    diskRow("Volumes", entry: usage.volumes)
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await stop() }
                } label: {
                    Label("Stop Container System", systemImage: "stop.fill")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("System")
        .toolbar {
            Button {
                Task { await refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)
        }
    }

    private func diskRow(_ title: LocalizedStringKey, entry: DiskUsageEntry) -> some View {
        LabeledContent(title) {
            Text(Int64(entry.sizeInBytes), format: .byteCount(style: .file))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func refresh() async {
        isRefreshing = true
        await system.refresh()
        isRefreshing = false
    }

    private func stop() async {
        try? await system.stop()
    }
}
