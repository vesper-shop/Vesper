import CryptoKit
import Foundation

public enum Moment {
    public static let pageSize = 24

    public static func list(cursor: String? = nil, tag: String? = nil) async throws -> PhotoPage {
        var query: [URLQueryItem] = []
        if let cursor { query.append(.init(name: "before", value: cursor)) }
        if let tag { query.append(.init(name: "tag", value: tag)) }
        return try await Client(.moment).json("photos", query: query, operation: "List photos")
    }

    public static func tags() async throws -> [TagCount] {
        let list: TagList = try await Client(.moment).json("tags", operation: "List photo tags")
        return list.tags
    }

    public static func metadata(_ source: Data) throws -> PhotoMetadata {
        try Media.metadata(source)
    }

    /// Vesper serves photos only to the owner.
    public static func image(_ photo: Photo, thumbnail: Bool) async throws -> Data {
        try await Client(.moment).data(
            "photos/\(photo.id)",
            method: "GET",
            query: [.init(name: "size", value: thumbnail ? "thumb" : "original")],
            operation: "Read photo"
        )
    }

    public static func upload(_ source: Data, input: PhotoInput) async throws -> Photo {
        let title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = input.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard (1...120).contains(title.count) else { throw ConsumerError.invalid("A title of 1 to 120 characters is required.") }
        if let description = input.description, description.count > 500 {
            throw ConsumerError.invalid("The description is longer than 500 characters.")
        }
        guard tags.count <= 10, tags.allSatisfy({ (1...50).contains($0.count) }) else {
            throw ConsumerError.invalid("Use at most 10 tags of 1 to 50 characters.")
        }
        let client = Client(.moment)
        let prepared = try Media.prepare(source)
        let digest = SHA256.hash(data: prepared.original).map { String(format: "%02x", $0) }.joined()
        _ = try await client.data(
            "photos", method: "PUT",
            body: .raw(prepared.original, type: "image/png", headers: ["x-content-sha256": digest]),
            operation: "Upload photo"
        )
        let description = input.description.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let takenAt = input.date.flatMap(Self.milliseconds)
        let entry = PhotoEntry(
            body: [title, description].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n\n"),
            tags: tags,
            visibility: .public,
            occurredAt: takenAt
        )
        let meta = PhotoMeta(
            width: prepared.width,
            height: prepared.height,
            thumbHash: Photo.base64URL(hex: prepared.thumbHash),
            takenAt: takenAt,
            geo: input.geo
        )
        var form = Multipart()
        form.field("entry", String(decoding: try JSONEncoder().encode(entry), as: UTF8.self))
        form.field("digest", digest)
        form.file("thumb", filename: "thumb.jpg", type: "image/jpeg", prepared.thumbnail)
        form.field("mime", "image/png")
        form.field("meta", String(decoding: try JSONEncoder().encode(meta), as: UTF8.self))
        let created: Created = try await client.json("entries", method: "POST", body: .form(form), operation: "Create photo entry")
        let document: EntryDocument = try await client.json("entries/\(created.id)", operation: "Read photo entry")
        guard let photo = document.photos?.first else { throw ConsumerError.invalid("The new entry has no photo.") }
        return Photo(
            id: photo.id, entryId: created.id, caption: document.body, tags: document.meta.tags,
            width: photo.width, height: photo.height, takenAt: photo.takenAt,
            occurredAt: document.meta.occurred.timeIntervalSince1970 * 1000,
            geo: photo.geo, thumbHash: photo.thumbHash
        )
    }

    static func milliseconds(_ value: String) -> Int? {
        Client.date(value).map { Int($0.timeIntervalSince1970 * 1000) }
    }
}
