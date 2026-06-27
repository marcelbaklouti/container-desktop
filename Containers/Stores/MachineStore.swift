import Foundation
import Observation

@Observable
@MainActor
final class MachineStore {
    private(set) var machines: [Machine] = []
    private(set) var hasLoaded = false
    var errorMessage: String?

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func refresh() async {
        do {
            let updated = try await client.decode([Machine].self, from: ["machine", "ls", "--format", "json"])
            if updated != machines {
                machines = updated
            }
            errorMessage = nil
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
        hasLoaded = true
    }

    func poll(every interval: Duration) async {
        while !Task.isCancelled {
            await refresh()
            do { try await Task.sleep(for: interval) } catch { return }
        }
    }

    func create(image: String, name: String, cpus: String, memory: String, homeMount: String, setDefault: Bool) async throws {
        var arguments = ["machine", "create"]
        if !name.isEmpty { arguments += ["--name", name] }
        if setDefault { arguments.append("--set-default") }
        if !cpus.isEmpty { arguments += ["--cpus", cpus] }
        if !memory.isEmpty { arguments += ["--memory", memory] }
        if !homeMount.isEmpty { arguments += ["--home-mount", homeMount] }
        arguments.append(image)
        _ = try await client.data(for: arguments)
        await refresh()
    }

    func reconfigure(_ machine: Machine, cpus: String, memory: String, homeMount: String) async throws {
        var arguments = ["machine", "set", "--name", machine.id]
        if !cpus.isEmpty { arguments.append("cpus=\(cpus)") }
        if !memory.isEmpty { arguments.append("memory=\(memory)") }
        if !homeMount.isEmpty { arguments.append("home-mount=\(homeMount)") }
        _ = try await client.data(for: arguments)
        await refresh()
    }

    func setDefault(_ machine: Machine) async { await perform(["machine", "set-default", machine.id]) }
    func stop(_ machine: Machine) async { await perform(["machine", "stop", machine.id]) }
    func delete(_ machine: Machine) async { await perform(["machine", "delete", machine.id]) }

    private func perform(_ arguments: [String]) async {
        do {
            _ = try await client.data(for: arguments)
            await refresh()
        } catch {
            errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
        }
    }
}
