import SwiftUI

struct AreaDetailView: View {
    let area: Area

    var body: some View {
        switch area {
        case .system:
            SystemAreaView()
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
