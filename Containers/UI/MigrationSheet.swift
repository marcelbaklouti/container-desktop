import SwiftUI

struct MigrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ContainerStore.self) private var containerStore
    @State private var migrator = DockerMigrator()
    @State private var selection: Set<String> = []
    @State private var hasPreselected = false

    var body: some View {
        NavigationStack {
            Group {
                if migrator.isMigrating || migrator.finished {
                    progressStage
                } else {
                    selectionStage
                }
            }
            .navigationTitle("Migrate from Docker")
            .toolbar { toolbarContent }
        }
        .frame(minWidth: 540, minHeight: 480)
        .interactiveDismissDisabled(migrator.isMigrating)
        .task {
            await migrator.loadCandidates()
            if !hasPreselected {
                selection = Set(migrator.candidates.filter(\.isRunning).map(\.id))
                hasPreselected = true
            }
        }
        .onChange(of: migrator.finished) { _, finished in
            if finished { Task { await containerStore.refresh() } }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if migrator.isMigrating {
                Button("Cancel") { migrator.cancel() }
            } else {
                Button(migrator.finished ? "Done" : "Cancel") { dismiss() }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            if !migrator.isMigrating && !migrator.finished {
                Button(migrateButtonTitle) {
                    let selected = migrator.candidates.filter { selection.contains($0.id) }
                    Task { await migrator.migrate(selected) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selection.isEmpty || migrator.availability != .ready)
            }
        }
    }

    private var migrateButtonTitle: String {
        selection.count <= 1
            ? String(localized: "Migrate Container")
            : String(localized: "Migrate \(selection.count) Containers")
    }

    @ViewBuilder
    private var selectionStage: some View {
        switch migrator.availability {
        case .notInstalled:
            ContentUnavailableView(
                "Docker Isn’t Installed",
                systemImage: "shippingbox.and.arrow.backward",
                description: Text("Migration copies containers out of a local Docker installation, and there isn’t one on this Mac.")
            )
        case .daemonStopped:
            ContentUnavailableView(
                "Start Docker to Migrate",
                systemImage: "shippingbox.and.arrow.backward",
                description: Text("Docker is installed but not running. Start Docker Desktop so its containers can be read, then try again.")
            )
        case .ready:
            if migrator.candidates.isEmpty {
                ContentUnavailableView(
                    "Nothing to Migrate",
                    systemImage: "shippingbox.and.arrow.backward",
                    description: Text("Docker has no containers on this Mac.")
                )
            } else {
                candidateList
            }
        }
    }

    private var candidateList: some View {
        Form {
            Section {
                Text("Copies the selected containers — images, settings, and volume data — to Apple’s runtime. Their Docker originals are stopped after a successful move, and never deleted.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Toggle("Stop originals in Docker", isOn: Bindable(migrator).stopOriginals)
            }
            ForEach(candidateGroups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.containers) { container in
                        candidateRow(container)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func candidateRow(_ container: DockerContainer) -> some View {
        Toggle(isOn: selectionBinding(container.id)) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(container.displayName).font(.callout.weight(.medium))
                    Text(candidateDetail(container))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                StatusBadge(
                    text: container.isRunning ? "Running" : "Stopped",
                    tint: container.isRunning ? .green : .gray
                )
            }
        }
        .toggleStyle(.checkbox)
    }

    private func candidateDetail(_ container: DockerContainer) -> String {
        var parts = [ImageName.short(container.config.image)]
        let ports = (container.hostConfig.portBindings ?? [:]).values.compactMap { bindings -> String? in
            guard let port = bindings?.first?.hostPort, !port.isEmpty else { return nil }
            return port
        }.sorted()
        if !ports.isEmpty { parts.append("ports \(ports.joined(separator: ", "))") }
        let volumes = container.namedVolumeMounts.compactMap(\.name)
        if !volumes.isEmpty {
            let described = volumes.map { name in
                migrator.volumeSizes[name].map { "\(name) (\($0))" } ?? name
            }
            parts.append(described.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    private struct CandidateGroup {
        let title: String
        let containers: [DockerContainer]
    }

    private var candidateGroups: [CandidateGroup] {
        let grouped = Dictionary(grouping: migrator.candidates) { $0.project ?? "" }
        var groups: [CandidateGroup] = []
        for project in grouped.keys.filter({ !$0.isEmpty }).sorted() {
            groups.append(CandidateGroup(title: project, containers: grouped[project] ?? []))
        }
        if let standalone = grouped[""], !standalone.isEmpty {
            groups.append(CandidateGroup(title: String(localized: "Standalone"), containers: standalone))
        }
        return groups
    }

    private func selectionBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { selection.contains(id) },
            set: { included in
                if included { selection.insert(id) } else { selection.remove(id) }
            }
        )
    }

    private var progressStage: some View {
        Form {
            Section {
                ForEach(migrator.items) { item in
                    MigrationItemRow(item: item)
                }
            } header: {
                HStack {
                    Text("Containers")
                    Spacer()
                    Text(progressSummary)
                        .font(.caption)
                        .foregroundStyle(summaryColor)
                        .textCase(nil)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var progressSummary: String {
        let total = migrator.items.count
        if migrator.finished {
            return migrator.failedCount == 0
                ? String(localized: "All \(migrator.doneCount) migrated")
                : String(localized: "\(migrator.doneCount) migrated · \(migrator.failedCount) failed")
        }
        return String(localized: "\(migrator.doneCount) of \(total) migrated")
    }

    private var summaryColor: Color {
        guard migrator.finished else { return .secondary }
        return migrator.failedCount == 0 ? .green : .orange
    }
}

private struct MigrationItemRow: View {
    let item: DockerMigrator.Item

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            statusIcon
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(item.name).font(.callout.weight(.medium))
                    Spacer(minLength: 8)
                    if let project = item.project {
                        Text(project)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                if case let .failed(message) = item.phase {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(item.notes, id: \.self) { note in
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.name)
        .accessibilityValue(statusText)
    }

    private var statusText: String {
        switch item.phase {
        case .waiting: String(localized: "Waiting")
        case .transferringImage: String(localized: "Transferring image…")
        case let .copyingVolume(name): String(localized: "Copying volume “\(name)”…")
        case .creating: String(localized: "Creating container…")
        case .switchingOver: String(localized: "Switching over…")
        case .done: String(localized: "Migrated")
        case let .skipped(reason): reason
        case .failed: String(localized: "Failed")
        }
    }

    private var statusColor: Color {
        switch item.phase {
        case .waiting, .transferringImage, .copyingVolume, .creating, .switchingOver: .secondary
        case .done: .green
        case .skipped: .secondary
        case .failed: .red
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.phase {
        case .waiting:
            Image(systemName: "circle.dotted").foregroundStyle(.tertiary)
        case .transferringImage, .copyingVolume, .creating, .switchingOver:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .skipped:
            Image(systemName: "minus.circle").foregroundStyle(.secondary)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }
}
