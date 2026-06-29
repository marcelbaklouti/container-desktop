import SwiftUI

struct RegistriesListView: View {
    @State private var store = RegistryStore()
    @State private var searchText = ""
    @State private var selection: Set<String> = []
    @State private var showLogin = false
    @State private var pendingLogout: [RegistryLogin] = []

    var body: some View {
        List(selection: $selection) {
            ForEach(store.logins.filter { searchText.isEmpty || $0.hostname.localizedCaseInsensitiveContains(searchText) }) { login in
                HStack(spacing: 12) {
                    Image(systemName: "person.badge.key.fill")
                        .foregroundStyle(.tint)
                        .font(.title3)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(login.hostname).font(.headline)
                        if let username = login.username {
                            Text(username).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(login.hostname)
                .accessibilityValue(login.username.map { "Signed in as \($0)" } ?? "Signed in")
                .tag(login.id)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { pendingLogout = [login] } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
        .contextMenu(forSelectionType: String.self) { ids in
            registryMenu(ids)
        }
        .onChange(of: store.logins) { _, items in
            let trimmed = selection.intersection(Set(items.map(\.id)))
            if trimmed != selection { selection = trimmed }
        }
        .overlay { emptyState }
        .navigationTitle("Registries")
        .searchable(text: $searchText, prompt: "Filter registries")
        .toolbar {
            ToolbarItem {
                Button { Task { await store.refresh() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .help("Refresh")
            }
            ToolbarItem {
                Button { showLogin = true } label: { Label("Log In", systemImage: "plus") }
                    .help("Log In to Registry…")
                    .keyboardShortcut("n", modifiers: .command)
                    .accessibilityLabel("Log In to a Registry")
            }
        }
        .task { await store.refresh() }
        .sheet(isPresented: $showLogin) { RegistryLoginSheet(store: store) }
        .confirmationDialog(pendingLogout.count == 1 ? "Log out of this registry?" : "Log out of \(pendingLogout.count) registries?", isPresented: logoutBinding) {
            Button("Log Out", role: .destructive) {
                let hostnames = pendingLogout.map(\.hostname)
                pendingLogout = []
                Task { await store.logout(hostnames) }
            }
        } message: {
            Text(pendingLogout.count == 1 ? (pendingLogout.first?.hostname ?? "") : "This logs out of \(pendingLogout.count) registries.")
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !store.hasLoaded {
            ProgressView().controlSize(.large)
        } else if store.logins.isEmpty {
            EmptyStateGuide(
                icon: "person.badge.key",
                title: "No Registry Logins",
                message: "A registry hosts container images, like Docker Hub. Sign in to pull from or push to private ones.",
                primaryLabel: "Log In",
                primaryAction: { showLogin = true },
                shortcuts: [
                    KeyboardHint(label: "Log in to a registry", keys: "⌘N"),
                    KeyboardHint(label: "Help", keys: "⌘?"),
                    KeyboardHint(label: "Settings", keys: "⌘,"),
                ]
            )
        }
    }

    @ViewBuilder
    private func registryMenu(_ ids: Set<String>) -> some View {
        let selected = store.logins.filter { ids.contains($0.id) }
        if !selected.isEmpty {
            Button(role: .destructive) { pendingLogout = selected } label: {
                Label(selected.count == 1 ? "Log Out" : "Log Out \(selected.count)", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    private var logoutBinding: Binding<Bool> {
        Binding(get: { !pendingLogout.isEmpty }, set: { if !$0 { pendingLogout = [] } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
    }
}

struct RegistryLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: RegistryStore

    @State private var server = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Registry") {
                    TextField("Server", text: $server, prompt: Text("docker.io"))
                        .textContentType(.URL)
                    TextField("Username", text: $username)
                        .textContentType(.username)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Log In to Registry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isWorking ? "Logging in…" : "Log In") { Task { await login() } }
                        .disabled(server.isEmpty || username.isEmpty || password.isEmpty || isWorking)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 300)
    }

    private func login() async {
        isWorking = true
        error = nil
        do {
            try await store.login(server: server, username: username, password: password)
            dismiss()
        } catch {
            self.error = (error as? RuntimeError)?.localizedMessage ?? error.localizedDescription
            isWorking = false
        }
    }
}
