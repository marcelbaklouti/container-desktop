import SwiftUI

nonisolated enum Area: String, CaseIterable, Identifiable, Hashable {
    case containers
    case images
    case networks
    case volumes
    case machines
    case builder
    case registries
    case system

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .containers: "Containers"
        case .images: "Images"
        case .networks: "Networks"
        case .volumes: "Volumes"
        case .machines: "Machines"
        case .builder: "Builder"
        case .registries: "Registries"
        case .system: "System"
        }
    }

    var systemImage: String {
        switch self {
        case .containers: "shippingbox"
        case .images: "square.stack.3d.up"
        case .networks: "network"
        case .volumes: "externaldrive"
        case .machines: "server.rack"
        case .builder: "hammer"
        case .registries: "person.badge.key"
        case .system: "gearshape"
        }
    }

    static let resources: [Area] = [.containers, .images, .networks, .volumes, .machines]
    static let tools: [Area] = [.builder, .registries]
}
