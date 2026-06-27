import Foundation
import Observation

@Observable
@MainActor
final class ContainerStatsStore {
    private(set) var samples: [String: ContainerStatsSample] = [:]
    private(set) var cpuPercents: [String: Double] = [:]
    private(set) var history: [String: [StatsPoint]] = [:]

    private let client: any RuntimeClient
    private var streamTask: Task<Void, Never>?
    private var previous: [String: (usec: Int, time: Date)] = [:]

    init(client: any RuntimeClient = ContainerCLI()) {
        self.client = client
    }

    func cpu(for id: String) -> Double? { cpuPercents[id] }

    func memory(for id: String) -> Int? { samples[id]?.memoryUsageBytes }

    func points(for id: String) -> [StatsPoint] { history[id] ?? [] }

    func totalCPU(for ids: [String]) -> Double {
        ids.reduce(0) { $0 + (cpuPercents[$1] ?? 0) }
    }

    func totalMemory(for ids: [String]) -> Int {
        ids.reduce(0) { $0 + (samples[$1]?.memoryUsageBytes ?? 0) }
    }

    func start() {
        guard streamTask == nil else { return }
        streamTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.consume()
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
            }
        }
    }

    private func consume() async {
        do {
            let stream = try await client.lines(for: ["stats", "--format", "json"])
            for try await line in stream {
                ingest(line)
            }
        } catch {
            // The stream ends when the daemon stops or no container is running; the outer loop retries.
        }
    }

    private func ingest(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("["),
              let data = trimmed.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([ContainerStatsSample].self, from: data) else { return }

        let now = Date()
        let seen = Set(decoded.map(\.id))

        for sample in decoded {
            var cpuPercent = 0.0
            if let prior = previous[sample.id] {
                let deltaUsec = Double(sample.cpuUsageUsec - prior.usec)
                let deltaTime = now.timeIntervalSince(prior.time)
                if deltaTime > 0 {
                    cpuPercent = max(0, deltaUsec / (deltaTime * 1_000_000) * 100)
                }
            }
            previous[sample.id] = (sample.cpuUsageUsec, now)
            cpuPercents[sample.id] = cpuPercent
            samples[sample.id] = sample

            var points = history[sample.id] ?? []
            points.append(StatsPoint(time: now, memoryBytes: sample.memoryUsageBytes, cpuPercent: cpuPercent))
            if points.count > 120 { points.removeFirst(points.count - 120) }
            history[sample.id] = points
        }

        for id in samples.keys where !seen.contains(id) {
            samples[id] = nil
            cpuPercents[id] = nil
            previous[id] = nil
            history[id] = nil
        }
    }
}

struct StatsPoint: Identifiable {
    let id = UUID()
    let time: Date
    let memoryBytes: Int
    let cpuPercent: Double
}
