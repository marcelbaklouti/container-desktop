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

    @Test func runOrderRespectsDependsOn() throws {
        let project = try #require(ComposeProject.parse(Self.sample, defaultName: "x"))
        let order = project.runOrder().map(\.name)
        let postgresIndex = try #require(order.firstIndex(of: "postgres"))
        let minioIndex = try #require(order.firstIndex(of: "minio"))
        #expect(postgresIndex < minioIndex)
    }
}
