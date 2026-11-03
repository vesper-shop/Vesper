import Consumers
import SwiftUI
import VesperUI

struct MemoEditor: View {
    let memo: Memo?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var content: String
    @State private var visibility: Memo.Visibility
    @State private var saving = false
    @State private var error: String?
    @State private var discarding = false
    @State private var detent = PresentationDetent.large
    @State private var saved = false
    private let original: (content: String, visibility: Memo.Visibility)
    @FocusState private var focused: Bool

    init(memo: Memo?) {
        self.memo = memo
        let start: (content: String, visibility: Memo.Visibility) = if let memo {
            (memo.content, memo.visibility)
        } else {
            ("", .private)
        }
        _content = State(initialValue: start.content)
        _visibility = State(initialValue: start.visibility)
        original = start
    }

    private var edited: Bool {
        content != original.content || visibility != original.visibility
    }

    /// Completes the `#word` at the end of the memo, not at the caret.
    private var suggestions: [TagCount] {
        guard let last = content.split(whereSeparator: \.isWhitespace).last, last.hasPrefix("#"),
              !content.last!.isWhitespace
        else { return [] }
        let typed = last.dropFirst()
        return Array(model.memos.tags.filter { $0.name.hasPrefix(typed) && $0.name != typed }.prefix(8))
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $content)
                .focused($focused)
                .font(Theme.Font.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, Theme.Space.md)
                .background(Theme.background)
                .overlay(alignment: .topLeading) {
                    if content.isEmpty {
                        Text("What's on your mind? Use #tags to organize.")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.mutedForeground)
                            .padding(.horizontal, Theme.Space.md + 5) // TextEditor insets its text by 5 pt
                            .padding(.top, Theme.Space.xs)
                            .allowsHitTesting(false)
                    }
                }
                .navigationTitle(memo == nil ? "New Memo" : "Edit Memo")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) {
                            if edited { discarding = true } else { dismiss() }
                        }
                        .confirmationDialog("Discard your changes to this memo?", isPresented: $discarding, titleVisibility: .visible) {
                            Button("Discard Changes", role: .destructive) { dismiss() }
                            Button("Keep Editing", role: .cancel) {}
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm) { Task { await save() } }
                            .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
                    }
                }
                .alert("Couldn't Save", isPresented: .constant(error != nil), presenting: error) { _ in
                    Button("OK") { error = nil }
                } message: { error in
                    Text(error)
                }
                .safeAreaInset(edge: .bottom) {
                    GlassEffectContainer(spacing: Theme.Space.xs) {
                        ScrollView(.horizontal) {
                            HStack(spacing: Theme.Space.xs) {
                                Button {
                                    visibility = visibility == .public ? .private : .public
                                } label: {
                                    Label(
                                        visibility == .public ? "Public" : "Private",
                                        systemImage: visibility == .public ? "globe" : "lock"
                                    )
                                    .contentTransition(.symbolEffect(.replace))
                                    .font(Theme.Font.detail.weight(.medium))
                                    .foregroundStyle(visibility == .public ? Theme.accentForeground : Theme.foreground)
                                    .padding(.horizontal, Theme.Space.sm)
                                    .padding(.vertical, 7)
                                }
                                .buttonStyle(.plain)
                                .glassEffect(visibility == .public ? .regular.tint(Theme.accent).interactive() : .regular.interactive(), in: .capsule)
                                .sensoryFeedback(.selection, trigger: visibility)
                                .accessibilityHint("Switches between public and private")
                                ForEach(suggestions, id: \.name) { tag in
                                    Button {
                                        let typed = content.split(whereSeparator: \.isWhitespace).last!.count
                                        content = content.dropLast(typed) + "#\(tag.name) "
                                    } label: {
                                        Text("#\(tag.name)")
                                            .font(Theme.Font.detail.weight(.medium))
                                            .foregroundStyle(Theme.foreground)
                                            .padding(.horizontal, Theme.Space.sm)
                                            .padding(.vertical, 7)
                                    }
                                    .buttonStyle(.plain)
                                    .glassEffect(.regular.interactive(), in: .capsule)
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, Theme.Space.md)
                            .padding(.vertical, Theme.Space.xs)
                        }
                        .rail()
                    }
                }
                .animation(Theme.Motion.quick, value: suggestions.map(\.name))
                .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .interactiveDismissDisabled(saving || edited)
        .sensoryFeedback(.success, trigger: saved)
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            if let memo {
                try await model.memos.edit(memo, content: content, visibility: visibility)
            } else {
                try await model.memos.create(content: content, visibility: visibility)
            }
            saved = true
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    MemoEditor(memo: nil)
        .environment(AppModel())
}
