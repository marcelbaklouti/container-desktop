import SwiftUI
import AppKit

nonisolated struct LogLine: Identifiable, Hashable {
    let id = UUID()
    let text: String
}

nonisolated struct LogEntry: Identifiable, Hashable, Sendable {
    let id: Int
    let prefix: String?
    let text: String

    var exportLine: String {
        if let prefix { return "\(prefix) | \(text)" }
        return text
    }
}

/// Shared append buffer for log surfaces: coalesces bursts into one UI publish per interval and
/// keeps a bounded ring so log storms can't churn the main actor or grow without limit.
@Observable
@MainActor
final class LogBuffer {
    private(set) var entries: [LogEntry] = []
    private(set) var didTrim = false

    private var pending: [LogEntry] = []
    private var flushTask: Task<Void, Never>?
    private var nextID = 0
    private let capacity: Int
    private let flushInterval: Duration

    init(capacity: Int = 10_000, flushInterval: Duration = .milliseconds(100)) {
        self.capacity = capacity
        self.flushInterval = flushInterval
    }

    func append(_ text: String, prefix: String? = nil) {
        pending.append(LogEntry(id: nextID, prefix: prefix, text: text))
        nextID += 1
        scheduleFlush()
    }

    func flushNow() {
        flushTask?.cancel()
        flushTask = nil
        flush()
    }

    func clear() {
        flushTask?.cancel()
        flushTask = nil
        pending = []
        entries = []
        didTrim = false
    }

    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task { [weak self, flushInterval] in
            try? await Task.sleep(for: flushInterval)
            guard !Task.isCancelled else { return }
            self?.flushTask = nil
            self?.flush()
        }
    }

    private func flush() {
        guard !pending.isEmpty else { return }
        entries.append(contentsOf: pending)
        pending = []
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
            didTrim = true
        }
    }
}

@Observable
@MainActor
final class LogSearchModel {
    var isActive = false
    var query = "" {
        didSet { if query != oldValue { rescan() } }
    }
    private(set) var orderedMatches: [Int] = []
    private(set) var matchSet: Set<Int> = []
    private(set) var currentIndex = 0

    private var scannedEntries: [LogEntry] = []
    private var lastScannedID = -1

    var current: Int? {
        orderedMatches.indices.contains(currentIndex) ? orderedMatches[currentIndex] : nil
    }

    var summary: String {
        guard !query.isEmpty else { return "" }
        guard !orderedMatches.isEmpty else { return String(localized: "No Matches") }
        return "\(currentIndex + 1) of \(orderedMatches.count)"
    }

    func update(entries: [LogEntry]) {
        if let first = entries.first, let firstScanned = scannedEntries.first, first.id > firstScanned.id {
            let minID = first.id
            orderedMatches.removeAll { $0 < minID }
            matchSet = matchSet.filter { $0 >= minID }
            currentIndex = min(currentIndex, max(orderedMatches.count - 1, 0))
        }
        scannedEntries = entries
        guard !query.isEmpty else { return }
        for entry in entries where entry.id > lastScannedID {
            if entry.text.localizedCaseInsensitiveContains(query) {
                orderedMatches.append(entry.id)
                matchSet.insert(entry.id)
            }
        }
        lastScannedID = entries.last?.id ?? lastScannedID
    }

    func next() {
        guard !orderedMatches.isEmpty else { return }
        currentIndex = (currentIndex + 1) % orderedMatches.count
    }

    func previous() {
        guard !orderedMatches.isEmpty else { return }
        currentIndex = (currentIndex - 1 + orderedMatches.count) % orderedMatches.count
    }

    func dismiss() {
        isActive = false
        query = ""
    }

    private func rescan() {
        orderedMatches = []
        matchSet = []
        currentIndex = 0
        lastScannedID = -1
        guard !query.isEmpty else { return }
        for entry in scannedEntries where entry.text.localizedCaseInsensitiveContains(query) {
            orderedMatches.append(entry.id)
            matchSet.insert(entry.id)
        }
        lastScannedID = scannedEntries.last?.id ?? -1
    }
}

struct LogPane: View {
    let entries: [LogEntry]
    var colorForPrefix: (String) -> Color = { _ in .secondary }
    let search: LogSearchModel
    @Binding var follow: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(entries) { entry in
                        LogRow(
                            entry: entry,
                            prefixColor: entry.prefix.map(colorForPrefix),
                            query: search.matchSet.contains(entry.id) ? search.query : nil,
                            isCurrentMatch: search.current == entry.id
                        )
                        .id(entry.id)
                    }
                }
                .padding(8)
            }
            .onChange(of: entries.count) {
                guard follow, search.current == nil, let last = entries.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
            .onChange(of: search.current) { _, current in
                guard let current else { return }
                proxy.scrollTo(current, anchor: .center)
            }
        }
    }
}

private struct LogRow: View {
    let entry: LogEntry
    let prefixColor: Color?
    let query: String?
    let isCurrentMatch: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let prefix = entry.prefix {
                Text(verbatim: "\(prefix) |")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(prefixColor ?? .secondary)
            }
            Text(highlighted)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var highlighted: AttributedString {
        var attributed = AttributedString(entry.text)
        guard let query, !query.isEmpty else { return attributed }
        var searchStart = attributed.startIndex
        while let range = attributed[searchStart...].range(of: query, options: .caseInsensitive) {
            attributed[range].backgroundColor = isCurrentMatch ? Color.orange.opacity(0.45) : Color.yellow.opacity(0.35)
            searchStart = range.upperBound
        }
        return attributed
    }
}

struct LogSearchBar: View {
    let search: LogSearchModel
    var focus: FocusState<Bool>.Binding

    var body: some View {
        @Bindable var search = search
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search logs", text: $search.query)
                .textFieldStyle(.plain)
                .focused(focus)
                .onSubmit { search.next() }
                .onKeyPress(.escape) {
                    search.dismiss()
                    return .handled
                }
            if !search.query.isEmpty {
                Text(search.summary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Button { search.previous() } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.borderless)
                .disabled(search.orderedMatches.isEmpty)
                .help("Previous Match")
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Button { search.next() } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.borderless)
                .disabled(search.orderedMatches.isEmpty)
                .help("Next Match")
                .keyboardShortcut("g", modifiers: .command)
            Button("Done") { search.dismiss() }
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 8)
        .padding(.top, 6)
    }
}

@MainActor
enum LogExporter {
    static func copyAll(_ entries: [LogEntry]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entries.map(\.exportLine).joined(separator: "\n"), forType: .string)
    }

    static func save(_ entries: [LogEntry], suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text = entries.map(\.exportLine).joined(separator: "\n")
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
