import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(SystemController.self) private var system
    @Environment(ContainerStatsStore.self) private var stats
    @AppStorage("appearance") private var appearance = Appearance.system

    var body: some View {
        @Bindable var navigator = appModel.navigator
        NavigationSplitView {
            List(selection: $navigator.area) {
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
        .frame(minWidth: 960, minHeight: 600)
        .preferredColorScheme(appearance.colorScheme)
        .onAppear { stats.start() }
        .onDisappear { stats.stop() }
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
            AreaDetailView(area: appModel.navigator.area ?? .containers)
        }
    }
}

#Preview {
    let model = AppModel()
    ContentView()
        .environment(model)
        .environment(model.system)
        .environment(model.stats)
}
