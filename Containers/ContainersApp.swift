import SwiftUI

@main
struct ContainersApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(appModel)
                .environment(appModel.system)
                .environment(appModel.containers)
                .environment(appModel.stats)
                .environment(appModel.installer)
                .task {
                    Notifier.requestAuthorization()
                    await appModel.system.refresh()
                    appModel.startPolling()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarContentView()
                .environment(appModel)
                .environment(appModel.system)
                .environment(appModel.containers)
                .environment(appModel.stats)
        } label: {
            if appModel.runningCount > 0 {
                Label(String(appModel.runningCount), systemImage: appModel.daemonRunning ? "shippingbox.fill" : "shippingbox")
                    .labelStyle(.titleAndIcon)
            } else {
                Image(systemName: appModel.daemonRunning ? "shippingbox.fill" : "shippingbox")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
