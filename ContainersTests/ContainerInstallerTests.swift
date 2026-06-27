import Testing
import Foundation
@testable import Containers

struct ContainerInstallerTests {
    @Test func versionCompareOrders() {
        #expect(ContainerInstaller.compare("1.0.0", "1.0.0") == .orderedSame)
        #expect(ContainerInstaller.compare("1.0.0", "1.0.1") == .orderedAscending)
        #expect(ContainerInstaller.compare("1.2.0", "1.1.9") == .orderedDescending)
        #expect(ContainerInstaller.compare("1.0", "1.0.0") == .orderedSame)
        #expect(ContainerInstaller.compare("2.0.0", "10.0.0") == .orderedAscending)
        #expect(ContainerInstaller.compare("1.0.1", "1.0.0") == .orderedDescending)
    }

    @Test func requiredVersionTracksApp() {
        #expect(ContainerInstaller.requiredVersion == "1.0.0")
    }
}
