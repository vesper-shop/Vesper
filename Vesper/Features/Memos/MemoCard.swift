import Consumers
import SwiftUI
import VesperUI

struct MemoCard: View {
    let item: MemoItem
    let busy: Bool
    let perform: (MemoAction) -> Void

    private var memo: Memo { item.memo }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(spacing: Theme.Space.xs) {
                Text(memo.createdAt, format: .relative(presentation: .named))
                Image(systemName: memo.visibility == .public ? "globe" : "lock")
                    .imageScale(.small)
                    .accessibilityLabel(memo.visibility == .public ? "Public" : "Private")
                Spacer(minLength: 0)
                if busy {
                    ProgressView().controlSize(.small)
                }
                if memo.pinned {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Theme.accent)
                        .transition(.symbolEffect(.appear))
                        .accessibilityLabel("Pinned")
                }
                if memo.favorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Theme.accent)
                        .transition(.symbolEffect(.appear))
                        .accessibilityLabel("Favorite")
                }
                Menu {
                    actions
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 28, height: 22)
                        .contentShape(.rect)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .disabled(busy)
                .accessibilityLabel("Actions")
                .help("Actions")
            }
            .font(Theme.Font.meta)
            .foregroundStyle(Theme.mutedForeground)
            .animation(Theme.Motion.bouncy, value: [memo.pinned, memo.favorite])

            Collapsible {
                MarkdownView(item.document)
            }

            if !memo.tags.isEmpty {
                FlowLayout(spacing: Theme.Space.xs) {
                    ForEach(memo.tags, id: \.self) { tag in
                        Button { perform(.filter(tag: tag)) } label: { Badge("#\(tag)") }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .card()
        .contextMenu { actions }
        .sensoryFeedback(.selection, trigger: [memo.pinned, memo.favorite])
    }

    @ViewBuilder
    private var actions: some View {
        Button(memo.pinned ? "Unpin" : "Pin", systemImage: memo.pinned ? "star.slash" : "star") { perform(.toggle(.pinned)) }
        Button(memo.favorite ? "Unfavorite" : "Favorite", systemImage: memo.favorite ? "heart.slash" : "heart") { perform(.toggle(.favorite)) }
        Button("Edit", systemImage: "pencil") { perform(.edit) }
        Button(memo.archived ? "Restore" : "Archive", systemImage: memo.archived ? "tray.and.arrow.up" : "archivebox") { perform(.toggle(.archived)) }
        Divider()
        ShareLink(item: memo.content)
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { perform(.delete) }
    }
}

extension MemoCard {
    /// `lines` are body line widths as fractions of the card; bars sit on the body's line pitch.
    struct Skeleton: View {
        let lines: [CGFloat]
        let tag: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Bone(width: 64, height: 8)
                GeometryReader { geometry in
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(lines.indices, id: \.self) { index in
                            Bone(width: geometry.size.width * lines[index], height: 9)
                        }
                    }
                }
                .frame(height: CGFloat(lines.count) * 23 - 14)
                if tag {
                    Bone(width: 44, height: 16)
                }
            }
            .shimmer()
            .card()
        }
    }
}

#if DEBUG
#Preview {
    ScrollView {
        MemoCard(item: try! MemoItem(.sample), busy: false) { _ in }
            .padding()
    }
    .background(Theme.background)
}
#endif

#Preview("Skeleton") {
    VStack(spacing: Theme.Space.lg) {
        MemoCard.Skeleton(lines: [0.96, 1, 0.62], tag: true)
        MemoCard.Skeleton(lines: [0.84, 0.4], tag: false)
    }
    .padding()
    .background(Theme.background)
}
