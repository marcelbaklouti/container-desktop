import SwiftUI

struct StackLogsView: View {
    let stack: Stack
    var allowsOpenInWindow = true

    @State private var store = StackLogStore()
    @State private var search = LogSearchModel()
    @State private var follow = true
    @State private var hiddenServices: Set<String> = []
    @FocusState private var searchFocused: Bool
    @Environment(\.openWindow) private var openWindow

    private static let palette: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .brown]

    var body: some View {
        VStack(spacing: 0) {
            chipsRow
            Divider()
            if search.isActive {
                LogSearchBar(search: search, focus: $searchFocused)
            }
            LogPane(entries: visibleEntries, colorForPrefix: color(for:), search: search, follow: $follow)
                .overlay {
                    if store.buffer.entries.isEmpty {
                        ContentUnavailableView("No Log Output", systemImage: "text.alignleft", description: Text("The stack’s services haven’t written any logs yet."))
                    }
                }
                .onChange(of: store.buffer.entries) { _, _ in
                    search.update(entries: visibleEntries)
                }
                .onChange(of: hiddenServices) { _, _ in
                    search.reset(entries: visibleEntries)
                }
            if store.buffer.didTrim {
                Text("Showing the last 10,000 lines — Save… captures what’s shown.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }
            Divider()
            controls
        }
        .onChange(of: memberKey, initial: true) { _, _ in
            store.setMembers(members)
        }
        .onDisappear {
            store.stop()
        }
    }

    private var members: [StackLogStore.Member] {
        stack.containers.map { container in
            StackLogStore.Member(
                id: container.id,
                service: container.serviceName ?? container.id,
                isRunning: container.status?.state == "running"
            )
        }
    }

    private var memberKey: String {
        members.map { "\($0.id):\($0.isRunning)" }.joined(separator: "|")
    }

    private var visibleEntries: [LogEntry] {
        guard !hiddenServices.isEmpty else { return store.buffer.entries }
        return store.buffer.entries.filter { entry in
            guard let prefix = entry.prefix else { return true }
            return !hiddenServices.contains(prefix)
        }
    }

    private var services: [String] {
        store.serviceColorIndex.keys.sorted()
    }

    private func color(for service: String) -> Color {
        let index = store.serviceColorIndex[service] ?? 0
        return Self.palette[index % Self.palette.count]
    }

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(services, id: \.self) { service in
                    ServiceChip(
                        name: service,
                        color: color(for: service),
                        isVisible: !hiddenServices.contains(service),
                        toggle: { isolate in
                            if isolate {
                                let others = Set(services).subtracting([service])
                                hiddenServices = hiddenServices == others ? [] : others
                            } else if hiddenServices.contains(service) {
                                hiddenServices.remove(service)
                            } else {
                                hiddenServices.insert(service)
                            }
                        }
                    )
                }
                Spacer(minLength: 0)
                if allowsOpenInWindow {
                    Button {
                        openWindow(id: "stack-logs", value: stack.name)
                    } label: {
                        Image(systemName: "macwindow.on.rectangle")
                    }
                    .buttonStyle(.borderless)
                    .help("Open Logs in New Window")
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
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

            Spacer()

            Toggle("Follow", isOn: $follow)
                .controlSize(.small)

            Menu {
                Button("Copy All") { LogExporter.copyAll(visibleEntries) }
                Button("Save…") { LogExporter.save(visibleEntries, suggestedName: "\(stack.name)-logs.log") }
                Divider()
                Button("Clear") { store.clear() }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Export or Clear")
            .disabled(store.buffer.entries.isEmpty)
        }
        .padding(8)
    }
}

private struct ServiceChip: View {
    let name: String
    let color: Color
    let isVisible: Bool
    let toggle: (Bool) -> Void

    var body: some View {
        Button {
            toggle(NSEvent.modifierFlags.contains(.option))
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(name)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isVisible ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: Capsule())
            .overlay(Capsule().strokeBorder(.quaternary, lineWidth: isVisible ? 0 : 1))
            .opacity(isVisible ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .help(isVisible ? "Hide \(name) (⌥-click to show only \(name))" : "Show \(name)")
        .accessibilityLabel(name)
        .accessibilityValue(isVisible ? "Shown" : "Hidden")
    }
}

struct StackLogsWindow: View {
    let stackName: String
    @Environment(ContainerStore.self) private var store

    var body: some View {
        Group {
            if let stack = Stack.stacks(from: store.containers).first(where: { $0.name == stackName }) {
                StackLogsView(stack: stack, allowsOpenInWindow: false)
            } else {
                ContentUnavailableView(
                    "Stack Not Found",
                    systemImage: "rectangle.3.group",
                    description: Text("“\(stackName)” isn’t running anymore.")
                )
            }
        }
        .navigationTitle("\(stackName) — Logs")
        .frame(minWidth: 560, minHeight: 400)
    }
}
