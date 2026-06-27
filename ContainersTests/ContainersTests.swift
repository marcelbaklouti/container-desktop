import Testing
import Foundation
@testable import Containers

@Suite(.serialized)
struct RuntimeClientTests {

    @Test func processRunCapturesStandardOutput() async throws {
        let invocation = ProcessInvocation(executableURL: URL(fileURLWithPath: "/bin/echo"), arguments: ["hello world"])
        let result = try await invocation.run()
        #expect(result.exitCode == 0)
        #expect(String(decoding: result.standardOutput, as: UTF8.self) == "hello world\n")
    }

    @Test func processStreamYieldsLines() async throws {
        let invocation = ProcessInvocation(executableURL: URL(fileURLWithPath: "/usr/bin/seq"), arguments: ["3"])
        var lines: [String] = []
        for try await line in invocation.stream() {
            lines.append(line)
        }
        #expect(lines == ["1", "2", "3"])
    }

    @Test func processCapturesFailureOutput() async throws {
        let invocation = ProcessInvocation(executableURL: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf oops >&2; exit 7"])
        let result = try await invocation.run()
        #expect(result.exitCode == 7)
        #expect(String(decoding: result.standardError, as: UTF8.self) == "oops")
    }

    @Test func missingBinaryThrows() async throws {
        let client = ContainerCLI(searchDirectories: ["/nonexistent"])
        await #expect(throws: RuntimeError.binaryNotFound) {
            _ = try await client.data(for: ["--version"])
        }
    }

    @Test func networkListDecodesWhenDaemonAvailable() async throws {
        struct NetworkSummary: Decodable, Sendable {
            let id: String
        }
        let client = ContainerCLI()
        do {
            let networks = try await client.decode([NetworkSummary].self, from: ["network", "ls", "--format", "json"])
            #expect(networks.contains { $0.id == "default" })
        } catch RuntimeError.binaryNotFound, RuntimeError.daemonNotRunning {
        }
    }
}
