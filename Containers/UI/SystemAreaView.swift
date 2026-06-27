import SwiftUI

struct SystemAreaView: View {
    @Environment(SystemController.self) private var system
    @State private var dnsStore = DNSStore()
    @State private var isRefreshing = false
    @State private var showAddDNS = false
    @State private var pendingDNSRemoval: String?
    @State private var confirmingStop = false

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

            Section("Local DNS domains") {
                ForEach(dnsStore.domains, id: \.self) { domain in
                    HStack {
                        Text(domain).monospaced()
                        Spacer()
                        Button(role: .destructive) { pendingDNSRemoval = domain } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Delete domain \(domain)")
                        .help("Delete Domain \(domain)")
                    }
                }
                Button { showAddDNS = true } label: { Label("Add Domain…", systemImage: "plus.circle") }
                if let dnsError = dnsStore.errorMessage {
                    Label(dnsError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmingStop = true
                } label: {
                    Label("Stop Container System", systemImage: "stop.fill")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("System")
        .task { await dnsStore.refresh() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh")
                .disabled(isRefreshing)
            }
        }
        .sheet(isPresented: $showAddDNS) { AddDNSDomainSheet(store: dnsStore) }
        .confirmationDialog("Delete this DNS domain?", isPresented: dnsRemovalBinding, presenting: pendingDNSRemoval) { domain in
            Button("Delete", role: .destructive) { Task { await dnsStore.remove(domain: domain) } }
        } message: { domain in
            Text("“\(domain)” — requires administrator authorization.")
        }
        .confirmationDialog("Stop the container system?", isPresented: $confirmingStop) {
            Button("Stop", role: .destructive) { Task { await stop() } }
        } message: {
            Text("All running containers will be stopped.")
        }
    }

    private var dnsRemovalBinding: Binding<Bool> {
        Binding(get: { pendingDNSRemoval != nil }, set: { if !$0 { pendingDNSRemoval = nil } })
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
        await dnsStore.refresh()
        isRefreshing = false
    }

    private func stop() async {
        try? await system.stop()
    }
}

struct AddDNSDomainSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: DNSStore

    @State private var domain = ""
    @State private var localhost = ""
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Local DNS domain") {
                    TextField("Domain", text: $domain, prompt: Text("test"))
                    TextField("IP Address", text: $localhost, prompt: Text("127.0.0.1 (optional)"))
                }
                Section {
                    Text("Creating a local DNS domain requires administrator authorization.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add DNS Domain")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isWorking ? "Adding…" : "Add") {
                        Task {
                            isWorking = true
                            await store.add(domain: domain, localhost: localhost)
                            isWorking = false
                            dismiss()
                        }
                    }
                    .disabled(domain.isEmpty || isWorking)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 300)
    }
}
