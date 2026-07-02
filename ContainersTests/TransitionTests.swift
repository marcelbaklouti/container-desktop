import Testing
import Foundation
@testable import Containers

private final class FakeRuntimeClient: RuntimeClient, @unchecked Sendable {
    private let lock = NSLock()
    private var currentContainers: [Container]?
    private var statusResponses: [SystemStatus] = []
    private var failingSubcommands: Set<String> = []

    func setContainers(_ list: [Container]) {
        lock.withLock { currentContainers = list }
    }

    func enqueueStatuses(_ statuses: [SystemStatus]) {
        lock.withLock { statusResponses.append(contentsOf: statuses) }
    }

    func fail(subcommand: String) {
        lock.withLock { _ = failingSubcommands.insert(subcommand) }
    }

    func data(for arguments: [String], input: Data?) async throws -> Data {
        let result: Result<Data, any Error> = lock.withLock {
            if let subcommand = arguments.first, failingSubcommands.contains(subcommand) {
                return .failure(RuntimeError.commandFailed(arguments: arguments, exitCode: 1, message: "scripted failure"))
            }
            if arguments == ["--version"] {
                return .success(Data("container CLI version 1.0.0".utf8))
            }
            return .success(Data())
        }
        return try result.get()
    }

    func decode<Value>(_ type: Value.Type, from arguments: [String]) async throws -> Value where Value: Decodable & Sendable {
        let result: Result<Value, any Error> = lock.withLock {
            if arguments.first == "ls" {
                guard let list = currentContainers else { return .failure(RuntimeError.daemonNotRunning) }
                guard let value = list as? Value else {
                    return .failure(RuntimeError.decodingFailed(arguments: arguments, message: "unexpected type"))
                }
                return .success(value)
            }
            if arguments.first == "system" {
                guard let status = statusResponses.first else { return .failure(RuntimeError.daemonNotRunning) }
                if statusResponses.count > 1 { statusResponses.removeFirst() }
                guard let value = status as? Value else {
                    return .failure(RuntimeError.decodingFailed(arguments: arguments, message: "unexpected type"))
                }
                return .success(value)
            }
            return .failure(RuntimeError.decodingFailed(arguments: arguments, message: "unscripted request"))
        }
        return try result.get()
    }

    func lines(for arguments: [String]) async throws -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private func makeContainer(id: String, state: String?) -> Container {
    Container(
        id: id,
        configuration: ContainerConfiguration(
            id: id,
            creationDate: "2026-07-02T00:00:00Z",
            image: ContainerImageReference(
                reference: "docker.io/library/alpine:latest",
                descriptor: OCIDescriptor(digest: "sha256:test", mediaType: "application/vnd.oci.image.index.v1+json", size: 1)
            ),
            initProcess: ContainerProcess(
                executable: "/bin/sh",
                arguments: [],
                environment: [],
                workingDirectory: "/",
                terminal: false,
                user: ContainerProcessUser(id: ContainerProcessUserID(uid: 0, gid: 0))
            ),
            resources: ContainerResources(cpus: 1, memoryInBytes: 1_073_741_824, cpuOverhead: 0),
            networks: [],
            publishedPorts: [],
            mounts: [],
            dns: nil,
            labels: [:],
            platform: Platform(architecture: "arm64", os: "linux", variant: nil),
            runtimeHandler: "container-runtime-linux",
            readOnly: false,
            rosetta: false
        ),
        status: state.map { ContainerStatus(state: $0, startedDate: nil, networks: []) }
    )
}

@MainActor
struct ContainerTransitionTests {

    @Test func startShowsPendingTransitionUntilRunningIsObserved() async throws {
        let client = FakeRuntimeClient()
        let stopped = makeContainer(id: "web", state: "stopped")
        client.setContainers([stopped])
        let store = ContainerStore(client: client)
        await store.refresh()

        await store.start(stopped)
        #expect(store.pendingTransitions["web"] == .starting)

        client.setContainers([makeContainer(id: "web", state: "running")])
        await store.refresh()
        #expect(store.pendingTransitions["web"] == nil)
    }

    @Test func stopReconcilesWhenContainerLeavesRunning() async throws {
        let client = FakeRuntimeClient()
        let running = makeContainer(id: "db", state: "running")
        client.setContainers([running])
        let store = ContainerStore(client: client)
        await store.refresh()

        await store.stop(running)
        #expect(store.pendingTransitions["db"] == .stopping)

        client.setContainers([makeContainer(id: "db", state: "stopped")])
        await store.refresh()
        #expect(store.pendingTransitions["db"] == nil)
    }

    @Test func timedOutTransitionClearsAndSurfacesMessage() async throws {
        let client = FakeRuntimeClient()
        let stopped = makeContainer(id: "slow", state: "stopped")
        client.setContainers([stopped])
        let store = ContainerStore(client: client, transitionTimeout: .milliseconds(1))
        await store.refresh()

        await store.start(stopped)
        try await Task.sleep(for: .milliseconds(20))
        await store.refresh()
        #expect(store.pendingTransitions["slow"] == nil)
        #expect(store.issue?.title.contains("slow") == true)
    }

    @Test func failedCommandClearsTransitionImmediately() async throws {
        let client = FakeRuntimeClient()
        let stopped = makeContainer(id: "broken", state: "stopped")
        client.setContainers([stopped])
        let store = ContainerStore(client: client)
        await store.refresh()

        client.fail(subcommand: "start")
        await store.start(stopped)
        #expect(store.pendingTransitions["broken"] == nil)
        #expect(store.issue != nil)
    }

    @Test func disappearedContainerClearsTransitionSilently() async throws {
        let client = FakeRuntimeClient()
        let running = makeContainer(id: "gone", state: "running")
        client.setContainers([running])
        let store = ContainerStore(client: client)
        await store.refresh()

        await store.stop(running)
        client.setContainers([])
        await store.refresh()
        #expect(store.pendingTransitions["gone"] == nil)
        #expect(store.issue == nil)
    }
}

@MainActor
struct SystemControllerTransitionTests {

    private func status(_ value: String) -> SystemStatus {
        SystemStatus(
            status: value,
            apiServerVersion: "1.0.0",
            apiServerCommit: nil,
            apiServerBuild: nil,
            apiServerAppName: nil,
            appRoot: nil,
            installRoot: nil
        )
    }

    @Test func startWaitsUntilDaemonReportsRunning() async throws {
        let client = FakeRuntimeClient()
        client.enqueueStatuses([status("stopped"), status("stopped"), status("running")])
        let controller = SystemController(client: client)

        try await controller.start()
        if case .running = controller.state {} else {
            Issue.record("expected running state, got \(controller.state)")
        }
        #expect(controller.transition == nil)
    }

    @Test func startFailureThrowsFromTheCommandItself() async throws {
        let client = FakeRuntimeClient()
        client.fail(subcommand: "system")
        let controller = SystemController(client: client)

        await #expect(throws: (any Error).self) {
            try await controller.start()
        }
        #expect(controller.transition == nil)
    }
}
