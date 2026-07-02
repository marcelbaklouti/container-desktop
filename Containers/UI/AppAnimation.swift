import SwiftUI

extension View {
    /// The app's one list/state animation: a short smooth curve, disabled entirely when the
    /// user has Reduce Motion on.
    func appAnimation<V: Equatable>(_ value: V) -> some View {
        modifier(AppAnimationModifier(value: value))
    }
}

private struct AppAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .smooth(duration: 0.25), value: value)
    }
}
