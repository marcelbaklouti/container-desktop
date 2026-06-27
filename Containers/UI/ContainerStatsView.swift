import SwiftUI
import Charts

struct ContainerStatsView: View {
    let containerID: String

    @State private var client = ContainerCLI()
    @State private var points: [StatsPoint] = []
    @State private var latest: ContainerStatsSample?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                chart("CPU", unit: "%") { $0.cpuPercent }
                chart("Memory", unit: "MB") { Double($0.memoryBytes) / 1_000_000 }
                if let latest {
                    summary(latest)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .task(id: containerID) { await poll() }
    }

    private func chart(_ title: LocalizedStringKey, unit: String, value: @escaping (StatsPoint) -> Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Chart(points) { point in
                AreaMark(x: .value("Time", point.time), y: .value(unit, value(point)))
                    .foregroundStyle(.tint.opacity(0.2))
                LineMark(x: .value("Time", point.time), y: .value(unit, value(point)))
                    .foregroundStyle(.tint)
                    .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .frame(height: 140)
            .overlay {
                if points.isEmpty {
                    ProgressView()
                }
            }
        }
    }

    @ViewBuilder
    private func summary(_ sample: ContainerStatsSample) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 8) {
            GridRow {
                tile("Memory", Int64(sample.memoryUsageBytes), style: .memory)
                tile("Limit", Int64(sample.memoryLimitBytes), style: .memory)
            }
            GridRow {
                tile("Net RX", Int64(sample.networkRxBytes), style: .file)
                tile("Net TX", Int64(sample.networkTxBytes), style: .file)
            }
            GridRow {
                LabeledContent("Processes", value: sample.numProcesses.formatted())
                tile("Block read", Int64(sample.blockReadBytes), style: .file)
            }
        }
    }

    private func tile(_ title: LocalizedStringKey, _ bytes: Int64, style: ByteCountFormatStyle.Style) -> some View {
        LabeledContent(title) {
            Text(bytes, format: .byteCount(style: style))
                .monospacedDigit()
        }
    }

    private func poll() async {
        points = []
        latest = nil
        errorMessage = nil
        var previous: (usec: Int, time: Date)?
        while !Task.isCancelled {
            do {
                let samples = try await client.decode(
                    [ContainerStatsSample].self,
                    from: ["stats", containerID, "--format", "json", "--no-stream"]
                )
                if let sample = samples.first(where: { $0.id == containerID }) ?? samples.first {
                    let now = Date()
                    var cpuPercent = 0.0
                    if let previous {
                        let deltaUsec = Double(sample.cpuUsageUsec - previous.usec)
                        let deltaTime = now.timeIntervalSince(previous.time)
                        if deltaTime > 0 {
                            cpuPercent = max(0, deltaUsec / (deltaTime * 1_000_000) * 100)
                        }
                    }
                    previous = (sample.cpuUsageUsec, now)
                    latest = sample
                    points.append(StatsPoint(time: now, memoryBytes: sample.memoryUsageBytes, cpuPercent: cpuPercent))
                    if points.count > 120 {
                        points.removeFirst(points.count - 120)
                    }
                }
                errorMessage = nil
            } catch {
                errorMessage = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            }
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
        }
    }
}

struct StatsPoint: Identifiable {
    let id = UUID()
    let time: Date
    let memoryBytes: Int
    let cpuPercent: Double
}
