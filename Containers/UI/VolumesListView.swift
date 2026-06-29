import SwiftUI

struct VolumesListView: View {
    @State private var store = VolumeStore()
    @State private var searchText = ""
    @State private var selection: Set<String> = []
    @State private var showInspector = false
    @State private var showCreate = false
    @State private var pendingDeletion: [Volume] = []
    @State private var confirmingPrune = false

    var body: some View {
        decoratedList
            .navigationTitle("Volumes")
            .searchable(text: $searchText, prompt: "Filter volumes")
            .toolbar { toolbarContent }
            .task { await store.poll(every: .seconds(4)) }
            .inspector(isPresented: $showInspector) {
                inspectorContent
                    .inspectorColumnWidth(min: 300, ideal: 340, max: 520)
            }
            .onChange(of: selection) { _, value in showInspector = value.count == 1 }
        .onChange(of: store.volumes) { _, items in
            let trimmed = selection.intersection(Set(items.map(\.id)))
            if trimmed != selection { selection = trimmed }
        }
        .sheet(isPresented: $showCreate) { CreateVolumeSheet(store: store) }
        .confirmationDialog(pendingDeletion.count == 1 ? "Delete this volume?" : "Delete \(pendingDeletion.count) volumes?", isPresented: deletionBinding) {
            Button("Delete", role: .destructive) {
                let ids = pendingDeletion.map(\.id)
                pendingDeletion = []
                Task { await store.delete(ids) }
            }
        } message: {
            Text(pendingDeletion.count == 1 ? (pendingDeletion.first?.id ?? "") : "This permanently deletes \(pendingDeletion.count) volumes, including their data.")
        }
        .confirmationDialog("Remove all unused volumes?", isPresented: $confirmingPrune) {
            Button("Remove Unused Volumes", role: .destructive) { Task { await store.prune() } }
        } message: {
            Text("This permanently deletes every volume not used by a container, including its data.")
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var decoratedList: some View {
        List(selection: $selection) {
            ForEach(store.volumes.filter { searchText.isEmpty || $0.configuration.name.localizedCaseInsensitiveContains(searchText) }) { volume in
                VolumeRow(volume: volume, usedBytes: store.usedSizes[volume.id])
                    .tag(volume.id)
                    .swipeActions(edge: .trailing) { deleteButton(volume) }
            }
        }
        .contextMenu(forSelectionType: String.self) { ids in
            volumeMenu(ids)
        }
        .overlay { emptyState }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button { showCreate = true } label: { Label("Create Volume", systemImage: "plus") }
                .help("Create Volume…")
                .keyboardShortcut("n", modifiers: .command)
        }
        ToolbarItem {
            Button { showInspector.toggle() } label: { Label(showInspector ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.right") }
                .help(showInspector ? "Hide Inspector" : "Show Inspector")
        }
        ToolbarItem {
            Menu {
                Button(role: .destructive) { confirmingPrune = true } label: { Label("Prune Unused Volumes", systemImage: "trash") }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .help("More Actions")
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if selection.count == 1, let id = selection.first, let selected = store.volumes.first(where: { $0.id == id }) {
            VolumeDetailView(volume: selected, usedBytes: store.usedSizes[selected.id])
        } else if selection.count > 1 {
            ContentUnavailableView("\(selection.count) Selected", systemImage: "externaldrive", description: Text("Select a single volume to inspect it."))
        } else {
            ContentUnavailableView("No Selection", systemImage: "externaldrive", description: Text("Select a volume to inspect it."))
        }
    }

    @ViewBuilder
    private func deleteButton(_ volume: Volume) -> some View {
        Button(role: .destructive) { pendingDeletion = [volume] } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder
    private func volumeMenu(_ ids: Set<String>) -> some View {
        let selected = store.volumes.filter { ids.contains($0.id) }
        if !selected.isEmpty {
            Button(role: .destructive) { pendingDeletion = selected } label: {
                Label(selected.count == 1 ? "Delete" : "Delete \(selected.count)", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !store.hasLoaded {
            ProgressView().controlSize(.large)
        } else if store.volumes.isEmpty {
            EmptyStateGuide(
                icon: "externaldrive",
                title: "No Volumes",
                message: "A volume stores data that needs to outlive a container — databases, uploads, caches — so it survives restarts and rebuilds.",
                primaryLabel: "Create a Volume",
                primaryAction: { showCreate = true },
                shortcuts: [
                    KeyboardHint(label: "Create a volume", keys: "⌘N"),
                    KeyboardHint(label: "Help", keys: "⌘?"),
                    KeyboardHint(label: "Settings", keys: "⌘,"),
                ]
            )
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(get: { !pendingDeletion.isEmpty }, set: { if !$0 { pendingDeletion = [] } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
    }
}

struct VolumeRow: View {
    let volume: Volume
    let usedBytes: Int?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .foregroundStyle(.tint)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(volume.configuration.name).font(.headline)
                Text(verbatim: "\(volume.configuration.driver) · \(volume.configuration.format)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                if let usedBytes {
                    Text(Int64(usedBytes), format: .byteCount(style: .file))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text("of \(ByteCountFormatStyle(style: .file).format(Int64(volume.configuration.sizeInBytes)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(volume.configuration.name)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let allocated = ByteCountFormatStyle(style: .file).format(Int64(volume.configuration.sizeInBytes))
        if let usedBytes {
            let used = ByteCountFormatStyle(style: .file).format(Int64(usedBytes))
            return "\(used) of \(allocated) used"
        }
        return allocated
    }
}

struct VolumeDetailView: View {
    let volume: Volume
    let usedBytes: Int?

    var body: some View {
        Form {
            Section {
                LabeledContent("ID", value: volume.id)
                LabeledContent("Name", value: volume.configuration.name)
                LabeledContent("Driver", value: volume.configuration.driver)
                LabeledContent("Format", value: volume.configuration.format)
                if let usedBytes {
                    LabeledContent("Used") {
                        Text(Int64(usedBytes), format: .byteCount(style: .file))
                    }
                    ProgressView(value: Double(usedBytes), total: Double(max(volume.configuration.sizeInBytes, 1)))
                }
                LabeledContent("Allocated") {
                    Text(Int64(volume.configuration.sizeInBytes), format: .byteCount(style: .file))
                }
                LabeledContent("Created", value: DateText.relative(volume.configuration.creationDate))
            }
            Section("Source") {
                Text(volume.configuration.source)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            if !volume.configuration.labels.isEmpty {
                Section("Labels") {
                    ForEach(volume.configuration.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        LabeledContent(key, value: value)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .textSelection(.enabled)
        .navigationTitle(volume.configuration.name)
    }
}

struct CreateVolumeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: VolumeStore

    @State private var name = ""
    @State private var size = ""
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Volume") {
                    TextField("Name", text: $name, prompt: Text("my-volume"))
                    TextField("Size", text: $size, prompt: Text("e.g. 10G (optional)"))
                }
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Create Volume")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "Creating…" : "Create") { Task { await create() } }
                        .disabled(name.isEmpty || isCreating)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 240)
    }

    private func create() async {
        isCreating = true
        error = nil
        do {
            try await store.create(name: name, size: size)
            dismiss()
        } catch {
            self.error = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            isCreating = false
        }
    }
}
