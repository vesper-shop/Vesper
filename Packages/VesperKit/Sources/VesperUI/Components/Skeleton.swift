import SwiftUI

/// `width` nil fills the line.
public struct Bone: View {
    let width: CGFloat?
    let height: CGFloat

    public init(width: CGFloat? = nil, height: CGFloat = 10) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        Capsule()
            .fill(Theme.skeleton)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

public struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var still

    public func body(content: Content) -> some View {
        content
            .overlay {
                if !still {
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        Rectangle()
                            .fill(LinearGradient(colors: [Theme.shine.opacity(0), Theme.shine.opacity(0.9), Theme.shine.opacity(0)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: width * 0.5)
                            .phaseAnimator([false, true]) { band, swept in
                                band.offset(x: swept ? width * 1.25 : -width * 0.75)
                            } animation: { swept in
                                swept ? .easeInOut(duration: 1.4).delay(0.5) : nil
                            }
                    }
                    .mask { content }
                    .allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading")
    }
}

extension View {
    public func shimmer() -> some View {
        modifier(Shimmer())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        Bone(width: 90, height: 9)
        Bone()
        Bone()
        Bone(width: 180)
    }
    .card()
    .shimmer()
    .padding()
    .background(Theme.background)
}
