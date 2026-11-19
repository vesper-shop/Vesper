import SwiftUI

public struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var still

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !still ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(configuration.isPressed ? Theme.Motion.quick : Theme.Motion.bouncy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressStyle {
    public static var press: PressStyle { PressStyle() }
}
