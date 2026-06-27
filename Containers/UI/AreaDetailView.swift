import SwiftUI

struct AreaDetailView: View {
    let area: Area

    var body: some View {
        switch area {
        case .system:
            SystemAreaView()
        case .containers:
            ContainersListView()
        case .networks:
            NetworksListView()
        case .volumes:
            VolumesListView()
        case .images:
            ImagesListView()
        case .builder:
            BuilderView()
        case .machines:
            MachinesListView()
        case .registries:
            RegistriesListView()
        default:
            AreaPlaceholderView(area: area)
        }
    }
}

struct AreaPlaceholderView: View {
    let area: Area

    var body: some View {
        ContentUnavailableView {
            Label(area.titleKey, systemImage: area.systemImage)
        } description: {
            Text("This area is coming soon.")
        }
        .navigationTitle(area.titleKey)
    }
}

#Preview {
    AreaPlaceholderView(area: .images)
}
