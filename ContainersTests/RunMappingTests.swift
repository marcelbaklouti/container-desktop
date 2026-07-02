import Testing
import Foundation
@testable import Containers

@MainActor
struct RunMappingTests {

    private func makeContainer(
        id: String = "cdt-db",
        executable: String = "docker-entrypoint.sh",
        arguments: [String] = ["postgres"],
        environment: [String] = ["PATH=/usr/bin", "POSTGRES_PASSWORD=secret"],
        ports: [PublishedPort] = [PublishedPort(hostAddress: "", hostPort: 5432, containerPort: 5432, proto: "tcp")],
        mounts: [ContainerMount] = [],
        labels: [String: String] = [:],
        cpus: Int = 2,
        memory: Int = 1_073_741_824,
        network: String = "default",
        architecture: String = "arm64",
        uid: Int = 0
    ) -> Container {
        Container(
            id: id,
            configuration: ContainerConfiguration(
                id: id,
                creationDate: "2026-07-02T00:00:00Z",
                image: ContainerImageReference(
                    reference: "docker.io/pgvector/pgvector:pg16",
                    descriptor: OCIDescriptor(digest: "sha256:x", mediaType: "application/vnd.oci.image.index.v1+json", size: 1)
                ),
                initProcess: ContainerProcess(
                    executable: executable,
                    arguments: arguments,
                    environment: environment,
                    workingDirectory: "/",
                    terminal: false,
                    user: ContainerProcessUser(id: ContainerProcessUserID(uid: uid, gid: uid))
                ),
                resources: ContainerResources(cpus: cpus, memoryInBytes: memory, cpuOverhead: 0),
                networks: [ContainerNetworkAttachment(network: network)],
                publishedPorts: ports,
                mounts: mounts,
                dns: nil,
                labels: labels,
                platform: Platform(architecture: architecture, os: "linux", variant: nil),
                runtimeHandler: "container-runtime-linux",
                readOnly: false,
                rosetta: architecture == "amd64"
            ),
            status: ContainerStatus(state: "stopped", startedDate: nil, networks: [])
        )
    }

    private var imageConfig: ImageRuntimeConfig {
        ImageRuntimeConfig(
            env: ["PATH=/usr/bin"],
            cmd: ["postgres"],
            entrypoint: ["docker-entrypoint.sh"],
            workingDir: "/",
            user: "",
            labels: ["vendor": "postgres"]
        )
    }

    @Test func entrypointImageWithDefaultCommandMapsClean() {
        var notes: [String] = []
        let config = RunConfiguration(duplicating: makeContainer(), imageConfig: imageConfig, existingIDs: [], notes: &notes)
        #expect(config.image == "docker.io/pgvector/pgvector:pg16")
        #expect(config.entrypoint.isEmpty)
        #expect(config.command.isEmpty)
        #expect(config.environment.map(\.key) == ["POSTGRES_PASSWORD"])
        #expect(config.ports.map(\.text) == ["5432:5432"])
        #expect(config.cpus == "2")
        #expect(config.memory == "1G")
        #expect(config.network.isEmpty)
    }

    @Test func overriddenCommandKeepsEntrypointAndMapsArgs() {
        var notes: [String] = []
        let container = makeContainer(arguments: ["postgres", "-c", "log_statement=all"])
        let config = RunConfiguration(duplicating: container, imageConfig: imageConfig, existingIDs: [], notes: &notes)
        #expect(config.entrypoint.isEmpty)
        #expect(config.command == "postgres -c log_statement=all")
    }

    @Test func overriddenEntrypointMaps() {
        var notes: [String] = []
        let container = makeContainer(executable: "/bin/sh", arguments: ["-c", "echo hi"])
        let config = RunConfiguration(duplicating: container, imageConfig: imageConfig, existingIDs: [], notes: &notes)
        #expect(config.entrypoint == "/bin/sh")
        #expect(config.command == "-c \"echo hi\"")
    }

    @Test func missingImageConfigCarriesVerbatimWithNote() {
        var notes: [String] = []
        let config = RunConfiguration(duplicating: makeContainer(), imageConfig: nil, existingIDs: [], notes: &notes)
        #expect(config.entrypoint == "docker-entrypoint.sh")
        #expect(config.command == "postgres")
        #expect(notes.contains { $0.contains("couldn’t be checked") })
    }

