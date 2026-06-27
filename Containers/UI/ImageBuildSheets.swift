import SwiftUI
import AppKit

struct BuildImageSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: ImageStore

    @State private var client = ContainerCLI()
    @State private var contextDirectory = ""
    @State private var tag = ""
    @State private var dockerfile = ""
    @State private var target = ""
    @State private var noCache = false
    @State private var buildArgs: [KeyValue] = []
    @State private var lines: [LogLine] = []
    @State private var isBuilding = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Build") {
                    HStack {
                        TextField("Context directory", text: $contextDirectory, prompt: Text("/path/to/context"))
                        Button("Choose…") { chooseContext() }
                    }
                    TextField("Tag", text: $tag, prompt: Text("myimage:latest"))
                    TextField("Dockerfile", text: $dockerfile, prompt: Text("optional (defaults to ./Dockerfile)"))
                    TextField("Target stage", text: $target, prompt: Text("optional"))
                    Toggle("No cache", isOn: $noCache)
                }
                Section("Build args") {
                    ForEach($buildArgs) { $arg in
                        HStack {
                            TextField("Name", text: $arg.key)
                            TextField("Value", text: $arg.value)
                            Button(role: .destructive) { buildArgs.removeAll { $0.id == arg.id } } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .help("Remove Build Argument")
                            .accessibilityLabel("Remove Build Argument")
                        }
                    }
                    Button { buildArgs.append(KeyValue()) } label: { Label("Add Build Arg", systemImage: "plus.circle") }
                }
                if !lines.isEmpty {
                    Section("Output") {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 1) {
                                    ForEach(lines) { line in
                                        Text(line.text)
                                            .font(.system(.caption, design: .monospaced))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .id(line.id)
                                    }
                                }
                            }
                            .frame(minHeight: 200)
                            .onChange(of: lines.count) {
                                if let last = lines.last { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Build Image")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isBuilding ? "Building…" : "Build") { Task { await build() } }
                        .buttonStyle(.glassProminent)
                        .disabled(contextDirectory.isEmpty || tag.isEmpty || isBuilding)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 580)
    }

    private func chooseContext() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            contextDirectory = url.path
        }
    }

    private func build() async {
        isBuilding = true
        error = nil
        lines = []
        var arguments = ["build", "--progress", "plain", "-t", tag]
        if !dockerfile.isEmpty { arguments += ["-f", dockerfile] }
        if !target.isEmpty { arguments += ["--target", target] }
        if noCache { arguments.append("--no-cache") }
        for arg in buildArgs where !arg.key.isEmpty {
            arguments += ["--build-arg", "\(arg.key)=\(arg.value)"]
        }
        arguments.append(contextDirectory)
        do {
            let stream = try await client.lines(for: arguments)
            for try await line in stream {
                lines.append(LogLine(text: line))
                if lines.count > 3000 { lines.removeFirst(lines.count - 3000) }
            }
            await store.refresh()
        } catch {
            self.error = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
        isBuilding = false
    }
}

struct PushImageSheet: View {
    @Environment(\.dismiss) private var dismiss
    let reference: String

    @State private var client = ContainerCLI()
    @State private var lines: [LogLine] = []
    @State private var isPushing = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LabeledContent("Reference") {
                    Text(reference).font(.callout.monospaced())
                }
                .padding()
                Divider()

                if !lines.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(lines) { line in
                                    Text(line.text)
                                        .font(.system(.caption, design: .monospaced))
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
            .navigationTitle("Push Image")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isPushing ? "Pushing…" : "Push") { Task { await push() } }
                        .buttonStyle(.glassProminent)
                        .disabled(isPushing)
                }
            }
        }
        .frame(minWidth: 560, minHeight: 340)
    }

    private func push() async {
        isPushing = true
        error = nil
        lines = []
        do {
            let stream = try await client.lines(for: ["image", "push", "--progress", "plain", reference])
            for try await line in stream {
                lines.append(LogLine(text: line))
                if lines.count > 2000 { lines.removeFirst(lines.count - 2000) }
            }
        } catch {
            self.error = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
        isPushing = false
    }
}
