import Testing
import Foundation
@testable import Containers

@MainActor
struct LogBufferTests {

    @Test func coalescedAppendPublishesAfterFlush() async throws {
        let buffer = LogBuffer(capacity: 100, flushInterval: .milliseconds(5))
        buffer.append("one")
        buffer.append("two")
        #expect(buffer.entries.isEmpty)
        try await Task.sleep(for: .milliseconds(30))
        #expect(buffer.entries.map(\.text) == ["one", "two"])
    }

    @Test func flushNowPublishesImmediately() {
        let buffer = LogBuffer(capacity: 100)
        buffer.append("line")
        buffer.flushNow()
        #expect(buffer.entries.count == 1)
    }

    @Test func ringCapTrimsOldestAndFlagsTrim() {
        let buffer = LogBuffer(capacity: 5)
        for index in 0..<12 {
            buffer.append("line \(index)")
        }
        buffer.flushNow()
        #expect(buffer.entries.count == 5)
        #expect(buffer.entries.first?.text == "line 7")
        #expect(buffer.didTrim)
        #expect(buffer.entries.last?.id == 11)
    }

    @Test func clearResets() {
        let buffer = LogBuffer(capacity: 5)
        buffer.append("x")
        buffer.flushNow()
        buffer.clear()
        #expect(buffer.entries.isEmpty)
        #expect(!buffer.didTrim)
    }

    @Test func prefixCarriesThrough() {
        let buffer = LogBuffer(capacity: 5)
        buffer.append("hello", prefix: "web")
        buffer.flushNow()
        #expect(buffer.entries.first?.prefix == "web")
        #expect(buffer.entries.first?.exportLine == "web | hello")
    }
}

@MainActor
struct LogSearchTests {

    private func entries(_ texts: [String], startingAt id: Int = 0) -> [LogEntry] {
        texts.enumerated().map { LogEntry(id: id + $0.offset, prefix: nil, text: $0.element) }
    }

    @Test func findsMatchesCaseInsensitively() {
        let search = LogSearchModel()
        search.update(entries: entries(["Error: failed", "all good", "ERROR again"]))
        search.query = "error"
        #expect(search.orderedMatches == [0, 2])
        #expect(search.summary == "1 of 2")
    }

    @Test func incrementalAppendExtendsMatches() {
        let search = LogSearchModel()
        search.update(entries: entries(["alpha", "beta"]))
        search.query = "beta"
        #expect(search.orderedMatches == [1])
        search.update(entries: entries(["alpha", "beta", "beta two", "gamma"]))
        #expect(search.orderedMatches == [1, 2])
    }

    @Test func navigationWrapsBothDirections() {
        let search = LogSearchModel()
        search.update(entries: entries(["m", "x", "m", "m"]))
        search.query = "m"
        #expect(search.current == 0)
        search.next()
        #expect(search.current == 2)
        search.next()
        #expect(search.current == 3)
        search.next()
        #expect(search.current == 0)
        search.previous()
        #expect(search.current == 3)
    }

    @Test func trimmedEntriesDropFromMatches() {
        let search = LogSearchModel()
        search.update(entries: entries(["m one", "m two", "m three"]))
        search.query = "m"
        #expect(search.orderedMatches == [0, 1, 2])
        search.update(entries: entries(["m two", "m three", "m four"], startingAt: 1))
        #expect(search.orderedMatches == [1, 2, 3])
    }

    @Test func unicodeMatches() {
        let search = LogSearchModel()
        search.update(entries: entries(["Grüße aus dem Container", "plain"]))
        search.query = "grüße"
        #expect(search.orderedMatches == [0])
    }

    @Test func emptyQueryHasNoMatches() {
        let search = LogSearchModel()
        search.update(entries: entries(["anything"]))
        search.query = ""
        #expect(search.orderedMatches.isEmpty)
        #expect(search.summary.isEmpty)
    }
}
