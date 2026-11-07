import Consumers
import VesperMarkdown

/// A memo with its body compiled once, so rendering never re-parses Markdown.
struct MemoItem: Identifiable {
    let memo: Memo
    let document: MarkdownDocument

    var id: Memo.ID { memo.id }

    init(_ memo: Memo) throws {
        self.memo = memo
        document = try MarkdownDocument(memo: Memos.strip(memo.content))
    }
}

enum MemoFlag {
    case pinned
    case favorite
    case archived
}

enum MemoAction {
    case toggle(MemoFlag)
    case edit
    case delete
    case filter(tag: String)
}

struct MemosQuery: Hashable {
    let filters: MemoFilters
    let revision: Int
}

extension MemoDisplay {
    var title: String {
        switch self {
        case .all: "Memos"
        case .public: "Public"
        case .favorites: "Favorites"
        case .archived: "Archive"
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
