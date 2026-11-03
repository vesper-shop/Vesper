import SwiftUI

/// Lifts content to full size and opacity in the middle of a scroll view and lets it recede a
/// little at the edges, giving long feeds depth. Off under Reduce Motion.
public struct ScrollDepth: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var still

    public func body(content: Content) -> some View {
        let still = still
        return content.scrollTransition(.interactive, axis: .vertical) { view, phase in
            view
                .scaleEffect(still || phase.isIdentity ? 1 : 0.96)
                .opacity(still || phase.isIdentity ? 1 : 0.7)
        }
    }
}

extension View {
    public func scrollDepth() -> some View {
        modifier(ScrollDepth())
    }
}
