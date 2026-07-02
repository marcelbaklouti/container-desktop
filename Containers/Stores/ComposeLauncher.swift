import Foundation
import Observation

@Observable
@MainActor
final class ComposeLauncher {
    enum Phase: Equatable {
        case waiting
        case building(String?)
        case pulling
        case starting
        case running
        case failed(String)
    }

    enum Preparation: Equatable {
        case none
        case checkingBuilder
        case startingBuilder(String?)
        case ready
        case failed(String)
    }

    struct ServiceProgress: Identifiable {
        let id: String
        let name: String
        var phase: Phase
    }

    private(set) var progress: [ServiceProgress] = []
    private(set) var preparation: Preparation = .none
    private(set) var isLaunching = false
    private(set) var finished = false

    private let client: any RuntimeClient

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    var runningCount: Int {
        progress.filter { $0.phase == .running }.count
    }

    var failedCount: Int {
        progress.reduce(0) { count, item in
            if case .failed = item.phase { return count + 1 }
            return count
        }
    }

    func launch(_ project: ComposeProject) async {
        guard !isLaunching else { return }
        isLaunching = true
        finished = false
        preparation = .none

        let order = project.runOrder()
        progress = order.map { ServiceProgress(id: $0.name, name: $0.displayName, phase: .waiting) }

        do {
            for volume in project.namedVolumes {
                try await createToleratingExisting(["volume", "create", volume])
            }
            try await createToleratingExisting(["network", "create", project.networkName])
        } catch {
            let message = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            for index in progress.indices { progress[index].phase = .failed(message) }
            isLaunching = false
            finished = true
            return
        }

        let localReferences = await localImageReferences()
        let buildPlan = Dictionary(uniqueKeysWithValues: order.map { service in
            (service.name, service.build != nil && !hasLocalImage(service, project: project, references: localReferences))
        })

        if buildPlan.values.contains(true) {
            await prepareBuilder()
        }

        var failedServices: Set<String> = []

        for index in order.indices {
            let service = order[index]

            if let failedDependency = service.dependsOn.first(where: { failedServices.contains($0) }) {
                progress[index].phase = .failed(String(localized: "Didn’t start — \(failedDependency) failed."))
                failedServices.insert(service.name)
                continue
            }
            guard service.image != nil || service.build != nil else {
                progress[index].phase = .failed(String(localized: "The service has neither an image nor a build configuration."))
                failedServices.insert(service.name)
                continue
            }

            // Re-create cleanly so re-launching a stack is idempotent.
            let identifier = service.containerIdentifier(in: project)
            _ = try? await client.data(for: ["stop", identifier])
            _ = try? await client.data(for: ["delete", identifier])

            if buildPlan[service.name] == true {
                if case let .failed(reason) = preparation {
                    progress[index].phase = .failed(reason)
                    failedServices.insert(service.name)
                    continue
                }
                progress[index].phase = .building(nil)
                do {
                    try await runBuild(for: service, in: project, at: index)
                } catch {
                    progress[index].phase = .failed((error as? RuntimeError)?.localizedMessage ?? error.localizedDescription)
                    failedServices.insert(service.name)
                    continue
                }
            } else if service.build == nil, let image = service.image {
                // Pull explicitly so the row can show a distinct "Pulling…" phase; the run is the
                // arbiter, so a pull failure (e.g. the image is already local) is non-fatal here.
                progress[index].phase = .pulling
                _ = try? await client.data(for: ["image", "pull", image])
            }

            progress[index].phase = .starting
            do {
                _ = try await client.data(for: service.runArguments(in: project))
                progress[index].phase = .running
            } catch {
                progress[index].phase = .failed((error as? RuntimeError)?.localizedMessage ?? error.localizedDescription)
                failedServices.insert(service.name)
            }
        }

        isLaunching = false
        finished = true
    }

    /// Builds run only after the builder container is up. Its first start pulls the builder image,
    /// so the stream keeps the preparation row honest instead of looking hung.
    private func prepareBuilder() async {
        preparation = .checkingBuilder
        if await builderIsRunning() {
            preparation = .ready
            return
        }
        preparation = .startingBuilder(nil)
        do {
            var lastUpdate = ContinuousClock.now
            for try await line in try await client.lines(for: ["builder", "start"]) {
                let now = ContinuousClock.now
                if now - lastUpdate > .milliseconds(300) {
                    preparation = .startingBuilder(line)
                    lastUpdate = now
                }
            }
            preparation = .ready
        } catch {
            preparation = .failed((error as? RuntimeError)?.localizedMessage ?? error.localizedDescription)
        }
    }

    private func builderIsRunning() async -> Bool {
        guard let data = try? await client.data(for: ["builder", "status", "--format", "json"]) else { return false }
        let entries = (try? JSONSerialization.jsonObject(with: data)) as? [Any]
        return entries?.isEmpty == false
    }

    private func runBuild(for service: ComposeService, in project: ComposeProject, at index: Int) async throws {
        guard let arguments = service.buildArguments(in: project) else { return }
        var lastUpdate = ContinuousClock.now
        for try await line in try await client.lines(for: arguments) {
            let now = ContinuousClock.now
            if now - lastUpdate > .milliseconds(300) {
                progress[index].phase = .building(line)
                lastUpdate = now
            }
        }
    }

    private func localImageReferences() async -> Set<String> {
        guard let images = try? await client.decode([ContainerImage].self, from: ["image", "ls", "--format", "json"]) else { return [] }
        return Set(images.map { $0.configuration.name })
    }

    private nonisolated func hasLocalImage(_ service: ComposeService, project: ComposeProject, references: Set<String>) -> Bool {
        guard let tag = service.imageTag(in: project) else { return false }
        let withDefaultTag = tag.contains(":") ? tag : "\(tag):latest"
        return references.contains { reference in
            reference == tag || reference == withDefaultTag || reference.hasSuffix("/\(withDefaultTag)")
        }
    }

    /// Creates a project resource, tolerating the "already exists" error so re-launching
    /// a stack is idempotent, but surfacing any other failure (e.g. daemon down).
    private func createToleratingExisting(_ arguments: [String]) async throws {
        do {
            _ = try await client.data(for: arguments)
        } catch let RuntimeError.commandFailed(_, _, message)
            where message.localizedCaseInsensitiveContains("already exists") {
        }
    }
}
