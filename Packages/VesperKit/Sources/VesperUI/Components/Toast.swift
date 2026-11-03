import SwiftUI

/// A Liquid Glass capsule above the bottom bar that does not interrupt the page. It leaves after
/// four seconds, or at once when its action is taken.
public struct ToastModifier: ViewModifier {
    @Binding var message: ToastMessage?

    public func body(content: Content) -> some View {
        content
            .environment(\.toasting, message != nil)
            .overlay(alignment: .bottom) {
                if let message {
                    HStack(spacing: 14) {
                        Text(message.text)
                            .font(Theme.Font.meta.weight(.medium))
                            .foregroundStyle(Theme.foreground)
                            .lineLimit(2)
                        if let action = message.action {
                            Button(action.title) {
                                self.message = nil
                                action.perform()
                            }
                            .font(Theme.Font.meta.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .padding(.horizontal, Theme.Space.xl)
                    .padding(.bottom, Theme.Space.sm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityElement(children: .combine)
                    .task(id: message.id) {
                        do {
                            try await Task.sleep(for: .seconds(4))
                        } catch {
                            return
                        }
                        withAnimation(Theme.Motion.quick) { self.message = nil }
                    }
                }
            }
            .animation(Theme.Motion.quick, value: message)
    }
}

extension EnvironmentValues {
    @Entry public var toasting = false
}

extension View {
    public func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
