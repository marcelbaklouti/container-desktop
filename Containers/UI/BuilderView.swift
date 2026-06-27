import SwiftUI
import Foundation

struct BuilderView: View {
    @State private var client = ContainerCLI()
    @State private var isRunning = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Builder") {
                LabeledContent("Status") {
                    StatusBadge(text: isRunning ? "Running" : "Stopped", tint: isRunning ? .green : .gray)
                }
                Text("The builder is a Linux container that runs image builds. Building an image starts it automatically if needed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                if isRunning {
                    Button(role: .destructive) {
                        Task { await run(["builder", "stop"]) }
                    } label: {
                        Label("Stop Builder", systemImage: "stop.fill")
                    }
                    .disabled(isWorking)
                } else {
                    Button {
                        Task { await run(["builder", "start"]) }
                    } label: {
                        Label("Start Builder", systemImage: "play.fill")
                    }
                    .disabled(isWorking)
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Builder")
        .task { await refresh() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .help("Refresh Builder Status")
            }
        }
    }

    private func refresh() async {
        do {
            let data = try await client.data(for: ["builder", "status", "--format", "json"])
            let array = (try? JSONSerialization.jsonObject(with: data)) as? [Any]
            isRunning = (array?.isEmpty == false)
        } catch {
            isRunning = false
        }
    }

    private func run(_ arguments: [String]) async {
        isWorking = true
        errorMessage = nil
        do {
            _ = try await client.data(for: arguments)
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
        await refresh()
        isWorking = false
    }
}
