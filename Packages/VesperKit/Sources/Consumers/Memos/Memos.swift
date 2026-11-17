import Foundation

public enum Memos {
    public static let pageSize = 50

    public static func list(cursor: String? = nil, filters: MemoFilters) async throws -> MemoPage {
        let client = Client(.memos)
        var query = [URLQueryItem(name: "in", value: shelf(filters.display))]
        if let cursor { query.append(.init(name: "before", value: cursor)) }
        if let tag = filters.tag { query.append(.init(name: "tag", value: tag)) }
        let documents: [EntryDocument]
        let next: String?
        if filters.search.isEmpty {
            let page: DocumentPage = try await client.json("entries/documents", query: query, operation: "List memos")
            (documents, next) = (page.documents, page.next)
        } else {
            query.append(.init(name: "q", value: filters.search))
            let page: EntrySummaries = try await client.json("entries", query: query, operation: "Search memos")
            documents = try await withThrowingTaskGroup(of: (Int, EntryDocument).self) { group in
                for (index, summary) in page.entries.enumerated() where summary.photos.isEmpty {
                    group.addTask { (index, try await read(summary.id, client)) }
                }
                return try await group.reduce(into: []) { $0.append($1) }.sorted { $0.0 < $1.0 }.map(\.1)
            }
            next = page.next
        }
        let memos = documents
            .filter { $0.meta.photos.isEmpty }
            .map(\.memo)
            .filter { filters.display != .public || $0.visibility == .public }
        return MemoPage(memos: memos, nextCursor: next)
    }

    private static func shelf(_ display: MemoDisplay) -> String {
        switch display {
        case .all, .public: "all"
        case .favorites: "favorites"
        case .archived: "archive"
        }
    }

    private static func read(_ id: Memo.ID, _ client: Client) async throws -> EntryDocument {
        try await client.json("entries/\(id)", operation: "Read memo")
    }

    public static func tags() async throws -> [TagCount] {
        let list: TagList = try await Client(.memos).json("tags", operation: "List memo tags")
        return list.tags
    }

    public static func create(content: String, visibility: Memo.Visibility) async throws -> Memo {
        let client = Client(.memos)
        let draft = EntryPatch(body: body(content), tags: tags(in: content), visibility: visibility,
                               pinned: nil, favorite: nil, archived: nil)
        let created: Created = try await client.json("entries", method: "POST", body: .json(draft), operation: "Create memo")
        return try await read(created.id, client).memo
    }

    public static func update(_ id: Memo.ID, _ update: MemoUpdate) async throws -> Memo {
        let client = Client(.memos)
        let patch = EntryPatch(
            body: update.content.map(body),
            tags: update.content.map(tags(in:)),
            visibility: update.visibility,
            pinned: update.pinned,
            favorite: update.favorite,
            archived: update.archived
        )
        _ = try await client.data("entries/\(id)", method: "PATCH", body: .json(patch), operation: "Update memo")
        return try await read(id, client).memo
    }

    public static func delete(_ id: Memo.ID) async throws {
        _ = try await Client(.memos).data("entries/\(id)", method: "DELETE", operation: "Delete memo")
    }

    private static func isTag(_ word: Substring) -> Bool {
        guard word.first == "#" else { return false }
        let name = word.dropFirst()
        return !name.isEmpty && name.first != "#" && name.allSatisfy { $0.isLetter || $0.isNumber || "_-/".contains($0) }
    }

    /// The content without its closing hashtag lines, as Vesper stores the body.
    static func body(_ content: String) -> String {
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        while let last = lines.last {
            let trimmed = last.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.split(separator: " ").allSatisfy(isTag) {
                lines.removeLast()
            } else {
                break
            }
        }
        return lines.joined(separator: "\n")
    }

    static func tags(in content: String) -> [String] {
        var tags: [String] = []
        for word in content.split(whereSeparator: \.isWhitespace) where isTag(word) {
            let tag = word.dropFirst().lowercased()
            if !tags.contains(tag) { tags.append(tag) }
        }
        return tags
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
