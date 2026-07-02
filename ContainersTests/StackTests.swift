import Testing
import Foundation
@testable import Containers

struct StackTests {

    private func container(id: String, state: String, project: String? = nil, service: String? = nil, configFiles: String? = nil) -> Container {
        var labels: [String: String] = [:]
        if let project { labels[Container.projectLabelKey] = project }
        if let service { labels["com.docker.compose.service"] = service }
        if let configFiles { labels["com.docker.compose.project.config_files"] = configFiles }
        return Container(
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
                networks: [],
                publishedPorts: [],
                mounts: [],
                dns: nil,
                labels: labels,
                platform: Platform(architecture: "arm64", os: "linux", variant: nil),
                runtimeHandler: "container-runtime-linux",
                readOnly: false,
                rosetta: false
            ),
            status: ContainerStatus(state: state, startedDate: nil, networks: [])
        )
    }

    @Test func derivesStacksFromProjectLabels() {
        let containers = [
            container(id: "shop-web-1", state: "running", project: "shop", service: "web"),
            container(id: "shop-db-1", state: "stopped", project: "shop", service: "db"),
            container(id: "blog-1", state: "running", project: "blog"),
            container(id: "loner", state: "running"),
        ]
        let stacks = Stack.stacks(from: containers)
        #expect(stacks.map(\.name) == ["blog", "shop"])
        let shop = stacks[1]
        #expect(shop.totalCount == 2)
        #expect(shop.runningCount == 1)
        #expect(shop.aggregateState == .partial)
        #expect(stacks[0].aggregateState == .running)
    }

    @Test func membersSortByServiceNameWithIDFallback() {
        let stack = Stack(name: "x", containers: [
            container(id: "zzz", state: "running", project: "x", service: "api"),
            container(id: "aaa-no-service", state: "running", project: "x"),
            container(id: "mmm", state: "running", project: "x", service: "web"),
        ])
        #expect(stack.containers.map(\.id) == ["aaa-no-service", "zzz", "mmm"])
    }

    @Test func aggregateStates() {
        let running = Stack(name: "a", containers: [container(id: "1", state: "running", project: "a")])
        #expect(running.aggregateState == .running)
        let stopped = Stack(name: "b", containers: [container(id: "2", state: "stopped", project: "b")])
        #expect(stopped.aggregateState == .stopped)
    }

    @Test func configFileComesFromLabelFirstPath() {
        let single = container(id: "a", state: "running", project: "p", configFiles: "/Users/dev/app/docker-compose.yml")
        #expect(single.stackConfigFile?.path == "/Users/dev/app/docker-compose.yml")

        let multi = container(id: "b", state: "running", project: "p", configFiles: "/one/compose.yml, /two/override.yml")
        #expect(multi.stackConfigFile?.path == "/one/compose.yml")

        let relative = container(id: "c", state: "running", project: "p", configFiles: "relative/path.yml")
        #expect(relative.stackConfigFile == nil)

        let stack = Stack(name: "p", containers: [
            container(id: "no-label", state: "running", project: "p"),
            single,
        ])
        #expect(stack.configFile?.path == "/Users/dev/app/docker-compose.yml")
    }

    @Test func serviceNameReadsComposeLabel() {
        #expect(container(id: "x", state: "running", service: "cache").serviceName == "cache")
        #expect(container(id: "x", state: "running").serviceName == nil)
    }
}
