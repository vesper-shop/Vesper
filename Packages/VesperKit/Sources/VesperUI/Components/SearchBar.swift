import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// A Liquid Glass search field whose presence the caller owns: it focuses when shown and
/// `close` is the only way it goes away. `text` only receives committed input, never an IME
/// composition in progress.
public struct SearchBar: View {
    @Binding var text: String
    let prompt: String
    let close: () -> Void
    @State private var draft = ""
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
                    TextField(prompt, text: $draft)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .onSubmit { text = draft }
                        .onReceive(NotificationCenter.default.publisher(for: SearchBar.edited)) { note in
                            guard focused else { return }
                            #if os(iOS)
                            guard let field = note.object as? UITextField, field.markedTextRange == nil else { return }
                            text = field.text ?? ""
                            #else
                            guard let editor = (note.object as? NSTextField)?.currentEditor() as? NSTextView, !editor.hasMarkedText() else { return }
                            text = editor.string
                            #endif
                        }
                    if !draft.isEmpty {
                        Button {
                            draft = ""
                            text = ""
                        } label: {
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
        .onAppear {
            draft = text
            focused = true
        }
    }

    #if os(iOS)
    private static let edited = UITextField.textDidChangeNotification
    #else
    private static let edited = NSControl.textDidChangeNotification
    #endif
}
