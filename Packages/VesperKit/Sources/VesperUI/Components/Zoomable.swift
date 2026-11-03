import SwiftUI

/// `zoomed` lets a parent pager stop scrolling while the content is magnified.
public struct Zoomable<Content: View>: View {
    @Binding var zoomed: Bool
    let tap: () -> Void
    @ViewBuilder let content: Content

    @State private var scale: CGFloat = 1
    @State private var settledScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero

    public init(zoomed: Binding<Bool>, tap: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        _zoomed = zoomed
        self.tap = tap
        self.content = content()
    }

    public var body: some View {
        content
            .scaleEffect(scale)
            .offset(offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = min(max(settledScale * value.magnification, 1), 4)
                    }
                    .onEnded { _ in
                        settle(scale)
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: settledOffset.width + value.translation.width,
                            height: settledOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        settledOffset = offset
                    },
                // Unzoomed drags belong to the pager and the dismiss transition.
                including: zoomed ? .all : .subviews
            )
            .onTapGesture(count: 2) {
                settle(scale > 1 ? 1 : 2.5)
            }
            .onTapGesture(perform: tap)
    }

    private func settle(_ target: CGFloat) {
        withAnimation(Theme.Motion.gentle) {
            scale = target
            settledScale = target
            if target == 1 {
                offset = .zero
                settledOffset = .zero
            }
        }
        zoomed = target > 1
    }
}
