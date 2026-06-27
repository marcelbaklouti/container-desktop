import SwiftUI

@main
struct ContainersApp: App {
    @State private var system = SystemController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(system)
                .task { await system.refresh() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
