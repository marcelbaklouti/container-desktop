import Testing
import Foundation
@testable import Containers

struct IssueMapperTests {

    private func commandFailed(_ message: String, arguments: [String] = ["delete", "x"]) -> RuntimeError {
        .commandFailed(arguments: arguments, exitCode: 1, message: message)
    }

    @Test func runningContainerDeleteOffersStopAndDelete() {
        let stderr = "Error: internalError: \"failed to delete container\" (cause: \"invalidState: \"container web is running and can not be deleted\"\")"
        let issue = IssueMapper.issue(for: commandFailed(stderr), context: .deleteContainer(id: "web"))
        #expect(issue.title.contains("web"))
        #expect(issue.remedy == .stopAndDeleteContainer("web"))
        #expect(issue.remedyLabel == "Stop and Delete")
        #expect(issue.rawDetails?.contains("exit code 1") == true)
    }

    @Test func mountedVolumeDeleteRevealsContainers() {
        let stderr = "failed to delete volume: [\"error\": invalidArgument: \"volume 'pgdata' is currently in use and cannot be accessed by another container, or deleted\", \"id\": pgdata]\nError: delete failed for one or more volumes: [\"pgdata\"]"
        let issue = IssueMapper.issue(for: commandFailed(stderr), context: .deleteVolume(name: "pgdata", mountedBy: ["db"]))
        #expect(issue.title.contains("pgdata"))
        #expect(issue.reason.contains("db"))
        #expect(issue.remedy == .revealContainers(["db"]))
    }

    @Test func attachedNetworkParsesReferringContainersFromStderr() {
        let stderr = "failed to delete network: [\"id\": backend, \"error\": invalidState: \"cannot delete subnet backend with referring containers: api, worker\"]\nError: delete failed for one or more networks: [\"backend\"]"
        let issue = IssueMapper.issue(for: commandFailed(stderr), context: .deleteNetwork(name: "backend", attachedTo: []))
        #expect(issue.remedy == .revealContainers(["api", "worker"]))
        #expect(issue.reason.contains("api"))
    }

    @Test func attachedNetworkPrefersAppSideKnowledge() {
        let stderr = "cannot delete subnet backend with referring containers: api"
        let issue = IssueMapper.issue(for: commandFailed(stderr), context: .deleteNetwork(name: "backend", attachedTo: ["api", "web"]))
        #expect(issue.remedy == .revealContainers(["api", "web"]))
    }

    @Test func portConflictRevealsRunningContainers() {
        let message = "A published port is already in use — stop whatever is using it (for example, the same stack running in Docker) and try again."
        let issue = IssueMapper.issue(for: commandFailed(message, arguments: ["run", "-p", "5432:5432", "img"]), context: .runContainer)
        #expect(issue.title == "A Port Is Already in Use")
        #expect(issue.remedy == .revealContainers([]))
    }

    @Test func daemonNotRunningOffersStart() {
        let issue = IssueMapper.issue(for: RuntimeError.daemonNotRunning, context: .generic(actionTitle: "Couldn’t Refresh"))
        #expect(issue.remedy == .startDaemon)
        #expect(issue.remedyLabel == "Start Container System")
    }

    @Test func fallbackUsesActionTitleAndKeepsDetails() {
        let issue = IssueMapper.issue(for: commandFailed("some obscure failure", arguments: ["image", "prune"]), context: .generic(actionTitle: "Couldn’t Prune Images"))
        #expect(issue.title == "Couldn’t Prune Images")
        #expect(issue.reason == "some obscure failure")
        #expect(issue.remedy == .none)
        #expect(issue.rawDetails?.contains("container image prune") == true)
    }
}
