import SwiftUI

/// Caps tall content at `maxHeight` with a fade and a Show more toggle, the touch equivalent of the
/// desktop's scrollable `max-height` memo body.
public struct Collapsible<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder let content: Content
    @State private var expanded = false
    @State private var overflows = false

    public init(maxHeight: CGFloat = 260, @ViewBuilder content: () -> Content) {
        self.maxHeight = maxHeight
        self.content = content()
    }

    public var body: some View {
        let collapsed = overflows && !expanded
        let limit = maxHeight
        VStack(alignment: .leading, spacing: 8) {
            content
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: Bool.self) { $0.size.height > limit } action: { overflows = $0 }
                .frame(maxHeight: collapsed ? maxHeight : nil, alignment: .top)
                .clipped()
                .mask {
                    LinearGradient(
                        stops: [.init(color: .black, location: collapsed ? 0.75 : 1), .init(color: .black.opacity(collapsed ? 0 : 1), location: 1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            if overflows {
                Button(expanded ? "Show less" : "Show more") {
                    withAnimation(Theme.Motion.gentle) { expanded.toggle() }
                }
                .font(Theme.Font.meta.weight(.medium))
                .foregroundStyle(Theme.accent)
                .buttonStyle(.plain)
            }
        }
    }
}
