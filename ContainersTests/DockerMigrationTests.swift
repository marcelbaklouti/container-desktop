import Testing
import Foundation
@testable import Containers

struct DockerMigrationTests {

    static let inspectFixture = """
    [{
      "Id": "97a4e02dd2dc0f00aa11bb22cc33dd44ee55ff6677889900aabbccddeeff0011",
      "Name": "/container-desktop-test-cache",
      "State": { "Status": "running", "Running": true },
      "Config": {
        "Image": "valkey/valkey:8-alpine",
        "Env": [
          "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
          "VALKEY_VERSION=8.1.8",
          "CACHE_MODE=aggressive"
        ],
        "Cmd": ["valkey-server", "--appendonly", "yes"],
        "Entrypoint": ["docker-entrypoint.sh"],
        "Labels": {
          "com.docker.compose.project": "container-desktop-test",
          "com.docker.compose.service": "cache",
          "url": "https://catalog.redhat.com/en/search?searchType=containers",
          "vendor": "Container Desktop Test",
          "custom.container.label": "kept"
        },
        "WorkingDir": "/data",
        "User": "",
        "ExposedPorts": { "6379/tcp": {} }
      },
      "HostConfig": {
        "Binds": null,
        "PortBindings": {
          "6379/tcp": [ { "HostIp": "", "HostPort": "6379" } ],
          "9999/udp": [ { "HostIp": "127.0.0.1", "HostPort": "9999" } ]
        },
        "RestartPolicy": { "Name": "unless-stopped", "MaximumRetryCount": 0 },
        "Memory": 536870912,
        "NanoCpus": 2000000000,
        "NetworkMode": "container-desktop-test_default"
      },
      "Mounts": [
        {
          "Type": "volume",
          "Name": "container-desktop-test-data",
          "Source": "/var/lib/docker/volumes/container-desktop-test-data/_data",
          "Destination": "/data",
          "RW": true
        },
        {
          "Type": "bind",
          "Source": "/host_mnt/private/tmp",
          "Destination": "/etc/app",
          "RW": false
        },
        {
          "Type": "bind",
          "Source": "/Users/container-desktop-test/missing",
          "Destination": "/etc/gone",
          "RW": true
        }
      ]
    }]
    """

    static let imageFixture = """
    [{
      "Config": {
        "Env": [
          "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
          "VALKEY_VERSION=8.1.8"
        ],
        "Cmd": ["valkey-server"],
        "Entrypoint": ["docker-entrypoint.sh"],
        "Labels": {
          "url": "https://catalog.redhat.com/en/search?searchType=containers",
          "vendor": "Container Desktop Test"
        },
        "WorkingDir": "/data",
        "User": ""
      },
      "RepoDigests": ["valkey/valkey@sha256:abc123"],
      "Size": 62914560
    }]
    """

    private func fixtureContainer() throws -> DockerContainer {
        try #require(try JSONDecoder().decode([DockerContainer].self, from: Data(Self.inspectFixture.utf8)).first)
    }

    private func fixtureImage() throws -> DockerImage {
        try #require(try JSONDecoder().decode([DockerImage].self, from: Data(Self.imageFixture.utf8)).first)
    }

    @Test func decodesRealInspectShape() throws {
        let container = try fixtureContainer()
        #expect(container.displayName == "container-desktop-test-cache")
        #expect(container.project == "container-desktop-test")
        #expect(container.isRunning)
        #expect(container.namedVolumeMounts.count == 1)
        #expect(container.namedVolumeMounts.first?.name == "container-desktop-test-data")
        #expect(container.hostConfig.restartPolicy?.name == "unless-stopped")
    }

    @Test func registryResolvableComesFromRepoDigests() throws {
        let pulled = try fixtureImage()
        #expect(pulled.isRegistryResolvable)
        let localOnly = try JSONDecoder().decode(
            [DockerImage].self,
            from: Data("[{\"Config\": {}, \"RepoDigests\": [], \"Size\": 1}]".utf8)
        ).first
        #expect(localOnly?.isRegistryResolvable == false)
    }

