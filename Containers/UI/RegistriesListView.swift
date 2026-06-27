import SwiftUI

struct RegistriesListView: View {
    @State private var store = RegistryStore()
    @State private var searchText = ""
    @State private var showLogin = false
    @State private var pendingLogout: RegistryLogin?

    var body: some View {
        List {
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
                .contextMenu {
                    Button(role: .destructive) { pendingLogout = login } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { pendingLogout = login } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
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
                    .accessibilityLabel("Log In to a Registry")
            }
        }
        .task { await store.refresh() }
        .sheet(isPresented: $showLogin) { RegistryLoginSheet(store: store) }
        .confirmationDialog("Log out of this registry?", isPresented: logoutBinding, presenting: pendingLogout) { login in
            Button("Log Out", role: .destructive) { Task { await store.logout(login) } }
        } message: { login in
            Text(login.hostname)
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
            ContentUnavailableView("No Registry Logins", systemImage: "person.badge.key", description: Text("Log in to a registry to push and pull private images."))
        }
    }

    private var logoutBinding: Binding<Bool> {
        Binding(get: { pendingLogout != nil }, set: { if !$0 { pendingLogout = nil } })
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
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
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
