import SwiftUI

struct ContainerLogsView: View {
    let containerID: String
    var isRunning = true

    @State private var client = ContainerCLI()
    @State private var mode: LogMode = .live
    @State private var tail: LogTail = .recent
    @State private var follow = true
    @State private var buffer = LogBuffer()
    @State private var search = LogSearchModel()
    @State private var errorMessage: String?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if search.isActive {
                LogSearchBar(search: search, focus: $searchFocused)
            }
            if mode == .live && !isRunning {
                Text("Final logs — output from the container’s last run.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
            }
            LogPane(entries: buffer.entries, search: search, follow: $follow)
                .overlay {
                    if buffer.entries.isEmpty && errorMessage == nil {
                        ContentUnavailableView("No Log Output", systemImage: "text.alignleft", description: Text("This container hasn’t written any logs yet."))
                    }
                }
                .onChange(of: buffer.entries) { _, entries in
                    search.update(entries: entries)
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }
            if buffer.didTrim {
                Text("Showing the last 10,000 lines — Save… captures what’s shown.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }

            Divider()
            controls
        }
        .task(id: streamKey) {
            await stream()
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Picker("Mode", selection: $mode) {
                Text(isRunning ? "Live" : "Final").tag(LogMode.live)
                Text("Boot").tag(LogMode.boot)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            if mode == .live {
                Menu {
                    ForEach(LogTail.allCases) { option in
                        Button {
                            tail = option
                        } label: {
                            if tail == option {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                    }
                } label: {
                    Text(tail.label)
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("How much history to load")
            }

            Spacer()

            Button {
                search.isActive = true
                searchFocused = true
            } label: {
                Label("Search", systemImage: "magnifyingglass")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Search Logs")
            .keyboardShortcut("f", modifiers: .command)

            if mode == .live && isRunning {
                Toggle("Follow", isOn: $follow)
                    .controlSize(.small)
            }

            Menu {
                Button("Copy All") { LogExporter.copyAll(buffer.entries) }
                Button("Save…") { LogExporter.save(buffer.entries, suggestedName: "\(containerID).log") }
                Divider()
                Button("Clear") { buffer.clear() }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Export or Clear")
            .disabled(buffer.entries.isEmpty)
        }
        .padding(8)
    }

    private var streamKey: String { "\(containerID)|\(mode.rawValue)|\(tail.rawValue)|\(isRunning)" }

    private func stream() async {
        buffer.clear()
        errorMessage = nil
        do {
            do {
                try await consume(arguments(withTail: true))
            } catch let RuntimeError.commandFailed(_, _, message) where mode == .live && tail != .all {
                _ = message
                try await consume(arguments(withTail: false))
            }
            buffer.flushNow()
        } catch is CancellationError {
            buffer.flushNow()
        } catch {
            buffer.flushNow()
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
    }

    private func arguments(withTail: Bool) -> [String] {
        switch mode {
        case .boot:
            return ["logs", "--boot", containerID]
        case .live:
            var arguments = ["logs"]
            if isRunning { arguments.append("--follow") }
            if withTail, let count = tail.lineCount {
                arguments += ["-n", String(count)]
            }
            arguments.append(containerID)
            return arguments
        }
    }

    private func consume(_ arguments: [String]) async throws {
        let output = try await client.lines(for: arguments)
        for try await line in output {
            buffer.append(line)
        }
    }
}

enum LogMode: String {
    case live
    case boot
}

enum LogTail: String, CaseIterable, Identifiable {
    case recent
    case extended
    case all

    var id: String { rawValue }

    var lineCount: Int? {
        switch self {
        case .recent: 500
        case .extended: 5000
        case .all: nil
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .recent: "Last 500"
        case .extended: "Last 5,000"
        case .all: "Everything"
        }
    }
}