    @Test func mountsMapToVolumesAndTmpfs() {
        var notes: [String] = []
        let mounts = [
            ContainerMount(destination: "/data", source: "pgdata", options: [], type: MountType(volume: MountVolume(name: "pgdata", format: nil), bind: nil, tmpfs: nil)),
            ContainerMount(destination: "/etc/cfg", source: "/host/cfg", options: ["ro"], type: MountType(volume: nil, bind: MountEmpty(), tmpfs: nil)),
            ContainerMount(destination: "/scratch", source: "", options: [], type: MountType(volume: nil, bind: nil, tmpfs: MountEmpty())),
        ]
        let config = RunConfiguration(duplicating: makeContainer(mounts: mounts), imageConfig: imageConfig, existingIDs: [], notes: &notes)
        #expect(config.volumes.map(\.text) == ["pgdata:/data", "/host/cfg:/etc/cfg:ro"])
        #expect(config.tmpfs.map(\.text) == ["/scratch"])
    }

    @Test func hostAddressAndUDPPortsMap() {
        var notes: [String] = []
        let ports = [
            PublishedPort(hostAddress: "127.0.0.1", hostPort: 9999, containerPort: 9999, proto: "udp"),
            PublishedPort(hostAddress: "0.0.0.0", hostPort: 8080, containerPort: 80, proto: "tcp"),
        ]
        let config = RunConfiguration(duplicating: makeContainer(ports: ports), imageConfig: imageConfig, existingIDs: [], notes: &notes)
        #expect(config.ports.map(\.text) == ["127.0.0.1:9999:9999/udp", "8080:80"])
    }

    @Test func reservedAndImageLabelsAreFiltered() {
        var notes: [String] = []
        let labels = [
            Container.projectLabelKey: "shop",
            "com.docker.compose.service": "db",
            DockerMigrator.migrationLabelKey: "docker",
            "vendor": "postgres",
            "custom": "kept",
        ]
        let config = RunConfiguration(duplicating: makeContainer(labels: labels), imageConfig: imageConfig, existingIDs: [], notes: &notes)
        #expect(config.project == "shop")
        #expect(config.labels.map(\.key) == ["custom"])
    }

    @Test func intelContainersMapToRosettaPlatform() {
        var notes: [String] = []
        let config = RunConfiguration(duplicating: makeContainer(architecture: "amd64"), imageConfig: imageConfig, existingIDs: [], notes: &notes)
        #expect(config.platform == .intel)
        #expect(config.rosetta)
    }

    @Test func nonRootUserMaps() {
        var notes: [String] = []
        let config = RunConfiguration(duplicating: makeContainer(uid: 999), imageConfig: imageConfig, existingIDs: [], notes: &notes)
        #expect(config.user == "999:999")
    }

    @Test func nameSuffixSkipsTaken() {
        #expect(RunConfiguration.nextFreeName(from: "web", existing: []) == "web-2")
        #expect(RunConfiguration.nextFreeName(from: "web", existing: ["web-2"]) == "web-3")
        #expect(RunConfiguration.nextFreeName(from: "web-2", existing: ["web-2"]) == "web-3")
        #expect(RunConfiguration.nextFreeName(from: "cdt-db-1", existing: ["cdt-db-2", "cdt-db-3"]) == "cdt-db-4")
    }

    @Test func memoryTextCompactForms() {
        #expect(MemoryText.compact(1_073_741_824) == "1G")
        #expect(MemoryText.compact(2_147_483_648) == "2G")
        #expect(MemoryText.compact(536_870_912) == "512M")
        #expect(MemoryText.compact(0) == "")
    }

    @Test func copyCommandKeepsRealNameAndQuotes() {
        let container = makeContainer(environment: ["PATH=/usr/bin", "GREETING=hello world"])
        let command = RunCommandFormatter.command(for: container, imageConfig: imageConfig)
        #expect(command.hasPrefix("container run"))
        #expect(command.contains("--name cdt-db"))
        #expect(command.contains("'GREETING=hello world'"))
        #expect(command.contains("-- docker.io/pgvector/pgvector:pg16"))
    }
}
