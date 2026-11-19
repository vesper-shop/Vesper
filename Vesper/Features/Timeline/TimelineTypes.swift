import Consumers
import ImageIO
import SwiftUI
import VesperMarkdown

/// An entry with its text compiled once, so rendering never re-parses Markdown.
struct EntryItem: Identifiable {
    let entry: Entry
    let document: MarkdownDocument

    var id: Entry.ID { entry.id }

    init(_ entry: Entry) throws {
        self.entry = entry
        document = try MarkdownDocument(memo: Entries.strip(entry.content))
    }
}

enum EntryFlag {
    case pinned
    case favorite
    case archived
}

enum EntryAction {
    case toggle(EntryFlag)
    case edit
    case delete
    case filter(tag: String)
}

struct TimelineQuery: Hashable {
    let filters: EntryFilters
    let revision: Int
}

struct Attachment: Identifiable {
    let id = UUID()
    let source: Data
    let preview: CGImage
    let geo: Photo.Geo?

    init(_ source: Data) throws {
        guard let image = CGImageSourceCreateWithData(source as CFData, nil),
              let preview = CGImageSourceCreateThumbnailAtIndex(image, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 600,
              ] as CFDictionary)
        else { throw ConsumerError.media("the file is not a supported image") }
        self.source = source
        self.preview = preview
        geo = try Photos.metadata(source).geo
    }
}

extension EntryDisplay {
    var title: String {
        switch self {
        case .all: "Timeline"
        case .public: "Public"
        case .favorites: "Favorites"
        case .archived: "Archive"
        }
    }

    var blank: (title: LocalizedStringKey, message: LocalizedStringKey) {
        switch self {
        case .all: ("Nothing Written Yet", "Write a few lines or add up to four photos.")
        case .public: ("Nothing Public", "Entries you make public appear here.")
        case .favorites: ("No Favorites", "Favorite an entry from its ⋯ menu to keep it close.")
        case .archived: ("Archive Is Empty", "Archived entries rest here, out of the timeline.")
        }
    }

    var symbol: String {
        switch self {
        case .all: "tray.full"
        case .public: "globe"
        case .favorites: "heart"
        case .archived: "archivebox"
        }
    }
}
