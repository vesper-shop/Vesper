import CryptoKit
import Foundation

public enum Entries {
    public static func list(cursor: String? = nil, filters: EntryFilters) async throws -> EntryPage {
        let client = Client()
        var query = [URLQueryItem(name: "in", value: shelf(filters.display))]
        if let cursor { query.append(.init(name: "before", value: cursor)) }
        if let tag = filters.tag { query.append(.init(name: "tag", value: tag)) }
        if let day = filters.day { query.append(.init(name: "day", value: Client.day(day))) }
        let documents: [EntryDocument]
        let next: String?
        if filters.search.isEmpty {
            let page: DocumentPage = try await client.json("entries/documents", query: query, operation: "List entries")
            (documents, next) = (page.documents, page.next)
        } else {
            query.append(.init(name: "q", value: filters.search))
            let page: EntrySummaries = try await client.json("entries", query: query, operation: "Search entries")
            documents = try await withThrowingTaskGroup(of: (Int, EntryDocument).self) { group in
                for (index, summary) in page.entries.enumerated() {
                    group.addTask { (index, try await read(summary.id, client)) }
                }
                return try await group.reduce(into: []) { $0.append($1) }.sorted { $0.0 < $1.0 }.map(\.1)
            }
            next = page.next
        }
        let entries = documents
            .map(\.entry)
            .filter { filters.display != .public || $0.visibility == .public }
        return EntryPage(entries: entries, nextCursor: next)
    }

    public static func dates() async throws -> [Date] {
        let client = Client()
        var dates: [Date] = []
        var cursor: String?
        repeat {
            var query = [URLQueryItem(name: "in", value: "all")]
            if let cursor { query.append(.init(name: "before", value: cursor)) }
            let page: EntrySummaries = try await client.json("entries", query: query, operation: "List entry dates")
            dates += page.entries.map { Date(timeIntervalSince1970: $0.occurredAt / 1000) }
            cursor = page.next
        } while cursor != nil
        return dates
    }

    private static func shelf(_ display: EntryDisplay) -> String {
        switch display {
        case .all, .public: "all"
        case .favorites: "favorites"
        case .archived: "archive"
        }
    }

    private static func read(_ id: Entry.ID, _ client: Client) async throws -> EntryDocument {
        try await client.json("entries/\(id)", operation: "Read entry")
    }

    public static func tags() async throws -> [TagCount] {
        let list: TagList = try await Client().json("tags", operation: "List tags")
        return list.tags
    }

    /// Originals go up one at a time, so only one is held in memory. An entry with photos
    /// happens when its earliest photo was taken.
    public static func create(content: String, visibility: Entry.Visibility, photos: [Data], located: Bool) async throws -> Entry {
        let client = Client()
        var uploads: [(digest: String, thumbnail: Data, meta: PhotoMeta)] = []
        for source in photos {
            let prepared = try Media.prepare(source)
            let digest = SHA256.hash(data: prepared.original).map { String(format: "%02x", $0) }.joined()
            _ = try await client.data(
                "photos", method: "PUT",
                body: .raw(prepared.original, type: "image/png", headers: ["x-content-sha256": digest]),
                operation: "Upload photo"
            )
            uploads.append((digest, prepared.thumbnail, PhotoMeta(
                width: prepared.width,
                height: prepared.height,
                thumbHash: Photo.base64URL(hex: prepared.thumbHash),
                takenAt: prepared.metadata.captured.flatMap(Photos.milliseconds),
                geo: located ? prepared.metadata.geo : nil
            )))
        }
        let draft = EntryDraft(body: body(content), tags: tags(in: content), visibility: visibility, occurredAt: uploads.compactMap(\.meta.takenAt).min())
        let created: Created
        if uploads.isEmpty {
            created = try await client.json("entries", method: "POST", body: .json(draft), operation: "Create entry")
        } else {
            var form = Multipart()
            form.field("entry", String(decoding: try JSONEncoder().encode(draft), as: UTF8.self))
            for upload in uploads {
                form.field("digest", upload.digest)
                form.file("thumb", filename: "thumb.jpg", type: "image/jpeg", upload.thumbnail)
                form.field("mime", "image/png")
                form.field("meta", String(decoding: try JSONEncoder().encode(upload.meta), as: UTF8.self))
            }
            created = try await client.json("entries", method: "POST", body: .form(form), operation: "Create entry")
        }
        return try await read(created.id, client).entry
    }

    public static func update(_ id: Entry.ID, _ update: EntryUpdate) async throws -> Entry {
        let client = Client()
        let patch = EntryPatch(
            body: update.content.map(body),
            tags: update.content.map(tags(in:)),
            visibility: update.visibility,
            pinned: update.pinned,
            favorite: update.favorite,
            archived: update.archived
        )
        _ = try await client.data("entries/\(id)", method: "PATCH", body: .json(patch), operation: "Update entry")
        return try await read(id, client).entry
    }

    public static func delete(_ id: Entry.ID) async throws {
        _ = try await Client().data("entries/\(id)", method: "DELETE", operation: "Delete entry")
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

    /// Drops whitespace-delimited `#tag` tokens, shown as chips instead, and collapses the
    /// horizontal space they leave behind.
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
