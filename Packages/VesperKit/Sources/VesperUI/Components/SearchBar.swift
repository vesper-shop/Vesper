import SwiftUI

/// A Liquid Glass search field whose presence the caller owns: it focuses when shown and
/// `close` is the only way it goes away.
public struct SearchBar: View {
    @Binding var text: String
    let prompt: String
    let close: () -> Void
    @FocusState private var focused: Bool

    public init(text: Binding<String>, prompt: String, close: @escaping () -> Void) {
        _text = text
        self.prompt = prompt
        self.close = close
    }

    public var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.mutedForeground)
                    TextField(prompt, text: $text)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                    if !text.isEmpty {
                        Button { text = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.mutedForeground)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: .capsule)

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(Theme.Font.body.weight(.semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Close Search")
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .onAppear { focused = true }
    }
}
