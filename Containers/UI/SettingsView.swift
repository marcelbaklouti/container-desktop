import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = Appearance.system
    @AppStorage("defaultCPUs") private var defaultCPUs = ""
    @AppStorage("defaultMemory") private var defaultMemory = ""
    @AppStorage("notifyExits") private var notifyExits = true
    @AppStorage("notifyDaemon") private var notifyDaemon = true
    @Environment(AppUpdater.self) private var updater

    var body: some View {
        TabView {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { appearance in
                            Text(appearance.label).tag(appearance)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Section("Default container resources") {
                    TextField("CPUs", text: $defaultCPUs, prompt: Text("e.g. 2"))
                    TextField("Memory", text: $defaultMemory, prompt: Text("e.g. 1G"))
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Defaults", systemImage: "slider.horizontal.3") }

            Form {
                Section("Notifications") {
                    Toggle("Container exits unexpectedly", isOn: $notifyExits)
                    Toggle("Daemon stops", isOn: $notifyDaemon)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Notifications", systemImage: "bell") }

            Form {
                Section("Updates") {
                    LabeledContent("Current Version", value: updater.currentVersion)
                    if let latest = updater.latestVersion {
                        LabeledContent("Latest Version", value: latest)
                    }
                    updateRow
                }
            }
            .formStyle(.grouped)
            .task { await updater.checkForUpdates() }
            .tabItem { Label("Updates", systemImage: "arrow.down.circle") }
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    @ViewBuilder
    private var updateRow: some View {
        switch updater.phase {
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            }
        case .downloading(let fraction):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: fraction)
                Text("Downloading… \(String(Int(fraction * 100)))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.red)
        case .idle:
            if updater.isUpdateAvailable {
                Button {
                    Task { await updater.downloadUpdate() }
                } label: {
                    Label("Download Update", systemImage: "arrow.down.circle")
                }
            } else if updater.latestVersion != nil {
                Label("Container Desktop is up to date.", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                Button("Check for Updates") { Task { await updater.checkForUpdates() } }
            }
        }
    }
}
