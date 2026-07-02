import Testing
import Foundation
@testable import Containers

struct ComposeParsingTests {
    static let sample = """
    name: multi-container-example
    services:
      postgres:
        image: pgvector/pgvector:pg16
        container_name: postgres
        environment:
          POSTGRES_PASSWORD: secret
          PGDATA: /var/lib/postgresql/data/pgdata
        ports:
          - "5432:5432"
        volumes:
          - pgdata:/var/lib/postgresql/data
      valkey:
        image: valkey/valkey:8-alpine
        ports:
          - "6379:6379"
      minio:
        image: minio/minio:latest
        command: server /data --console-address ":9001"
        environment:
          - MINIO_ROOT_USER=minioadmin
          - MINIO_ROOT_PASSWORD=minioadmin
        ports:
          - "9000:9000"
          - "9001:9001"
        depends_on:
          - postgres
      mailpit:
        image: axllent/mailpit:latest
        labels:
          - traefik.enable=true
        ports:
          - target: 8025
            published: 8025
    volumes:
      pgdata:
    """

    @Test func parsesProjectNameAndServices() throws {
        let project = try #require(ComposeProject.parse(Self.sample, defaultName: "fallback"))
        #expect(project.name == "multi-container-example")
        #expect(project.services.count == 4)
        #expect(project.namedVolumes == ["pgdata"])
    }

    @Test func parsesServiceFields() throws {
        let project = try #require(ComposeProject.parse(Self.sample, defaultName: "x"))
        let postgres = try #require(project.services.first { $0.name == "postgres" })
        #expect(postgres.image == "pgvector/pgvector:pg16")
        #expect(postgres.containerName == "postgres")
        #expect(postgres.ports == ["5432:5432"])
        #expect(postgres.volumes == ["pgdata:/var/lib/postgresql/data"])
        #expect(postgres.environment.sorted() == ["PGDATA=/var/lib/postgresql/data/pgdata", "POSTGRES_PASSWORD=secret"])
    }

    @Test func parsesCommandRespectingQuotes() throws {
        let project = try #require(ComposeProject.parse(Self.sample, defaultName: "x"))
        let minio = try #require(project.services.first { $0.name == "minio" })
        #expect(minio.command == ["server", "/data", "--console-address", ":9001"])
        #expect(minio.environment.contains("MINIO_ROOT_USER=minioadmin"))
        #expect(minio.ports == ["9000:9000", "9001:9001"])
        #expect(minio.dependsOn == ["postgres"])
    }

    @Test func parsesLongSyntaxPortsAndLabels() throws {
        let project = try #require(ComposeProject.parse(Self.sample, defaultName: "x"))
        let mailpit = try #require(project.services.first { $0.name == "mailpit" })
        #expect(mailpit.ports == ["8025:8025"])
        #expect(mailpit.labels["traefik.enable"] == "true")
    }

    @Test func normalizesPortsForContainerRun() throws {
        let source = """
        name: ports-demo
        services:
          web:
            image: nginx:latest
            ports:
              - "3000"
              - "5000/udp"
              - "8080:80"
          api:
            image: example/api:latest
            ports:
              - target: 9090
        """
        let project = try #require(ComposeProject.parse(source, defaultName: "x"))
        let web = try #require(project.services.first { $0.name == "web" })
        #expect(web.ports == ["3000:3000", "5000:5000/udp", "8080:80"])
        let api = try #require(project.services.first { $0.name == "api" })
        #expect(api.ports == [])
    }

