import SwiftUI
import AppKit

struct CopyFilesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: ContainerStore
    let container: Container

    @State private var direction: Direction = .fromContainer
    @State private var containerPath = ""
    @State private var localPath = ""
    @State private var isCopying = false
    @State private var error: String?

    enum Direction: Hashable {
        case fromContainer
        case toContainer
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Direction", selection: $direction) {
                    Text("From Container").tag(Direction.fromContainer)
                    Text("To Container").tag(Direction.toContainer)
                }
                .pickerStyle(.segmented)

                Section("Container Path") {
                    TextField("Path inside the container", text: $containerPath, prompt: Text("/etc/hosts"))
                }

                Section("Local Path") {
                    HStack {
                        TextField("Path on this Mac", text: $localPath, prompt: Text("/Users/…"))
                        Button("Browse…") { browse() }
                    }
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Copy Files")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCopying ? "Copying…" : "Copy") {
                        Task { await copy() }
                    }
                    .disabled(containerPath.isEmpty || localPath.isEmpty || isCopying)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 320)
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = direction == .toContainer
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            localPath = url.path
        }
    }

    private func copy() async {
        isCopying = true
        error = nil
        let source: String
        let destination: String
        switch direction {
        case .fromContainer:
            source = "\(container.id):\(containerPath)"
            destination = localPath
        case .toContainer:
            source = localPath
            destination = "\(container.id):\(containerPath)"
        }
        do {
            try await store.copyFiles(source: source, destination: destination)
            dismiss()
        } catch {
            self.error = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            isCopying = false
        }
    }
}
