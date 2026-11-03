import SwiftUI

/// The desktop Badge's `accent-outline` variant.
public struct Badge: View {
    let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(Theme.Font.caption.weight(.medium))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, Theme.Space.xs)
            .padding(.vertical, 3)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.4), lineWidth: 1)
            }
    }
}

#Preview {
    Badge("#日常").padding()
}
