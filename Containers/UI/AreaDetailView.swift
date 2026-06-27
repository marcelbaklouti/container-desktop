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
        }
    }
}
