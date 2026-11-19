import Consumers
import PhotosUI
import SwiftUI
import VesperUI

/// Photos are set when an entry is written; editing changes only its text and visibility.
struct EntryEditor: View {
    let entry: Entry?
    let camera: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var content: String
    @State private var visibility: Entry.Visibility
    @State private var attachments: [Attachment] = []
    @State private var located = true
    @State private var picked: [PhotosPickerItem] = []
    @State private var picking = false
    @State private var shooting = false
    @State private var saving = false
    @State private var saved = false
    @State private var error: String?
    @State private var discarding = false
    @State private var detent = PresentationDetent.large
    private let original: (content: String, visibility: Entry.Visibility)
    @FocusState private var focused: Bool

    init(entry: Entry?, camera: Bool) {
        self.entry = entry
        self.camera = camera
        let start: (content: String, visibility: Entry.Visibility) = if let entry {
            (entry.content, entry.visibility)
        } else {
            ("", .private)
        }
        _content = State(initialValue: start.content)
        _visibility = State(initialValue: start.visibility)
        original = start
    }

    private var edited: Bool {
        content != original.content || visibility != original.visibility || !attachments.isEmpty
    }

    /// A new entry may be photos alone; Vesper refuses an edit that empties the text.
    private var empty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (entry == nil ? attachments.isEmpty : content != original.content)
    }

    /// Completes the `#word` at the end of the text, not at the caret.
    private var suggestions: [TagCount] {
        guard let last = content.split(whereSeparator: \.isWhitespace).last, last.hasPrefix("#"),
              !content.last!.isWhitespace
        else { return [] }
        let typed = last.dropFirst()
        return Array(model.timeline.tags.filter { $0.name.hasPrefix(typed) && $0.name != typed }.prefix(8))
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
                        Text("What happened today? Use #tags to organize.")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.mutedForeground)
                            .padding(.horizontal, Theme.Space.md + 5) // TextEditor insets its text by 5 pt
                            .padding(.top, Theme.Space.xs)
                            .allowsHitTesting(false)
                    }
                }
                .navigationTitle(entry == nil ? "New Entry" : "Edit Entry")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) {
                            if edited { discarding = true } else { dismiss() }
                        }
                        .confirmationDialog("Discard this entry?", isPresented: $discarding, titleVisibility: .visible) {
                            Button("Discard", role: .destructive) { dismiss() }
                            Button("Keep Editing", role: .cancel) {}
                        }
                        .disabled(saving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if saving {
                            ProgressView()
                        } else {
                            Button(role: .confirm) { Task { await save() } }
                                .disabled(empty)
                        }
                    }
                    #if os(iOS)
                    ToolbarSpacer(.flexible, placement: .keyboard)
                    ToolbarItem(placement: .keyboard) {
                        Button("Dismiss Keyboard", systemImage: "keyboard.chevron.compact.down") { focused = false }
                    }
                    #endif
                }
                .alert("Couldn't Save", isPresented: .constant(error != nil), presenting: error) { _ in
                    Button("OK") { error = nil }
                } message: { error in
                    Text(error)
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        if entry == nil {
                            ScrollView(.horizontal) {
                                HStack(spacing: Theme.Space.xs) {
                                    ForEach(attachments) { attachment in
                                        Image(decorative: attachment.preview, scale: 1)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(.rect(cornerRadius: Theme.Radius.md))
                                            .overlay(alignment: .topTrailing) {
                                                Button {
                                                    attachments.removeAll { $0.id == attachment.id }
                                                } label: {
                                                    Image(systemName: "xmark")
                                                        .font(.caption2.weight(.bold))
                                                        .foregroundStyle(Theme.onDark)
                                                        .frame(width: 22, height: 22)
                                                }
                                                .buttonStyle(.plain)
                                                .glassEffect(.clear.interactive(), in: .circle)
                                                .padding(3)
                                                .accessibilityLabel("Remove Photo")
                                            }
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                    if attachments.count < Entry.photoLimit {
                                        Menu {
                                            #if os(iOS)
                                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                                Button("Take Photo", systemImage: "camera") { shooting = true }
                                            }
                                            #endif
                                            Button("Choose from Library", systemImage: "photo.on.rectangle") { picking = true }
                                        } label: {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.title3)
                                                .foregroundStyle(Theme.mutedForeground)
                                                .frame(width: 72, height: 72)
                                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Theme.Radius.md))
                                        }
                                        .menuIndicator(.hidden)
                                        .accessibilityLabel("Add Photos")
                                    }
                                }
                                .padding(.horizontal, Theme.Space.md)
                                .padding(.top, Theme.Space.xs)
                            }
                            .rail()
    
                        }
                        GlassEffectContainer(spacing: Theme.Space.xs) {
                            ScrollView(.horizontal) {
                                HStack(spacing: Theme.Space.xs) {
                                    chip(
                                        visibility == .public ? "Public" : "Private",
                                        symbol: visibility == .public ? "globe" : "lock",
                                        on: visibility == .public
                                    ) {
                                        visibility = visibility == .public ? .private : .public
                                    }
                                    .accessibilityHint("Switches between public and private")
                                    if attachments.contains(where: { $0.geo != nil }) {
                                        chip("Location", symbol: located ? "location.fill" : "location.slash", on: located) {
                                            located.toggle()
                                        }
                                        .accessibilityHint("Keeps or drops where the photos were taken")
                                    }
                                    ForEach(suggestions, id: \.name) { tag in
                                        chip("#\(tag.name)", symbol: nil, on: false) {
                                            let typed = content.split(whereSeparator: \.isWhitespace).last!.count
                                            content = content.dropLast(typed) + "#\(tag.name) "
                                        }
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .padding(.horizontal, Theme.Space.md)
                                .padding(.vertical, Theme.Space.xs)
                            }
                            .rail()
                        }
                    }
                }
                .animation(Theme.Motion.quick, value: suggestions.map(\.name))
                .animation(Theme.Motion.gentle, value: attachments.map(\.id))
                .photosPicker(isPresented: $picking, selection: $picked, maxSelectionCount: Entry.photoLimit - attachments.count, matching: .images)
                .onChange(of: picked) {
                    let items = picked
                    guard !items.isEmpty else { return }
                    picked = []
                    Task {
                        do {
                            for item in items {
                                guard let source = try await item.loadTransferable(type: Data.self) else {
                                    throw CocoaError(.fileReadUnknown)
                                }
                                attachments.append(try Attachment(source))
                            }
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
                #if os(iOS)
                .fullScreenCover(isPresented: $shooting) {
                    Camera { source in
                        do {
                            attachments.append(try Attachment(source))
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                    .ignoresSafeArea()
                }
                .onAppear {
                    shooting = camera && UIImagePickerController.isSourceTypeAvailable(.camera)
                    focused = !shooting
                }
                #else
                .onAppear { focused = true }
                #endif
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .interactiveDismissDisabled(saving || edited)
        .sensoryFeedback(.success, trigger: saved)
    }

    private func chip(_ title: String, symbol: String?, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let symbol {
                    Label(title, systemImage: symbol).contentTransition(.symbolEffect(.replace))
                } else {
                    Text(title)
                }
            }
            .font(Theme.Font.detail.weight(.medium))
            .foregroundStyle(on ? Theme.accentForeground : Theme.foreground)
            .padding(.horizontal, Theme.Space.sm)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .glassEffect(on ? .regular.tint(Theme.accent).interactive() : .regular.interactive(), in: .capsule)
        .sensoryFeedback(.selection, trigger: on)
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            if let entry {
                try await model.timeline.edit(entry, content: content == original.content ? nil : content, visibility: visibility)
            } else {
                _ = try await Entries.create(content: content, visibility: visibility, photos: attachments.map(\.source), located: located)
                model.invalidate()
            }
            saved = true
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    EntryEditor(entry: nil, camera: false)
        .environment(AppModel())
}
