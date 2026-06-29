import SwiftUI

struct KeyboardHint: Identifiable {
    let id = UUID()
    let label: String
    let keys: String
}

/// A spacious empty-state that does more than say "nothing here": it explains, in plain language,
/// what the resource is, offers the primary action, and surfaces the relevant keyboard shortcuts.
struct EmptyStateGuide: View {
    let icon: String
    let title: String
    let message: String
    var primaryLabel: String? = nil
    var primaryIcon: String = "plus"
    var primaryAction: (() -> Void)? = nil
    var secondaryLabel: String? = nil
    var secondaryIcon: String = "square.stack.3d.up"
    var secondaryAction: (() -> Void)? = nil
    var shortcuts: [KeyboardHint] = []

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 46))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text(title).font(.title2.weight(.semibold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if primaryLabel != nil || secondaryLabel != nil {
                HStack(spacing: 10) {
                    if let primaryLabel, let primaryAction {
                        Button(action: primaryAction) {
                            Label(primaryLabel, systemImage: primaryIcon)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if let secondaryLabel, let secondaryAction {
                        Button(action: secondaryAction) {
                            Label(secondaryLabel, systemImage: secondaryIcon)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .controlSize(.large)
            }

            if !shortcuts.isEmpty {
                VStack(spacing: 7) {
                    ForEach(shortcuts) { hint in
                        HStack(spacing: 16) {
                            Text(hint.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 12)
                            Text(hint.keys)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
                .frame(maxWidth: 260)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
