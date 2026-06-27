import SwiftUI
import Charts

struct ContainerStatsView: View {
    let containerID: String
    @Environment(ContainerStatsStore.self) private var stats

    private var points: [StatsPoint] { stats.points(for: containerID) }
    private var latest: ContainerStatsSample? { stats.samples[containerID] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                chart("CPU", unit: "%") { $0.cpuPercent }
                chart("Memory", unit: "MB") { Double($0.memoryBytes) / 1_000_000 }
                if let latest {
                    summary(latest)
                }
            }
            .padding()
        }
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
                    ContentUnavailableView {
                        Label("No Live Stats", systemImage: "chart.xyaxis.line")
                    } description: {
                        Text("Stats appear while the container is running.")
                    }
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
}
