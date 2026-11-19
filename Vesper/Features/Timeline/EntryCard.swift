import Consumers
import SwiftUI
import VesperUI

/// `perform` nil shows the entry read-only, without its actions.
struct EntryCard: View {
    let item: EntryItem
    let busy: Bool
    let zoom: Namespace.ID
    let perform: ((EntryAction) -> Void)?

    private var entry: Entry { item.entry }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(spacing: Theme.Space.xs) {
                Group {
                    if entry.occurred > .now.addingTimeInterval(-86_400) {
                        Text(entry.occurred, format: .relative(presentation: .named))
                    } else if Calendar.current.isDate(entry.occurred, equalTo: .now, toGranularity: .year) {
                        Text(entry.occurred, format: .dateTime.month(.abbreviated).day().hour().minute())
                    } else {
                        Text(entry.occurred, format: .dateTime.year().month(.abbreviated).day())
                    }
                }
                .help(Text(entry.occurred, format: .dateTime.year().month(.wide).day().weekday(.wide).hour().minute()))
                Image(systemName: entry.visibility == .public ? "globe" : "lock")
                    .imageScale(.small)
                    .accessibilityLabel(entry.visibility == .public ? "Public" : "Private")
                Spacer(minLength: 0)
                if busy {
                    ProgressView().controlSize(.small)
                }
                if entry.pinned {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Theme.accent)
                        .transition(.symbolEffect(.appear))
                        .accessibilityLabel("Pinned")
                }
                if entry.favorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Theme.accent)
                        .transition(.symbolEffect(.appear))
                        .accessibilityLabel("Favorite")
                }
                if let perform {
                    Menu {
                        actions(perform)
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 44, height: 36)
                            .contentShape(.rect)
                            .padding(.vertical, -7)
                            .padding(.trailing, -8)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .disabled(busy)
                    .accessibilityLabel("Actions")
                    .help("Actions")
                }
            }
            .font(Theme.Font.meta)
            .foregroundStyle(Theme.mutedForeground)
            .animation(Theme.Motion.bouncy, value: [entry.pinned, entry.favorite])

            if !item.document.blocks.isEmpty {
                Collapsible {
                    MarkdownView(item.document)
                }
            }

            if !entry.photos.isEmpty {
                let single = entry.photos.count == 1
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.xxs), count: single ? 1 : 2), spacing: Theme.Space.xxs) {
                    ForEach(entry.photos) { photo in
                        NavigationLink(value: PhotoStack(photos: entry.photos, start: photo)) {
                            Theme.muted
                                .aspectRatio(single ? min(max(photo.ratio, 0.75), 1.8) : 1, contentMode: .fit)
                                .overlay { PhotoImage(photo: photo, thumbnail: true, mode: .fill) }
                                .clipShape(.rect(cornerRadius: Theme.Radius.md))
                                .matchedTransitionSource(id: photo.id, in: zoom)
                        }
                        .buttonStyle(.press)
                        .contextMenu { PhotoMenu(photo: photo) }
                        .accessibilityLabel("Photo")
                    }
                }
            }

            if !entry.tags.isEmpty {
                FlowLayout(spacing: Theme.Space.xs) {
                    ForEach(entry.tags, id: \.self) { tag in
                        if let perform {
                            Button { perform(.filter(tag: tag)) } label: { Badge("#\(tag)") }
                                .buttonStyle(.press)
                        } else {
                            Badge("#\(tag)")
                        }
                    }
                }
            }
        }
        .card()
        .contextMenu {
            if let perform { actions(perform) }
        }
        .sensoryFeedback(.selection, trigger: [entry.pinned, entry.favorite])
    }

    @ViewBuilder
    private func actions(_ perform: @escaping (EntryAction) -> Void) -> some View {
        Button(entry.pinned ? "Unpin" : "Pin", systemImage: entry.pinned ? "star.slash" : "star") { perform(.toggle(.pinned)) }
        Button(entry.favorite ? "Unfavorite" : "Favorite", systemImage: entry.favorite ? "heart.slash" : "heart") { perform(.toggle(.favorite)) }
        Button("Edit", systemImage: "pencil") { perform(.edit) }
        Button(entry.archived ? "Restore" : "Archive", systemImage: entry.archived ? "tray.and.arrow.up" : "archivebox") { perform(.toggle(.archived)) }
        Divider()
        ShareLink(item: entry.content)
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { perform(.delete) }
    }
}

extension EntryCard {
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
    @Previewable @Namespace var zoom
    ScrollView {
        EntryCard(item: try! EntryItem(.sample), busy: false, zoom: zoom) { _ in }
            .padding()
    }
    .background(Theme.background)
}
#endif

#Preview("Skeleton") {
    VStack(spacing: Theme.Space.lg) {
        EntryCard.Skeleton(lines: [0.96, 1, 0.62], tag: true)
        EntryCard.Skeleton(lines: [0.84, 0.4], tag: false)
    }
    .padding()
    .background(Theme.background)
}
