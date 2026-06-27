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
        standardOutputPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { buffer.appendStandardOutput(chunk) }
        }
        standardErrorPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { buffer.appendStandardError(chunk) }
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProcessResult, any Error>) in
                process.terminationHandler = { [weak self] finishedProcess in
                    guard let self else {
                        continuation.resume(returning: buffer.result(exitCode: finishedProcess.terminationStatus))
                        return
                    }
                    self.standardOutputPipe.fileHandleForReading.readabilityHandler = nil
                    self.standardErrorPipe.fileHandleForReading.readabilityHandler = nil
                    let outputTail = (try? self.standardOutputPipe.fileHandleForReading.readToEnd()).flatMap { $0 } ?? Data()
                    if !outputTail.isEmpty { buffer.appendStandardOutput(outputTail) }
                    let errorTail = (try? self.standardErrorPipe.fileHandleForReading.readToEnd()).flatMap { $0 } ?? Data()
                    if !errorTail.isEmpty { buffer.appendStandardError(errorTail) }
                    continuation.resume(returning: buffer.result(exitCode: finishedProcess.terminationStatus))
                }
                do {
                    try process.run()
                    if let input, let inputPipe {
                        try? inputPipe.fileHandleForWriting.write(contentsOf: input)
                        try? inputPipe.fileHandleForWriting.close()
                    }
                } catch {
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
            standardOutputPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                for line in output.append(chunk) {
                    continuation.yield(line)
                }
            }
            standardErrorPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if !chunk.isEmpty { errorBuffer.appendStandardError(chunk) }
            }
            process.terminationHandler = { [weak self] finishedProcess in
                self?.standardOutputPipe.fileHandleForReading.readabilityHandler = nil
                if let self {
                    let remaining = (try? self.standardOutputPipe.fileHandleForReading.readToEnd()).flatMap { $0 } ?? Data()
                    for line in output.append(remaining) {
                        continuation.yield(line)
                    }
                }
                if let trailing = output.flush() {
                    continuation.yield(trailing)
                }
                switch finishedProcess.terminationReason {
                case .uncaughtSignal:
                    continuation.finish()
                case .exit where finishedProcess.terminationStatus == 0:
                    continuation.finish()
                default:
                    let message = String(decoding: errorBuffer.standardErrorData, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.finish(throwing: RuntimeError.commandFailed(
                        arguments: finishedProcess.arguments ?? [],
                        exitCode: finishedProcess.terminationStatus,
                        message: message))
                }
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
