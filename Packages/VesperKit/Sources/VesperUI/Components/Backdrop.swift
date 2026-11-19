import SwiftUI

public struct Backdrop: View {
    @Environment(\.accessibilityReduceMotion) private var still
    @State private var start = Date.now

    public init() {}

    public var body: some View {
        TimelineView(.animation(paused: still)) { context in
            let t = Float(context.date.timeIntervalSince(start))
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5 + 0.2 * sin(t * 0.21), 0], [1, 0],
                    [0, 0.5 + 0.15 * cos(t * 0.17)], [0.5 + 0.12 * cos(t * 0.23), 0.5 + 0.12 * sin(t * 0.19)], [1, 0.5 + 0.15 * sin(t * 0.13)],
                    [0, 1], [0.5 + 0.2 * cos(t * 0.11), 1], [1, 1],
                ],
                colors: [
                    Theme.background, Theme.lilac.opacity(0.45), Theme.background,
                    Theme.accent.opacity(0.16), Theme.background, Theme.lilac.opacity(0.35),
                    Theme.background, Theme.accent.opacity(0.2), Theme.lilac.opacity(0.25),
                ]
            )
        }
        .background(Theme.background)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    Backdrop()
}
