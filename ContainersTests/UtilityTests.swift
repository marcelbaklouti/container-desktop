import Testing
import Foundation
@testable import Containers

struct ShellQuotingTests {

    @Test func safeWordsStayBare() {
        #expect(ShellQuoting.quoted("nginx:1.27") == "nginx:1.27")
        #expect(ShellQuoting.quoted("--detach") == "--detach")
        #expect(ShellQuoting.quoted("8080:80/udp") == "8080:80/udp")
        #expect(ShellQuoting.quoted("KEY=value") == "KEY=value")
        #expect(ShellQuoting.quoted("/var/lib/data") == "/var/lib/data")
    }

    @Test func unsafeWordsAreSingleQuoted() {
        #expect(ShellQuoting.quoted("hello world") == "'hello world'")
        #expect(ShellQuoting.quoted("a\"b") == "'a\"b'")
        #expect(ShellQuoting.quoted("$HOME") == "'$HOME'")
        #expect(ShellQuoting.quoted("a\nb") == "'a\nb'")
        #expect(ShellQuoting.quoted("ümlaut") == "'ümlaut'")
        #expect(ShellQuoting.quoted("") == "''")
    }

    @Test func embeddedSingleQuotesEscapeSafely() {
        #expect(ShellQuoting.quoted("it's") == "'it'\\''s'")
        #expect(ShellQuoting.alwaysQuoted("plain") == "'plain'")
    }

    @Test func joinedProducesPasteableCommand() {
        let command = ShellQuoting.joined(["container", "run", "--name", "my app", "-e", "GREETING=hello world", "--", "alpine:3"])
        #expect(command == "container run --name 'my app' -e 'GREETING=hello world' -- alpine:3")
    }

    @Test func privilegedRunnerStillAlwaysQuotes() {
        #expect(PrivilegedRunner.posixQuoted("safe") == "'safe'")
        #expect(PrivilegedRunner.posixQuoted("a'b") == "'a'\\''b'")
    }
}

struct UsageIndexTests {

    private func container(id: String, state: String, volume: String? = nil, network: String? = nil) -> Container {
        Container(
            id: id,
            configuration: ContainerConfiguration(
                id: id,
                creationDate: "2026-07-02T00:00:00Z",
                image: ContainerImageReference(
                    reference: "docker.io/library/alpine:latest",
                    descriptor: OCIDescriptor(digest: "sha256:x", mediaType: "application/vnd.oci.image.index.v1+json", size: 1)
                ),
                initProcess: ContainerProcess(
                    executable: "/bin/sh",
                    arguments: [],
                    environment: [],
                    workingDirectory: "/",
                    terminal: false,
                    user: ContainerProcessUser(id: ContainerProcessUserID(uid: 0, gid: 0))
                ),
                resources: ContainerResources(cpus: 1, memoryInBytes: 1, cpuOverhead: 0),
                networks: network.map { [ContainerNetworkAttachment(network: $0)] } ?? [],
                publishedPorts: [],
                mounts: volume.map {
                    [ContainerMount(destination: "/data", source: $0, options: [], type: MountType(volume: MountVolume(name: $0, format: nil), bind: nil, tmpfs: nil))]
                } ?? [],
                dns: nil,
                labels: [:],
                platform: Platform(architecture: "arm64", os: "linux", variant: nil),
                runtimeHandler: "container-runtime-linux",
                readOnly: false,
                rosetta: false
            ),
            status: ContainerStatus(state: state, startedDate: nil, networks: [])
        )
    }

    @Test func findsContainersMountingVolume() {
        let containers = [
            container(id: "db", state: "running", volume: "pgdata"),
            container(id: "web", state: "stopped"),
            container(id: "worker", state: "stopped", volume: "pgdata"),
        ]
        let mounting = UsageIndex.containersMounting("pgdata", in: containers)
        #expect(mounting.map(\.id) == ["db", "worker"])
        #expect(UsageIndex.containersMounting("other", in: containers).isEmpty)
    }

    @Test func findsContainersAttachedToNetwork() {
        let containers = [
            container(id: "api", state: "running", network: "backend"),
            container(id: "cache", state: "running", network: "default"),
        ]
        #expect(UsageIndex.containersAttached("backend", in: containers).map(\.id) == ["api"])
        #expect(UsageIndex.containersAttached("missing", in: containers).isEmpty)
    }
}

struct PollIntervalTests {

    @Test func tiersMapToExpectedDurations() {
        #expect(PollInterval.fast.containers == .seconds(1.5))
        #expect(PollInterval.standard.containers == .seconds(3))
        #expect(PollInterval.relaxed.containers == .seconds(5))
        #expect(PollInterval.standard.secondary == .seconds(4))
        #expect(PollInterval.standard.images == .seconds(5))
    }

    @Test func currentFallsBackToStandard() {
        let defaults = UserDefaults(suiteName: "PollIntervalTests")!
        defaults.removeObject(forKey: "pollInterval")
        #expect(PollInterval.current(from: defaults) == .standard)
        defaults.set("fast", forKey: "pollInterval")
        #expect(PollInterval.current(from: defaults) == .fast)
        defaults.set("garbage", forKey: "pollInterval")
        #expect(PollInterval.current(from: defaults) == .standard)
        defaults.removeObject(forKey: "pollInterval")
    }
}
