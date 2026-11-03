import Foundation

/// The Moment API: `/api/photos` and `/api/tags` on moment.you-find.me.
public enum Moment {
    public static let pageSize = 60

    public static func list(cursor: String? = nil, tag: String? = nil) async throws -> PhotoPage {
        var query = [URLQueryItem(name: "limit", value: String(pageSize))]
        if let cursor { query.append(.init(name: "cursor", value: cursor)) }
        if let tag { query.append(.init(name: "tags", value: tag)) }
        return try await Client(.moment).json("photos", query: query, operation: "List photos")
    }

    public static func tags() async throws -> [TagCount] {
        let list: TagList = try await Client(.moment).json("tags", operation: "List photo tags")
        return list.tags
    }

    public static func metadata(_ source: Data) throws -> PhotoMetadata {
        try Media.metadata(source)
    }

    /// Normalizes the photo as the desktop does, then posts both renditions to
    /// `/api/photos/upload` with the Moment key. The Worker stores them in R2 through its binding
    /// and removes them again if registration fails.
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

        var form = Multipart()
        form.file("file", filename: "photo.png", type: "image/png", prepared.original)
        form.file("thumbnail", filename: "thumbnail.jpg", type: "image/jpeg", prepared.thumbnail)
        form.field("title", title)
        if let description = input.description { form.field("description", description) }
        if let date = input.date { form.field("date", date) }
        if let geo = input.geo { form.field("geo", String(decoding: try JSONEncoder().encode(geo), as: UTF8.self)) }
        form.field("tags", String(decoding: try JSONEncoder().encode(tags), as: UTF8.self))
        form.field("thumbHash", prepared.thumbHash)
        form.field("width", String(prepared.width))
        form.field("height", String(prepared.height))
        form.field("aspectRatio", String(Double(prepared.width) / Double(prepared.height)))
        return try await client.json("photos/upload", method: "POST", body: .form(form), operation: "Upload photo")
    }
}
