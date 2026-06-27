import Testing
import Foundation
@testable import Containers

struct ModelDecodingTests {

    @Test func networkDecodesFromRealJSON() throws {
        let json = """
        [{"configuration":{"creationDate":"2026-06-27T09:37:06Z","labels":{"com.apple.container.resource.role":"builtin"},"mode":"nat","name":"default","options":{},"plugin":"container-network-vmnet"},"id":"default","status":{"ipv4Gateway":"192.168.64.1","ipv4Subnet":"192.168.64.0/24","ipv6Subnet":"fde5:97ab:e9f1:c58::/64"}}]
        """
        let networks = try JSONDecoder().decode([Network].self, from: Data(json.utf8))
        let network = try #require(networks.first)
        #expect(network.id == "default")
        #expect(network.configuration.mode == "nat")
        #expect(network.configuration.plugin == "container-network-vmnet")
        #expect(network.status?.ipv4Subnet == "192.168.64.0/24")
    }

    @Test func containerDecodesFromLiveDaemon() async throws {
        let client = ContainerCLI()
        do {
            let containers = try await client.decode([Container].self, from: ["ls", "--all", "--format", "json"])
            if let demo = containers.first(where: { $0.id == "containers-demo" }) {
                #expect(demo.configuration.image.reference.contains("alpine"))
                #expect(demo.configuration.resources.cpus >= 1)
                #expect(demo.configuration.platform.os == "linux")
            }
        } catch RuntimeError.binaryNotFound, RuntimeError.daemonNotRunning {
        }
    }

    @Test func imageDecodesFromLiveDaemon() async throws {
        let client = ContainerCLI()
        do {
            let images = try await client.decode([ContainerImage].self, from: ["image", "ls", "--format", "json"])
            if let alpine = images.first(where: { $0.configuration.name.contains("alpine") }) {
                #expect(!alpine.configuration.descriptor.digest.isEmpty)
                #expect(!alpine.variants.isEmpty)
            }
        } catch RuntimeError.binaryNotFound, RuntimeError.daemonNotRunning {
        }
    }

    @Test func volumeDecodesFromLiveDaemon() async throws {
        let client = ContainerCLI()
        do {
            let volumes = try await client.decode([Volume].self, from: ["volume", "ls", "--format", "json"])
            for volume in volumes {
                #expect(!volume.configuration.format.isEmpty)
                #expect(volume.configuration.sizeInBytes > 0)
            }
        } catch RuntimeError.binaryNotFound, RuntimeError.daemonNotRunning {
        }
    }
}
