import SwiftUI
import AppKit

struct ImagesListView: View {
    @Environment(ContainerStore.self) private var containerStore
    @State private var store = ImageStore()
    @State private var searchText = ""
    @State private var selectedID: String?
    @State private var showInspector = false
    @State private var showPull = false
    @State private var tagging: ContainerImage?
    @State private var pushing: ContainerImage?
    @State private var pendingDeletion: ContainerImage?
    @State private var showBuild = false
    @State private var confirmingPrune = false

    var body: some View {
        List(selection: $selectedID) {
            ForEach(filteredImages) { image in
                ImageRow(image: image, isInUse: inUseDigests.contains(image.configuration.descriptor.digest))
                    .tag(image.id)
                    .contextMenu { actions(for: image) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { pendingDeletion = image } label: { Label("Delete", systemImage: "trash") }
                    }
            }
        }
        .overlay { emptyState }
        .navigationTitle("Images")
        .searchable(text: $searchText, prompt: "Filter images")
        .toolbar {
            ToolbarItemGroup {
                Button { showPull = true } label: { Label("Pull Image", systemImage: "arrow.down.circle") }
                    .help("Pull Image…")
                Button { showBuild = true } label: { Label("Build Image", systemImage: "hammer") }
                    .help("Build Image…")
                Button { importImage() } label: { Label("Import Image", systemImage: "arrow.up.doc") }
                    .help("Import Image…")
            }
            ToolbarItem {
                Button { showInspector.toggle() } label: { Label(showInspector ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.right") }
                    .help(showInspector ? "Hide Inspector" : "Show Inspector")
            }
            ToolbarItem {
                Menu {
                    Button(role: .destructive) { confirmingPrune = true } label: { Label("Prune Unused Images", systemImage: "trash") }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .help("More Actions")
            }
        }
        .task { await store.poll(every: .seconds(5)) }
        .inspector(isPresented: $showInspector) {
            Group {
                if let selected = store.images.first(where: { $0.id == selectedID }) {
                    ImageDetailView(image: selected, isInUse: inUseDigests.contains(selected.configuration.descriptor.digest))
                } else {
                    ContentUnavailableView("No Selection", systemImage: "square.stack.3d.up", description: Text("Select an image to inspect it."))
                }
            }
            .inspectorColumnWidth(min: 300, ideal: 340, max: 520)
        }
        .onChange(of: selectedID) { _, value in if value != nil { showInspector = true } }
        .sheet(isPresented: $showPull) { PullImageSheet(store: store) }
        .sheet(isPresented: $showBuild) { BuildImageSheet(store: store) }
        .sheet(item: $tagging) { image in TagImageSheet(store: store, image: image) }
        .sheet(item: $pushing) { image in PushImageSheet(reference: image.configuration.name) }
        .confirmationDialog("Delete this image?", isPresented: deletionBinding, presenting: pendingDeletion) { image in
            Button("Delete", role: .destructive) { Task { await store.delete(image) } }
        } message: { image in
            Text(image.configuration.name)
        }
        .confirmationDialog("Remove all unused images?", isPresented: $confirmingPrune) {
            Button("Remove Unused Images", role: .destructive) { Task { await store.prune() } }
        } message: {
            Text("This permanently deletes every image not used by a container.")
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var filteredImages: [ContainerImage] {
        guard !searchText.isEmpty else { return store.images }
        return store.images.filter { ImageName.short($0.configuration.name).localizedCaseInsensitiveContains(searchText) }
    }

    /// Images currently backing a container, matched by canonical image digest (robust to how the
    /// container referenced the image — tag, digest, or short name). Derived from the shared
    /// ContainerStore poll rather than a second `ls --all` of our own.
    private var inUseDigests: Set<String> {
        Set(containerStore.containers.map { $0.configuration.image.descriptor.digest })
    }

    @ViewBuilder
    private func actions(for image: ContainerImage) -> some View {
        Button { tagging = image } label: { Label("Tag…", systemImage: "tag") }
        Button { pushing = image } label: { Label("Push…", systemImage: "arrow.up.circle") }
        Button { exportImage(image) } label: { Label("Export…", systemImage: "arrow.down.doc") }
        Divider()
        Button(role: .destructive) { pendingDeletion = image } label: { Label("Delete", systemImage: "trash") }
    }

    private func exportImage(_ image: ContainerImage) {
        let panel = NSSavePanel()
        let safeName = ImageName.short(image.configuration.name)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        panel.nameFieldStringValue = "\(safeName).tar"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                try await store.save(image, to: url)
            } catch {
                store.errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            }
        }
    }

    private func importImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                try await store.load(from: url)
            } catch {
                store.errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !store.hasLoaded {
            ProgressView().controlSize(.large)
        } else if store.images.isEmpty {
            ContentUnavailableView("No Images", systemImage: "square.stack.3d.up", description: Text("Pull an image to get started."))
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
    }
}

struct ImageRow: View {
    let image: ContainerImage
    let isInUse: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .foregroundStyle(.tint)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(ImageName.short(image.configuration.name)).font(.headline)
                    if isInUse {
                        Text("In Use")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.green.opacity(0.18), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
                Text(image.shortDigest).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(Int64(image.displaySize), format: .byteCount(style: .file))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if image.realPlatforms.count > 1 {
                    Text("\(String(image.realPlatforms.count)) platforms")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ImageName.short(image.configuration.name))
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let usage = isInUse ? "In use" : "Not in use"
        let size = ByteCountFormatStyle(style: .file).format(Int64(image.displaySize))
        return "\(usage), \(size)"
    }
}

struct ImageDetailView: View {
    let image: ContainerImage
    let isInUse: Bool

    var body: some View {
        Form {
            Section {
                LabeledContent("ID", value: image.id)
                LabeledContent("Reference", value: ImageName.short(image.configuration.name))
                LabeledContent("Digest", value: image.shortDigest)
                LabeledContent("Size") {
                    Text(Int64(image.displaySize), format: .byteCount(style: .file))
                }
                if isInUse {
                    LabeledContent("Status") {
                        StatusBadge(text: "In Use", tint: .green)
                    }
                }
                LabeledContent("Created", value: DateText.relative(image.configuration.creationDate))
            }
            Section("Platforms") {
                ForEach(image.realPlatforms, id: \.digest) { variant in
                    LabeledContent(platformLabel(variant)) {
                        Text(Int64(variant.size), format: .byteCount(style: .file))
                    }
                }
            }
            if !image.hostHistory.isEmpty {
                Section("History") {
                    ForEach(Array(image.hostHistory.enumerated()), id: \.offset) { _, entry in
                        if let command = entry.createdBy {
                            Text(historyText(command))
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .lineLimit(4)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .textSelection(.enabled)
        .navigationTitle(ImageName.short(image.configuration.name))
    }

    private func platformLabel(_ variant: ImageVariant) -> String {
        var label = "\(variant.platform.os)/\(variant.platform.architecture)"
        if let v = variant.platform.variant { label += " (\(v))" }
        return label
    }

    private func historyText(_ raw: String) -> String {
        raw.replacingOccurrences(of: "/bin/sh -c #(nop) ", with: "")
            .replacingOccurrences(of: "/bin/sh -c ", with: "RUN ")
            .trimmingCharacters(in: .whitespaces)
    }
}

struct TagImageSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: ImageStore
    let image: ContainerImage

    @State private var target = ""
    @State private var isTagging = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    Text(image.configuration.name).font(.callout.monospaced())
                }
                Section("New reference") {
                    TextField("Target", text: $target, prompt: Text("myrepo/name:tag"))
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Tag Image")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isTagging ? "Tagging…" : "Tag") { Task { await tag() } }
                        .disabled(target.isEmpty || isTagging)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 240)
    }

    private func tag() async {
        isTagging = true
        error = nil
        do {
            try await store.tag(source: image.configuration.name, target: target)
            dismiss()
        } catch {
            self.error = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            isTagging = false
        }
    }
}

struct PullImageSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: ImageStore

    @State private var client = ContainerCLI()
    @State private var reference = ""
    @State private var lines: [LogLine] = []
    @State private var isPulling = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    TextField("Image reference", text: $reference, prompt: Text("nginx:latest"))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { startPull() }
                    Button(isPulling ? "Pulling…" : "Pull") { startPull() }
                        .buttonStyle(.glassProminent)
                        .disabled(reference.isEmpty || isPulling)
                }
                .padding()

                if !lines.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(lines) { line in
                                    Text(line.text)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(line.id)
                                }
                            }
                            .padding(8)
                        }
                        .onChange(of: lines.count) {
                            if let last = lines.last { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .frame(minHeight: 200)
                }

                if let error {
                    Text(error).font(.callout).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading).padding()
                }
            }
            .navigationTitle("Pull Image")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } }
            }
        }
        .frame(minWidth: 580, minHeight: 380)
    }

    private func startPull() {
        guard !reference.isEmpty, !isPulling else { return }
        Task { await pull() }
    }

    private func pull() async {
        isPulling = true
        error = nil
        lines = []
        do {
            let stream = try await client.lines(for: ["image", "pull", "--progress", "plain", reference])
            for try await line in stream {
                lines.append(LogLine(text: line))
                if lines.count > 2000 { lines.removeFirst(lines.count - 2000) }
            }
            await store.refresh()
        } catch {
            self.error = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
        isPulling = false
    }
}
