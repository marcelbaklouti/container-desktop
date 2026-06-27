import Testing
import Foundation
@testable import Containers

struct SystemModelTests {

    @Test func systemStatusDecodesFromRealJSON() throws {
        let json = """
        {"apiServerAppName":"container-apiserver","apiServerBuild":"release","apiServerCommit":"ee848e3","apiServerVersion":"container-apiserver version 1.0.0 (build: release, commit: ee848e3)","appRoot":"/x/","installRoot":"/usr/local/","status":"running"}
        """
        let status = try JSONDecoder().decode(SystemStatus.self, from: Data(json.utf8))
        #expect(status.isRunning)
        #expect(status.apiServerVersion?.contains("1.0.0") == true)
    }

    @Test func diskUsageDecodesFromRealJSON() throws {
        let json = """
        {"containers":{"active":1,"reclaimable":0,"sizeInBytes":268091392,"total":1},"images":{"active":1,"reclaimable":240828416,"sizeInBytes":893018112,"total":2},"volumes":{"active":0,"reclaimable":69390336,"sizeInBytes":69390336,"total":1}}
        """
        let usage = try JSONDecoder().decode(DiskUsage.self, from: Data(json.utf8))
        #expect(usage.images.total == 2)
        #expect(usage.volumes.reclaimable == 69390336)
    }
}

@MainActor
struct SystemControllerTests {

    @Test func missingBinaryYieldsBinaryMissing() async {
        let controller = SystemController(client: ContainerCLI(searchDirectories: ["/nonexistent"]))
        await controller.refresh()
        #expect(controller.state == .binaryMissing)
    }

    @Test func runningDaemonReadsStatusAndDiskUsage() async {
        let controller = SystemController()
        await controller.refresh()
        if case .running = controller.state {
            #expect(controller.status?.isRunning == true)
            #expect(controller.diskUsage != nil)
            #expect(controller.cliVersion != nil)
        }
    }
}
