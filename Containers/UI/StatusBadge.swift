import SwiftUI

struct StatusBadge: View {
    let text: LocalizedStringKey
    let tint: Color
    @ScaledMetric(relativeTo: .caption) private var horizontalPadding = 10
    @ScaledMetric(relativeTo: .caption) private var verticalPadding = 4

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .contentTransition(.opacity)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .glassEffect(.regular.tint(tint.opacity(0.55)), in: .capsule)
    }
}

#Preview {
    HStack {
        StatusBadge(text: "Running", tint: .green)
        StatusBadge(text: "Stopped", tint: .orange)
    }
    .padding()
}
