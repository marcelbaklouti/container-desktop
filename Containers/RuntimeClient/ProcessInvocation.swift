import Foundation

nonisolated struct ProcessResult: Sendable {
    let standardOutput: Data
    let standardError: Data
    let exitCode: Int32
}

nonisolated final class ProcessInvocation: @unchecked Sendable {
    private let process = Process()
    private let standardOutputPipe = Pipe()
    private let standardErrorPipe = Pipe()

    private let input: Data?
    private let inputPipe: Pipe?

    init(executableURL: URL, arguments: [String], input: Data? = nil) {
        self.input = input
        let pipe: Pipe? = input == nil ? nil : Pipe()
        self.inputPipe = pipe
        process.executableURL = executableURL
        process.arguments = arguments
        if let pipe {
            process.standardInput = pipe
        } else {
            process.standardInput = FileHandle.nullDevice
        }
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe
    }

    func run() async throws -> ProcessResult {
        let buffer = OutputBuffer()
        // Exactly one thread reads each pipe (its readability handler); the termination handler never
        // reads, so there is no concurrent access to a file handle. We complete once stdout and stderr
        // have both reached EOF and the process has terminated.
        let gate = CompletionGate(required: 3)
        let termination = TerminationBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProcessResult, any Error>) in
                let complete: @Sendable () -> Void = {
                    continuation.resume(returning: buffer.result(exitCode: termination.status))
                }

                standardOutputPipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    if chunk.isEmpty {
                        handle.readabilityHandler = nil
                        if gate.signal() { complete() }
                    } else {
                        buffer.appendStandardOutput(chunk)
                    }
                }
                standardErrorPipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    if chunk.isEmpty {
                        handle.readabilityHandler = nil
                        if gate.signal() { complete() }
                    } else {
                        buffer.appendStandardError(chunk)
                    }
                }
                process.terminationHandler = { finishedProcess in
                    termination.set(status: finishedProcess.terminationStatus,
                                    reason: finishedProcess.terminationReason,
                                    arguments: finishedProcess.arguments ?? [])
                    if gate.signal() { complete() }
                }

                do {
                    try process.run()
                    if let input, let inputPipe {
                        try? inputPipe.fileHandleForWriting.write(contentsOf: input)
                        try? inputPipe.fileHandleForWriting.close()
                    }
                } catch {
                    standardOutputPipe.fileHandleForReading.readabilityHandler = nil
                    standardErrorPipe.fileHandleForReading.readabilityHandler = nil
                    process.terminationHandler = nil
                    continuation.resume(throwing: RuntimeError.binaryNotFound)
                }
            }
        } onCancel: {
            terminate()
        }
    }

    func stream() -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            let output = LineAccumulator()
            let errorBuffer = OutputBuffer()
            let gate = CompletionGate(required: 3)
            let termination = TerminationBox()

            let complete: @Sendable () -> Void = {
                if let trailing = output.flush() { continuation.yield(trailing) }
                let outcome = termination.outcome
                switch outcome.reason {
                case .uncaughtSignal:
                    continuation.finish()
                case .exit where outcome.status == 0:
                    continuation.finish()
                default:
                    let message = String(decoding: errorBuffer.standardErrorData, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.finish(throwing: RuntimeError.commandFailed(
                        arguments: outcome.arguments,
                        exitCode: outcome.status,
                        message: message))
                }
            }

            standardOutputPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    if gate.signal() { complete() }
                } else {
                    for line in output.append(chunk) { continuation.yield(line) }
                }
            }
            standardErrorPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    if gate.signal() { complete() }
                } else {
                    errorBuffer.appendStandardError(chunk)
                }
            }
            process.terminationHandler = { finishedProcess in
                termination.set(status: finishedProcess.terminationStatus,
                                reason: finishedProcess.terminationReason,
                                arguments: finishedProcess.arguments ?? [])
                if gate.signal() { complete() }
            }
            continuation.onTermination = { _ in
                self.cleanup()
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: RuntimeError.binaryNotFound)
            }
        }
    }

    func terminate() {
        if process.isRunning { process.terminate() }
    }

    private func cleanup() {
        standardOutputPipe.fileHandleForReading.readabilityHandler = nil
        standardErrorPipe.fileHandleForReading.readabilityHandler = nil
        process.terminationHandler = nil
        if process.isRunning { process.terminate() }
    }
}

/// Fires exactly once, when the final required signal arrives. Used to complete a process only after
/// stdout EOF, stderr EOF, and termination have all been observed.
private nonisolated final class CompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private let required: Int
    private var count = 0
    private var fired = false

    init(required: Int) { self.required = required }

    func signal() -> Bool {
        lock.lock(); defer { lock.unlock() }
        count += 1
        guard count >= required, !fired else { return false }
        fired = true
        return true
    }
}

private nonisolated final class TerminationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedStatus: Int32 = 0
    private var storedReason: Process.TerminationReason = .exit
    private var storedArguments: [String] = []

    func set(status: Int32, reason: Process.TerminationReason, arguments: [String]) {
        lock.lock(); defer { lock.unlock() }
        storedStatus = status
        storedReason = reason
        storedArguments = arguments
    }

    var status: Int32 {
        lock.lock(); defer { lock.unlock() }
        return storedStatus
    }

    var outcome: (status: Int32, reason: Process.TerminationReason, arguments: [String]) {
        lock.lock(); defer { lock.unlock() }
        return (storedStatus, storedReason, storedArguments)
    }
}

private nonisolated final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var standardOutput = Data()
    private var standardError = Data()

    func appendStandardOutput(_ data: Data) {
        lock.lock(); standardOutput.append(data); lock.unlock()
    }

    func appendStandardError(_ data: Data) {
        lock.lock(); standardError.append(data); lock.unlock()
    }

    var standardErrorData: Data {
        lock.lock(); defer { lock.unlock() }
        return standardError
    }

    func result(exitCode: Int32) -> ProcessResult {
        lock.lock(); defer { lock.unlock() }
        return ProcessResult(standardOutput: standardOutput, standardError: standardError, exitCode: exitCode)
    }
}

private nonisolated final class LineAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var bytes: [UInt8] = []

    func append(_ data: Data) -> [String] {
        lock.lock(); defer { lock.unlock() }
        bytes.append(contentsOf: data)
        var lines: [String] = []
        while let newline = bytes.firstIndex(of: 0x0A) {
            lines.append(String(decoding: bytes[..<newline], as: UTF8.self))
            bytes.removeSubrange(...newline)
        }
        return lines
    }

    func flush() -> String? {
        lock.lock(); defer { lock.unlock() }
        guard !bytes.isEmpty else { return nil }
        let line = String(decoding: bytes, as: UTF8.self)
        bytes.removeAll()
        return line
    }
}
