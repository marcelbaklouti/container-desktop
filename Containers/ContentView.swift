import SwiftUI

struct ContentView: View {
    @Environment(SystemController.self) private var system
    @State private var selectedArea: Area? = .containers
    @AppStorage("appearance") private var appearance = Appearance.system

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedArea) {
                Section("Resources") {
                    ForEach(Area.resources) { area in
                        Label(area.titleKey, systemImage: area.systemImage).tag(area)
                    }
                }
                Section("Tools") {
                    ForEach(Area.tools) { area in
                        Label(area.titleKey, systemImage: area.systemImage).tag(area)
                    }
                }
                Section("System") {
                    Label(Area.system.titleKey, systemImage: Area.system.systemImage).tag(Area.system)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .navigationTitle("Container Desktop")
        } detail: {
            detail
        }
        .preferredColorScheme(appearance.colorScheme)
    }

    @ViewBuilder
    private var detail: some View {
        switch system.state {
        case .unknown:
            ProgressView()
                .controlSize(.large)
        case .binaryMissing, .daemonStopped:
            RuntimeUnavailableView()
        case .running:
            AreaDetailView(area: selectedArea ?? .containers)
        }
    }
}

#Preview {
    ContentView()
        .environment(SystemController())
}
