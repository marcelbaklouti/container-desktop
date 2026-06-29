import SwiftUI
import AppKit

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
                    await appModel.updater.checkForUpdates()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            // Free ⌘N (default "New Window") for each area's primary "new" action.
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About Container Desktop") { showAboutPanel() }
            }
            CommandGroup(after: .appInfo) {
                SettingsLink {
                    Text("Check for Updates…")
                }
            }
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
                .environment(appModel.updater)
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

/// Standard macOS About panel, with the copyright (from Info.plist) plus the
/// legally-required "not affiliated with Apple" notice in the credits.
@MainActor
private func showAboutPanel() {
    let notice = "Not affiliated with, endorsed by, or sponsored by Apple Inc. "
        + "Apple, macOS, and Apple Silicon are trademarks of Apple Inc."
    NSApplication.shared.orderFrontStandardAboutPanel(options: [
        .credits: NSAttributedString(
            string: notice,
            attributes: [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
    ])
    NSApplication.shared.activate(ignoringOtherApps: true)
}
