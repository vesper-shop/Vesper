import SwiftUI

/// Pads a page by the larger horizontal safe-area inset on both sides. A tab bar docked to one
/// side of a wide window (an unfolded iPhone Duo, a phone on its side) then leaves the page
/// centred on the screen instead of pushed away from the bar.
public struct SymmetricInsets: ViewModifier {
    @State private var inset: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .safeAreaPadding(.horizontal, inset)
            .ignoresSafeArea(.container, edges: .horizontal)
            .background {
                Color.clear.onGeometryChange(for: CGFloat.self) { max($0.safeAreaInsets.leading, $0.safeAreaInsets.trailing) } action: {
                    inset = $0
                }
            }
    }
}

extension View {
    public func symmetricInsets() -> some View {
        modifier(SymmetricInsets())
    }
}