    @Test func createArgumentsDiffAgainstImageDefaults() throws {
        let container = try fixtureContainer()
        let image = try fixtureImage()
        let plan = DockerMigrator.createArguments(for: container, imageDefaults: image)
        let args = plan.arguments

        #expect(args.first == "create")
        #expect(args.contains("container-desktop-test-cache"))

        let envIndexes = args.indices.filter { args[$0] == "-e" }.map { args[$0 + 1] }
        #expect(envIndexes == ["CACHE_MODE=aggressive"])

        let ports = args.indices.filter { args[$0] == "-p" }.map { args[$0 + 1] }
        #expect(ports.contains("6379:6379"))
        #expect(ports.contains("127.0.0.1:9999:9999/udp"))

        let volumes = args.indices.filter { args[$0] == "-v" }.map { args[$0 + 1] }
        #expect(volumes.contains("container-desktop-test-data:/data"))
        #expect(volumes.contains("/private/tmp:/etc/app:ro"))
        #expect(!volumes.contains { $0.contains("/etc/gone") })
        #expect(plan.notes.contains { $0.contains("/etc/gone") })

        #expect(!args.contains("--entrypoint"))
        #expect(!args.contains("--workdir"))

        let cpusIndex = try #require(args.firstIndex(of: "--cpus"))
        #expect(args[cpusIndex + 1] == "2")
        let memoryIndex = try #require(args.firstIndex(of: "--memory"))
        #expect(args[memoryIndex + 1] == "536870912")

        #expect(args.contains("\(DockerMigrator.migrationLabelKey)=docker"))
        let terminator = try #require(args.firstIndex(of: "--"))
        #expect(args[terminator + 1] == "valkey/valkey:8-alpine")
        #expect(args.suffix(from: terminator + 2) == ["valkey-server", "--appendonly", "yes"])

        #expect(plan.notes.contains { $0.contains("unless-stopped") })
        #expect(plan.notes.contains { $0.contains("container-desktop-test_default") })
    }

    @Test func defaultCommandAndEntrypointAreOmitted() throws {
        var fixture = Self.inspectFixture
        fixture = fixture.replacingOccurrences(
            of: "\"Cmd\": [\"valkey-server\", \"--appendonly\", \"yes\"]",
            with: "\"Cmd\": [\"valkey-server\"]"
        )
        let container = try #require(try JSONDecoder().decode([DockerContainer].self, from: Data(fixture.utf8)).first)
        let image = try fixtureImage()
        let args = DockerMigrator.createArguments(for: container, imageDefaults: image).arguments
        let terminator = try #require(args.firstIndex(of: "--"))
        #expect(args.suffix(from: terminator + 1) == ["valkey/valkey:8-alpine"])
    }

    @Test func imageBakedLabelsAreNotReapplied() throws {
        let container = try fixtureContainer()
        let image = try fixtureImage()
        let args = DockerMigrator.createArguments(for: container, imageDefaults: image).arguments
        let labels = args.indices.filter { args[$0] == "--label" }.map { args[$0 + 1] }
        #expect(labels.contains("com.docker.compose.project=container-desktop-test"))
        #expect(labels.contains("custom.container.label=kept"))
        #expect(!labels.contains { $0.hasPrefix("url=") })
        #expect(!labels.contains { $0.hasPrefix("vendor=") })
    }

    @Test func essentialLabelsFallbackKeepsOnlyComposeGrouping() throws {
        let container = try fixtureContainer()
        let image = try fixtureImage()
        let args = DockerMigrator.createArguments(for: container, imageDefaults: image, essentialLabelsOnly: true).arguments
        let labels = args.indices.filter { args[$0] == "--label" }.map { args[$0 + 1] }
        #expect(labels.contains("com.docker.compose.project=container-desktop-test"))
        #expect(labels.contains("com.docker.compose.service=cache"))
        #expect(labels.contains("\(DockerMigrator.migrationLabelKey)=docker"))
        #expect(!labels.contains("custom.container.label=kept"))
    }

    @Test func hostMountPathsNormalizeToTheMacFilesystem() {
        #expect(DockerMigrator.normalizedHostPath("/host_mnt/Users/dev/project") == "/Users/dev/project")
        #expect(DockerMigrator.normalizedHostPath("/Users/dev/project") == "/Users/dev/project")
        #expect(DockerMigrator.normalizedHostPath("/host_mnt/private/tmp") == "/private/tmp")
    }

    @Test func dockerSubprocessPathIncludesCredentialHelperDirectories() {
        let path = DockerCLI.subprocessEnvironment["PATH"] ?? ""
        #expect(path.contains("/Applications/Docker.app/Contents/Resources/bin"))
        #expect(path.contains(".docker/bin"))
    }

    @Test func canonicalReferenceMatchesAppleNaming() {
        #expect(DockerMigrator.canonicalReference("alpine:3") == "docker.io/library/alpine:3")
        #expect(DockerMigrator.canonicalReference("alpine") == "docker.io/library/alpine:latest")
        #expect(DockerMigrator.canonicalReference("pgvector/pgvector:pg16") == "docker.io/pgvector/pgvector:pg16")
        #expect(DockerMigrator.canonicalReference("ghcr.io/owner/app:2") == "ghcr.io/owner/app:2")

        let present: Set<String> = ["docker.io/library/alpine:3", "docker.io/pgvector/pgvector:pg16"]
        #expect(DockerMigrator.imageIsPresent("alpine:3", in: present))
        #expect(DockerMigrator.imageIsPresent("pgvector/pgvector:pg16", in: present))
        #expect(!DockerMigrator.imageIsPresent("postgres:16", in: present))
    }
}
