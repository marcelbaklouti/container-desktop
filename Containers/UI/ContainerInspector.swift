import SwiftUI

struct ContainerInspector: View {
    let container: Container
    @State private var tab: InspectorTab = .details

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $tab) {
                ForEach(InspectorTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)

            Divider()

            switch tab {
            case .details:
                ContainerDetailView(container: container)
            case .logs:
                ContainerLogsView(containerID: container.id)
            case .stats:
                ContainerStatsView(containerID: container.id)
            case .terminal:
                if container.status?.state == "running" {
                    ContainerTerminalView(containerID: container.id)
                        .frame(minHeight: 320)
                } else {
                    ContentUnavailableView("Container Not Running", systemImage: "terminal", description: Text("Start the container to open a shell."))
                }
            }
        }
    }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case details
    case logs
    case stats
    case terminal

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .details: "Details"
        case .logs: "Logs"
        case .stats: "Stats"
        case .terminal: "Terminal"
        }
    }
}
