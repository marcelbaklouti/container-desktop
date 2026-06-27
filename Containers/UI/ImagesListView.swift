import SwiftUI

struct ImagesListView: View {
    @State private var store = ImageStore()
    @State private var selectedID: String?
    @State private var showInspector = false
    @State private var showPull = false
    @State private var tagging: ContainerImage?
    @State private var pushing: ContainerImage?
    @State private var pendingDeletion: ContainerImage?
    @State private var showBuild = false

    var body: some View {
        List(selection: $selectedID) {
            ForEach(store.images) { image in
                ImageRow(image: image)
                    .tag(image.id)
                    .contextMenu { actions(for: image) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { pendingDeletion = image } label: { Label("Delete", systemImage: "trash") }
                    }
            }
        }
        .overlay { emptyState }
        .navigationTitle("Images")
        .toolbar {
            ToolbarItem {
                Button { Task { await store.prune() } } label: { Label("Prune", systemImage: "wand.and.rays") }
            }
            ToolbarItem {
                Button { showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.trailing") }
            }
            ToolbarItem {
                Button { showPull = true } label: { Label("Pull Image", systemImage: "arrow.down.circle") }
            }
            ToolbarItem {
                Button { showBuild = true } label: { Label("Build Image", systemImage: "hammer") }
            }
        }
        .task { await store.poll(every: .seconds(5)) }
        .inspector(isPresented: $showInspector) {
            if let selected = store.images.first(where: { $0.id == selectedID }) {
                ImageDetailView(image: selected)
            } else {
                ContentUnavailableView("No Selection", systemImage: "square.stack.3d.up", description: Text("Select an image to inspect it."))
            }
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
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func actions(for image: ContainerImage) -> some View {
        Button { tagging = image } label: { Label("Tag…", systemImage: "tag") }
        Button { pushing = image } label: { Label("Push…", systemImage: "arrow.up.circle") }
        Divider()
        Button(role: .destructive) { pendingDeletion = image } label: { Label("Delete", systemImage: "trash") }
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .foregroundStyle(.tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(image.configuration.name).font(.headline)
                Text(image.shortDigest).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Spacer()
            if !image.realPlatforms.isEmpty {
                Text("\(image.realPlatforms.count) platform\(image.realPlatforms.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct ImageDetailView: View {
    let image: ContainerImage

    var body: some View {
        Form {
            Section {
                LabeledContent("Reference", value: image.configuration.name)
                LabeledContent("Digest", value: image.shortDigest)
                LabeledContent("Created", value: image.configuration.creationDate)
            }
            Section("Platforms") {
                ForEach(image.realPlatforms, id: \.digest) { variant in
                    LabeledContent(platformLabel(variant)) {
                        Text(Int64(variant.size), format: .byteCount(style: .file))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(image.configuration.name)
    }

    private func platformLabel(_ variant: ImageVariant) -> String {
        var label = "\(variant.platform.os)/\(variant.platform.architecture)"
        if let v = variant.platform.variant { label += " (\(v))" }
        return label
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
