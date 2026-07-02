import Foundation

/// A stack is the app's highest-level resource: every container sharing a Compose project label,
/// treated as one unit. Stacks are a pure derivation of the shared container list — no store,
/// no extra polling.
nonisolated struct Stack: Identifiable, Hashable {
    nonisolated enum AggregateState: Hashable {
        case running
        case partial
        case stopped
    }

    let name: String
    let containers: [Container]

    var id: String { name }

    init(name: String, containers: [Container]) {
        self.name = name
        self.containers = containers.sorted { ($0.serviceName ?? $0.id) < ($1.serviceName ?? $1.id) }
    }

    var configFile: URL? {
        containers.compactMap(\.stackConfigFile).first
    }

    var runningCount: Int {
        containers.count { $0.status?.state == "running" }
    }

    var totalCount: Int {
        containers.count
    }

    var aggregateState: AggregateState {
        switch runningCount {
        case 0: .stopped
        case totalCount: .running
        default: .partial
        }
    }

    var runningIDs: [String] {
        containers.filter { $0.status?.state == "running" }.map(\.id)
    }

    var stoppedIDs: [String] {
        containers.filter { $0.status?.state != "running" }.map(\.id)
    }

    var memberIDs: [String] {
        containers.map(\.id)
    }

    static func stacks(from containers: [Container]) -> [Stack] {
        let grouped = Dictionary(grouping: containers.filter { $0.project != nil }) { $0.project ?? "" }
        return grouped.keys.sorted().map { Stack(name: $0, containers: grouped[$0] ?? []) }
    }
}

nonisolated extension Container {
    var serviceName: String? {
        configuration.labels["com.docker.compose.service"]
    }

    var stackConfigFile: URL? {
        guard let raw = configuration.labels["com.docker.compose.project.config_files"],
              let first = raw.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespaces),
              first.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: first)
    }
}
