import Foundation

/// The Memo API: `/api/memos`, `/api/memos/{id}` and `/api/tags` on memos.you-find.me.
public enum Memos {
    public static let pageSize = 25

    public static func list(cursor: String? = nil, filters: MemoFilters) async throws -> MemoPage {
        var query = [URLQueryItem(name: "limit", value: String(pageSize))]
        if let cursor { query.append(.init(name: "cursor", value: cursor)) }
        if !filters.search.isEmpty { query.append(.init(name: "search", value: filters.search)) }
        if let tag = filters.tag { query.append(.init(name: "tags", value: tag)) }
        switch filters.display {
        case .all: break
        case .public: query.append(.init(name: "publicOnly", value: "true"))
        case .favorites: query.append(.init(name: "favoritesOnly", value: "true"))
        case .archived: query.append(.init(name: "archivedOnly", value: "true"))
        }
        return try await Client(.memos).json("memos", query: query, operation: "List memos")
    }

    public static func tags() async throws -> [TagCount] {
        let list: TagList = try await Client(.memos).json("tags", operation: "List memo tags")
        return list.tags
    }

    public static func create(content: String, visibility: Memo.Visibility) async throws -> Memo {
        let body = MemoDraft(content: content, visibility: visibility)
        let result: MemoEnvelope = try await Client(.memos).json("memos", method: "POST", body: .json(body), operation: "Create memo")
        return result.memo
    }

    public static func update(_ id: Memo.ID, _ update: MemoUpdate) async throws -> Memo {
        let result: MemoEnvelope = try await Client(.memos).json("memos/\(id)", method: "PATCH", body: .json(update), operation: "Update memo")
        return result.memo
    }

    public static func delete(_ id: Memo.ID) async throws {
        _ = try await Client(.memos).data("memos/\(id)", method: "DELETE", operation: "Delete memo")
    }

    /// Mirrors `consumers::api::memos::strip_tags`: drops whitespace-delimited `#tag` tokens and
    /// collapses the horizontal space they leave behind.
    public static func strip(_ content: String) -> String {
        let tagged: (Character) -> Bool = { $0.isLetter || $0.isNumber || "_-/".contains($0) }
        let characters = Array(content)
        var output = ""
        var index = 0
        while index < characters.count {
            if characters[index] == "#",
               index == 0 || characters[index - 1].isWhitespace,
               index + 1 < characters.count,
               characters[index + 1] != "#",
               tagged(characters[index + 1]) {
                var end = index + 1
                while end < characters.count, tagged(characters[end]) {
                    end += 1
                }
                if end == characters.count || characters[end].isWhitespace {
                    index = end
                    continue
                }
            }
            output.append(characters[index])
            index += 1
        }
        var compact = ""
        var spaced = false
        for character in output {
            let horizontal = character == " " || character == "\t"
            if horizontal, spaced { continue }
            spaced = horizontal
            compact.append(character)
        }
        return compact.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
