import SwiftUI
import ServiceManagement

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
    @AppStorage("notifyUpdates") private var notifyUpdates = true
    @AppStorage("autoDownloadUpdates") private var autoDownloadUpdates = true
    @AppStorage("pollInterval") private var pollIntervalRaw = PollInterval.standard.rawValue
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?
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
                Section("Refresh") {
                    Picker("Refresh rate", selection: $pollIntervalRaw) {
                        Text("Fast").tag(PollInterval.fast.rawValue)
                        Text("Default").tag(PollInterval.standard.rawValue)
                        Text("Relaxed").tag(PollInterval.relaxed.rawValue)
                    }
                    Text("How often Container Desktop refreshes from the container system. Faster refresh shows changes sooner and uses slightly more energy.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Section("Login") {
                    Toggle("Open at Login", isOn: $openAtLogin)
                        .onChange(of: openAtLogin) { _, enabled in
                            updateLoginItem(enabled: enabled)
                        }
                    if let loginItemError {
                        Label(loginItemError, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Text("Opens Container Desktop automatically when you log in, so the menu bar controls are always available.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
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
                    Toggle("App update is available", isOn: $notifyUpdates)
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
                    Toggle("Download updates automatically", isOn: $autoDownloadUpdates)
                    updateRow
                }
            }
            .formStyle(.grouped)
            .task { await updater.checkForUpdates() }
            .tabItem { Label("Updates", systemImage: "arrow.down.circle") }
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            openAtLogin = SMAppService.mainApp.status == .enabled
            loginItemError = error.localizedDescription
        }
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
        case .verifying:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Verifying…").foregroundStyle(.secondary)
            }
        case .readyToInstall(let version):
            LabeledContent {
                Button("Restart to Update") {
                    Task { await updater.installStagedUpdate() }
                }
            } label: {
                Label("Version \(version) is ready to install.", systemImage: "checkmark.seal")
            }
        case .installing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Installing update…").foregroundStyle(.secondary)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.callout)
                .foregroundStyle(.red)
        case .idle:
            if updater.isUpdateAvailable {
                Button {
                    Task { await updater.stageUpdate() }
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
