import SwiftUI

struct ContainerLogsView: View {
    let containerID: String

    @State private var client = ContainerCLI()
    @State private var mode: LogMode = .live
    @State private var follow = true
    @State private var lines: [LogLine] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
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
                    guard follow, let last = lines.last else { return }
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }

            Divider()
            HStack {
                Picker("Mode", selection: $mode) {
                    Text("Live").tag(LogMode.live)
                    Text("Boot").tag(LogMode.boot)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                Spacer()

                Toggle("Follow", isOn: $follow)
                    .controlSize(.small)
            }
            .padding(8)
        }
        .task(id: streamKey) {
            await stream()
        }
    }

    private var streamKey: String { "\(containerID)|\(mode.rawValue)" }

    private func stream() async {
        lines = []
        errorMessage = nil
        let arguments = mode == .live
            ? ["logs", "--follow", containerID]
            : ["logs", "--boot", containerID]
        do {
            let output = try await client.lines(for: arguments)
            for try await line in output {
                lines.append(LogLine(text: line))
                if lines.count > 5000 {
                    lines.removeFirst(lines.count - 5000)
                }
            }
        } catch is CancellationError {
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
    }
}

enum LogMode: String {
    case live
    case boot
}

struct LogLine: Identifiable, Hashable {
    let id = UUID()
    let text: String
}
