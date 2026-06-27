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
        }
        .frame(minWidth: 480, minHeight: 360)
    }
}
