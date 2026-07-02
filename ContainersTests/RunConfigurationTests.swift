import Testing
import Foundation
@testable import Containers

@MainActor
struct RunConfigurationTests {

    @Test func advancedFieldsEmitTheirFlags() {
        var config = RunConfiguration()
        config.image = "alpine:3"
        config.entrypoint = "/bin/sh"
        config.user = "1000:1000"
        config.workingDirectory = "/app"
        config.tmpfs = [TextItem(text: "/tmp/cache")]
        config.labels = [KeyValue(key: "team", value: "core")]
        config.forwardSSHAgent = true

        let args = config.arguments
        #expect(args.contains(["--entrypoint", "/bin/sh"].joined(separator: " ")) == false)
        let entrypointIndex = args.firstIndex(of: "--entrypoint")
        #expect(entrypointIndex != nil && args[entrypointIndex! + 1] == "/bin/sh")
        let userIndex = args.firstIndex(of: "--user")
        #expect(userIndex != nil && args[userIndex! + 1] == "1000:1000")
        let workdirIndex = args.firstIndex(of: "--workdir")
        #expect(workdirIndex != nil && args[workdirIndex! + 1] == "/app")
        let tmpfsIndex = args.firstIndex(of: "--tmpfs")
        #expect(tmpfsIndex != nil && args[tmpfsIndex! + 1] == "/tmp/cache")
        #expect(args.contains("--ssh"))
        let labelIndexes = args.indices.filter { args[$0] == "--label" }.map { args[$0 + 1] }
        #expect(labelIndexes.contains("team=core"))
    }

    @Test func appleSiliconEmitsNoPlatformFlags() {
        var config = RunConfiguration()
        config.image = "alpine:3"
        let args = config.arguments
        #expect(!args.contains("--arch"))
        #expect(!args.contains("--rosetta"))
        #expect(!args.contains("--ssh"))
    }

    @Test func intelEmitsArchAndOptionalRosetta() {
        var config = RunConfiguration()
        config.image = "alpine:3"
        config.platform = .intel
        var args = config.arguments
        let archIndex = args.firstIndex(of: "--arch")
        #expect(archIndex != nil && args[archIndex! + 1] == "amd64")
        #expect(args.contains("--rosetta"))

        config.rosetta = false
        args = config.arguments
        #expect(args.contains("--arch"))
        #expect(!args.contains("--rosetta"))
    }

    @Test func commandTokenizesRespectingQuotes() {
        var config = RunConfiguration()
        config.image = "minio/minio"
        config.command = "server /data --console-address \":9001\""
        let args = config.arguments
        let terminator = args.firstIndex(of: "--")
        #expect(terminator != nil)
        #expect(Array(args.suffix(from: terminator! + 1)) == ["minio/minio", "server", "/data", "--console-address", ":9001"])
    }

    @Test func terminatorAlwaysPrecedesImage() {
        var config = RunConfiguration()
        config.image = "alpine:3"
        let args = config.arguments
        let terminator = args.firstIndex(of: "--")
        #expect(terminator != nil)
        #expect(args[terminator! + 1] == "alpine:3")
    }

    @Test func reservedProjectLabelIsFilteredAndInvalid() {
        var config = RunConfiguration()
        config.image = "alpine:3"
        config.labels = [KeyValue(key: Container.projectLabelKey, value: "sneaky")]
        #expect(!config.isValid)
        let labels = config.arguments.indices.filter { config.arguments[$0] == "--label" }.map { config.arguments[$0 + 1] }
        #expect(!labels.contains("\(Container.projectLabelKey)=sneaky"))
    }

    @Test func validationRules() {
        var config = RunConfiguration()
        config.user = "bad user!"
        #expect(!config.isValid)
        config.user = "www-data"
        config.workingDirectory = "relative/path"
        #expect(!config.isValid)
        config.workingDirectory = "/srv"
        #expect(config.isValid)
    }
}
