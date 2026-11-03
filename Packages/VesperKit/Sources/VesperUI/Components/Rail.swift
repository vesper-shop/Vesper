import SwiftUI

/// A horizontal chip strip without a scroller. A Mac mouse wheel cannot reach a hidden
/// horizontal scroller, so chevrons at each overflowing edge page it instead.
/// Apply it to the scroll view itself.
public struct Rail: ViewModifier {
    @State private var position = ScrollPosition()
    @State private var span = ScrollSpan()

    public func body(content: Content) -> some View {
        #if os(macOS)
        content
            .scrollIndicators(.never)
            .scrollPosition($position)
            .onScrollGeometryChange(for: ScrollSpan.self) {
                ScrollSpan(offset: $0.contentOffset.x, visible: $0.containerSize.width, total: $0.contentSize.width)
            } action: {
                span = $1
            }
            .overlay(alignment: .leading) {
                if span.offset > 1 { page(-1) }
            }
            .overlay(alignment: .trailing) {
                if span.offset + span.visible < span.total - 1 { page(1) }
            }
            .animation(Theme.Motion.quick, value: span)
        #else
        content.scrollIndicators(.hidden)
        #endif
    }

    #if os(macOS)
    private func page(_ direction: CGFloat) -> some View {
        Button {
            let x = min(max(span.offset + direction * span.visible * 0.8, 0), span.total - span.visible)
            withAnimation(Theme.Motion.gentle) { position.scrollTo(x: x) }
        } label: {
            Image(systemName: direction < 0 ? "chevron.left" : "chevron.right")
                .font(Theme.Font.detail.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .frame(width: 28, height: 28)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .help(direction < 0 ? "Scroll back" : "Scroll forward")
        .padding(.horizontal, 6)
        .transition(.opacity)
    }
    #endif
}

extension View {
    public func rail() -> some View {
        modifier(Rail())
    }
}