    @Test func interpolatesEnvironmentVariables() throws {
        let source = """
        name: interp
        services:
          db:
            image: postgres:${PG_TAG:-16}
            environment:
              POSTGRES_USER: ${POSTGRES_USER:-container-desktop-test}
            ports:
              - '${POSTGRES_PORT:-5432}:5432'
              - '${EXTRA_PORT-7000}:7000'
        """
        let defaults = try #require(ComposeProject.parse(source, defaultName: "x"))
        let db = try #require(defaults.services.first { $0.name == "db" })
        #expect(db.image == "postgres:16")
        #expect(db.ports == ["5432:5432", "7000:7000"])
        #expect(db.environment == ["POSTGRES_USER=container-desktop-test"])

        let overridden = try #require(ComposeProject.parse(
            source, defaultName: "x",
            environment: ["POSTGRES_PORT": "6000", "PG_TAG": "17"]))
        let db2 = try #require(overridden.services.first { $0.name == "db" })
        #expect(db2.image == "postgres:17")
        #expect(db2.ports == ["6000:5432", "7000:7000"])
    }

    @Test func interpolationHandlesEscapesAndAlternates() throws {
        let env = ["SET": "yes", "EMPTY": ""]
        #expect(ComposeInterpolation.expand("$$HOME", environment: env) == "$HOME")
        #expect(ComposeInterpolation.expand("${SET:+on}", environment: env) == "on")
        #expect(ComposeInterpolation.expand("${EMPTY:+on}", environment: env) == "")
        #expect(ComposeInterpolation.expand("${EMPTY:-fallback}", environment: env) == "fallback")
        #expect(ComposeInterpolation.expand("${EMPTY-keep}", environment: env) == "")
        #expect(ComposeInterpolation.expand("${MISSING:-${SET}}", environment: env) == "yes")
    }

    @Test func runOrderRespectsDependsOn() throws {
        let project = try #require(ComposeProject.parse(Self.sample, defaultName: "x"))
        let order = project.runOrder().map(\.name)
        let postgresIndex = try #require(order.firstIndex(of: "postgres"))
        let minioIndex = try #require(order.firstIndex(of: "minio"))
        #expect(postgresIndex < minioIndex)
    }

    static let buildSample = """
    name: container-desktop-test-build
    services:
      api:
        build: ./api
        ports:
          - "3000:3000"
      worker:
        build:
          context: ./worker
          dockerfile: Dockerfile.worker
          target: runtime
          args:
            - VERSION=${VER:-1.2}
            - MODE=fast
        depends_on:
          - api
      cache:
        image: valkey/valkey:8-alpine
      tagged:
        image: registry.example.com/team/app:2
        build:
          context: .
    """

    @Test func parsesShorthandAndMappingBuild() throws {
        let project = try #require(ComposeProject.parse(Self.buildSample, defaultName: "x"))
        let api = try #require(project.services.first { $0.name == "api" })
        #expect(api.build == ComposeBuild(context: "./api", dockerfile: nil, args: [], target: nil))
        let worker = try #require(project.services.first { $0.name == "worker" })
        #expect(worker.build?.context == "./worker")
        #expect(worker.build?.dockerfile == "Dockerfile.worker")
        #expect(worker.build?.target == "runtime")
        #expect(worker.build?.args == ["VERSION=1.2", "MODE=fast"])
        let cache = try #require(project.services.first { $0.name == "cache" })
        #expect(cache.build == nil)
    }

    @Test func buildArgsInterpolateFromEnvironment() throws {
        let project = try #require(ComposeProject.parse(Self.buildSample, defaultName: "x", environment: ["VER": "9.9"]))
        let worker = try #require(project.services.first { $0.name == "worker" })
        #expect(worker.build?.args.first == "VERSION=9.9")
    }

    @Test func imageTagFollowsComposeNamingConvention() throws {
        let project = try #require(ComposeProject.parse(Self.buildSample, defaultName: "x"))
        let api = try #require(project.services.first { $0.name == "api" })
        #expect(api.imageTag(in: project) == "container-desktop-test-build-api")
        let tagged = try #require(project.services.first { $0.name == "tagged" })
        #expect(tagged.imageTag(in: project) == "registry.example.com/team/app:2")
        let cache = try #require(project.services.first { $0.name == "cache" })
        #expect(cache.imageTag(in: project) == "valkey/valkey:8-alpine")
    }

    @Test func buildArgumentsResolvePathsAgainstComposeDirectory() throws {
        let directory = URL(fileURLWithPath: "/tmp/container-desktop-test-build", isDirectory: true)
        let project = try #require(ComposeProject.parse(Self.buildSample, defaultName: "x", directory: directory))
        let worker = try #require(project.services.first { $0.name == "worker" })
        let args = try #require(worker.buildArguments(in: project))
        #expect(args.first == "build")
        #expect(args.contains("--progress"))
        let tagIndex = try #require(args.firstIndex(of: "-t"))
        #expect(args[tagIndex + 1] == "container-desktop-test-build-worker")
        let fileIndex = try #require(args.firstIndex(of: "-f"))
        #expect(args[fileIndex + 1] == "/tmp/container-desktop-test-build/worker/Dockerfile.worker")
        let targetIndex = try #require(args.firstIndex(of: "--target"))
        #expect(args[targetIndex + 1] == "runtime")
        #expect(args.last == "/tmp/container-desktop-test-build/worker")
        #expect(args.contains("--build-arg"))
    }

    @Test func builtServiceRunsItsBuiltTag() throws {
        let project = try #require(ComposeProject.parse(Self.buildSample, defaultName: "x"))
        let api = try #require(project.services.first { $0.name == "api" })
        let run = api.runArguments(in: project)
        #expect(run.contains("container-desktop-test-build-api"))
    }

    @Test func runArgumentsCarryStackIdentityLabels() throws {
        var project = try #require(ComposeProject.parse(Self.sample, defaultName: "x"))
        project.configFileURL = URL(fileURLWithPath: "/Users/dev/shop/docker-compose.yml")
        let service = try #require(project.services.first { $0.name == "valkey" })
        let args = service.runArguments(in: project)
        #expect(args.contains("com.docker.compose.project.config_files=/Users/dev/shop/docker-compose.yml"))
        #expect(args.contains("com.docker.compose.project.working_dir=/Users/dev/shop"))
    }

    @Test func runArgumentsOmitStackLabelsWithoutConfigFile() throws {
        let project = try #require(ComposeProject.parse(Self.sample, defaultName: "x"))
        let service = try #require(project.services.first { $0.name == "valkey" })
        let args = service.runArguments(in: project)
        #expect(!args.contains { $0.hasPrefix("com.docker.compose.project.config_files=") })
    }
}
