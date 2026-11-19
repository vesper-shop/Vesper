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
    @State private var size: CGSize = .zero

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
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = min(max(settledScale * value.magnification, 1), 4)
                    }
                    .onEnded { _ in
                        settle(scale, toward: offset)
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        offset = clamp(CGSize(
                            width: settledOffset.width + value.translation.width,
                            height: settledOffset.height + value.translation.height
                        ), scale: scale)
                    }
                    .onEnded { _ in
                        settledOffset = offset
                    },
                // Unzoomed drags belong to the pager and the dismiss transition.
                including: zoomed ? .all : .subviews
            )
            .onTapGesture(count: 2) { location in
                if scale > 1 {
                    settle(1, toward: .zero)
                } else {
                    settle(2.5, toward: CGSize(width: (size.width / 2 - location.x) * 1.5, height: (size.height / 2 - location.y) * 1.5))
                }
            }
            .onTapGesture(perform: tap)
    }

    private func settle(_ target: CGFloat, toward goal: CGSize) {
        withAnimation(Theme.Motion.bouncy) {
            scale = target
            settledScale = target
            offset = clamp(goal, scale: target)
            settledOffset = offset
        }
        zoomed = target > 1
    }

    private func clamp(_ offset: CGSize, scale: CGFloat) -> CGSize {
        let x = size.width * (scale - 1) / 2
        let y = size.height * (scale - 1) / 2
        return CGSize(width: min(max(offset.width, -x), x), height: min(max(offset.height, -y), y))
    }
}
