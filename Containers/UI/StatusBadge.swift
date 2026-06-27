import SwiftUI

struct StatusBadge: View {
    let text: LocalizedStringKey
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
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
