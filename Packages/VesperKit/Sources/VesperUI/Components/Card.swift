import SwiftUI

public struct CardModifier: ViewModifier {
    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
        content
            .padding(Theme.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.background, in: shape)
            .overlay {
                shape.strokeBorder(Theme.border, lineWidth: 1)
            }
            .shadow(color: Theme.shadow.opacity(0.04), radius: 8, y: 2)
    }
}

extension View {
    public func card() -> some View {
        modifier(CardModifier())
    }
}

#Preview {
    VStack(spacing: 12) {
        Text("A card").card()
    }
    .padding()
    .background(Theme.background)
}
