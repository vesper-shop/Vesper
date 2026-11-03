import SwiftUI

/// A glass "Top" capsule that rises once a scroll view is more than one and a half screens down
/// and scrolls it back to the top. Apply it to the scroll view itself.
public struct BackToTop: ViewModifier {
    @State private var position = ScrollPosition(edge: .top)
    @State private var away = false
    @Environment(\.accessibilityReduceMotion) private var still
    @Environment(\.toasting) private var toasting

    public func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > geometry.containerSize.height * 1.5
            } action: { _, far in
                withAnimation(still ? nil : Theme.Motion.bouncy) { away = far }
            }
            .overlay(alignment: .bottom) {
                // A toast takes the same spot; the button steps aside until it leaves.
                if away && !toasting {
                    Button {
                        withAnimation(still ? nil : Theme.Motion.gentle) {
                            position.scrollTo(edge: .top)
                        }
                    } label: {
                        Label("Top", systemImage: "arrow.up")
                            .font(Theme.Font.meta.weight(.semibold))
                            .foregroundStyle(Theme.foreground)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .help("Back to top")
                    .padding(.bottom, Theme.Space.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(still ? nil : Theme.Motion.quick, value: toasting)
    }
}

extension View {
    public func backToTop() -> some View {
        modifier(BackToTop())
    }
}
