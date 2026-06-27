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
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .help) {
                HelpMenuButton()
            }
        }

        Window("Container Desktop Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentMinSize)

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

private struct HelpMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Container Desktop Help") {
            openWindow(id: "help")
        }
        .keyboardShortcut("?", modifiers: .command)
    }
}
