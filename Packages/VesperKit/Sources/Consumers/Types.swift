import CoreGraphics
import Foundation

// MARK: - Services

public enum ConsumerAPI: String, CaseIterable, Identifiable, Sendable {
    case memos
    case moment

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .memos: "Memos"
        case .moment: "Moment"
        }
    }

    /// Both read Vesper; memos are entries without photos.
    public var baseURL: URL { URL(string: "https://noted-this.date")! }
}

public enum ConsumerError: LocalizedError, Sendable {
    case status(operation: String, code: Int)
    case invalid(String)
    case media(String)

    public var errorDescription: String? {
        switch self {
        case .status(let operation, let code): "\(operation) returned \(code)."
        case .invalid(let message): message
        case .media(let message): "The photo could not be processed: \(message)."
        }
    }
}

public struct TagCount: Decodable, Hashable, Sendable {
    public let name: String
    public let count: Int
}

struct TagList: Decodable {
    let tags: [TagCount]
}

enum RequestBody {
    case json(any Encodable)
    case form(Multipart)
    case raw(Data, type: String, headers: [String: String])
}

struct Multipart {
    let boundary = "vesper-\(UUID().uuidString)"
    private var parts = Data()

    mutating func field(_ name: String, _ value: String) {
        parts.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
    }

    mutating func file(_ name: String, filename: String, type: String, _ content: Data) {
        parts.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(type)\r\n\r\n".utf8))
        parts.append(content)
        parts.append(Data("\r\n".utf8))
    }

    var body: Data {
        parts + Data("--\(boundary)--\r\n".utf8)
    }
}

// MARK: - Memos

public struct Memo: Identifiable, Hashable, Sendable {
    public enum Visibility: String, Codable, CaseIterable, Sendable {
        case `public`
        case `private`
    }

    public let id: String
    public let content: String
    public let tags: [String]
    public let createdAt: Date
    public let updatedAt: Date
    public let visibility: Visibility
    public let pinned: Bool
    public let favorite: Bool
    public let archived: Bool
}

public struct MemoPage: Sendable {
    public let memos: [Memo]
    public let nextCursor: String?
}

struct EntryDocument: Decodable {
    struct Meta: Decodable {
        let id: String
        let occurred: Date
        let visibility: Memo.Visibility
        let pinned: String?
        let favorite: String?
        let archived: String?
        let tags: [String]
        let photos: [String]
    }

    let meta: Meta
    let body: String
    let photos: [EntryPhoto]?

    var memo: Memo {
        let line = meta.tags.map { "#\($0)" }.joined(separator: " ")
        let trimmed = body.replacing(/\s+$/, with: "")
        return Memo(
            id: meta.id,
            content: line.isEmpty ? trimmed : "\(trimmed)\n\n\(line)",
            tags: meta.tags,
            createdAt: meta.occurred,
            updatedAt: meta.occurred,
            visibility: meta.visibility,
            pinned: meta.pinned != nil,
            favorite: meta.favorite != nil,
            archived: meta.archived != nil
        )
    }
}

struct EntryPhoto: Decodable {
    let id: String
    let width: Int
    let height: Int
    let takenAt: Double?
    let geo: Photo.Geo?
    let thumbHash: String
}

struct DocumentPage: Decodable {
    let documents: [EntryDocument]
    let next: String?
}

struct EntrySummaries: Decodable {
    struct Summary: Decodable {
        let id: String
        let photos: [EntryPhoto]
    }

    let entries: [Summary]
    let next: String?
}

struct Created: Decodable {
    let id: String
}

/// Which slice of the feed a list reads; the API excludes archived memos unless asked.
public enum MemoDisplay: String, CaseIterable, Identifiable, Sendable {
    case all
    case `public`
    case favorites
    case archived

    public var id: Self { self }

    public func contains(_ memo: Memo) -> Bool {
        switch self {
        case .all: !memo.archived
        case .public: memo.visibility == .public && !memo.archived
        case .favorites: memo.favorite && !memo.archived
        case .archived: memo.archived
        }
    }
}

public struct MemoFilters: Hashable, Sendable {
    public var display = MemoDisplay.all
    public var search = ""
    public var tag: String?

    public init() {}

    public var active: Bool {
        display != .all || tag != nil || !search.isEmpty
    }
}

/// A PATCH body; nil fields are left unchanged.
public struct MemoUpdate: Sendable {
    public var content: String?
    public var visibility: Memo.Visibility?
    public var pinned: Bool?
    public var favorite: Bool?
    public var archived: Bool?

    public init(
        content: String? = nil,
        visibility: Memo.Visibility? = nil,
        pinned: Bool? = nil,
        favorite: Bool? = nil,
        archived: Bool? = nil
    ) {
        self.content = content
        self.visibility = visibility
        self.pinned = pinned
        self.favorite = favorite
        self.archived = archived
    }
}

/// Nil fields are omitted, so PATCH leaves them unchanged.
struct EntryPatch: Encodable {
    let body: String?
    let tags: [String]?
    let visibility: Memo.Visibility?
    let pinned: Bool?
    let favorite: Bool?
    let archived: Bool?
}

// MARK: - Moment

struct PhotoEntry: Encodable {
    let body: String
    let tags: [String]
    let visibility: Memo.Visibility
    let occurredAt: Int?
}

/// Vesper's schema requires every field, null when unknown.
struct PhotoMeta: Encodable {
    let width: Int
    let height: Int
    let thumbHash: String
    let takenAt: Int?
    let geo: Photo.Geo?

    func encode(to encoder: any Encoder) throws {
        var meta = encoder.container(keyedBy: Key.self)
        try meta.encode(width, forKey: .width)
        try meta.encode(height, forKey: .height)
        try meta.encode(thumbHash, forKey: .thumbHash)
        try meta.encode(takenAt, forKey: .takenAt)
        try meta.encode(geo, forKey: .geo)
        try meta.encodeNil(forKey: .place)
        var exif = meta.nestedContainer(keyedBy: Key.self, forKey: .exif)
        for key in [Key.camera, .lens, .focalLength, .fNumber, .exposure, .iso, .film] {
            try exif.encodeNil(forKey: key)
        }
    }

    enum Key: String, CodingKey {
        case width, height, thumbHash, takenAt, geo, place, exif
        case camera, lens, focalLength, fNumber, exposure, iso, film
    }
}

public struct Photo: Decodable, Identifiable, Hashable, Sendable {
    public struct Geo: Codable, Hashable, Sendable {
        public let lat: Double
        public let lng: Double

        public init(lat: Double, lng: Double) {
            self.lat = lat
            self.lng = lng
        }
    }

    public let id: String
    public let entryId: String
    public let thumbHash: String?
    public let title: String
    public let width: Int
    public let height: Int
    public let tags: [String]
    public let date: Date?
    public let description: String?
    public let geo: Geo?

    public var shareURL: URL { URL(string: "https://moment.you-find.me/photos/\(id)")! }
    public var ratio: Double { Double(width) / Double(height) }
    public var placeholder: CGImage? { thumbHash.map(ThumbHash.image) }

    init(id: String, entryId: String, caption: String, tags: [String], width: Int, height: Int,
         takenAt: Double?, occurredAt: Double, geo: Geo?, thumbHash: String) {
        self.id = id
        self.entryId = entryId
        if let gap = caption.range(of: "\n\n") {
            let rest = caption[gap.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            self.title = String(caption[..<gap.lowerBound])
            self.description = rest.isEmpty ? nil : rest
        } else {
            self.title = caption
            self.description = nil
        }
        self.tags = tags
        self.width = width
        self.height = height
        let milliseconds = if let takenAt { takenAt } else { occurredAt }
        self.date = Date(timeIntervalSince1970: milliseconds / 1000)
        self.geo = geo
        self.thumbHash = Photo.hex(base64URL: thumbHash)
    }

    public init(from decoder: any Decoder) throws {
        let item = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: item.decode(String.self, forKey: .id),
            entryId: item.decode(String.self, forKey: .entryId),
            caption: item.decode(String.self, forKey: .caption),
            tags: item.decode([String].self, forKey: .tags),
            width: item.decode(Int.self, forKey: .width),
            height: item.decode(Int.self, forKey: .height),
            takenAt: item.decodeIfPresent(Double.self, forKey: .takenAt),
            occurredAt: item.decode(Double.self, forKey: .occurredAt),
            geo: item.decodeIfPresent(Geo.self, forKey: .geo),
            thumbHash: item.decode(String.self, forKey: .thumbHash)
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, entryId, caption, tags, width, height, takenAt, occurredAt, geo, thumbHash
    }

    static func hex(base64URL value: String) -> String? {
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64).map { $0.map { String(format: "%02x", $0) }.joined() }
    }

    static func base64URL(hex value: String) -> String {
        var bytes = Data()
        var rest = Substring(value)
        while let byte = UInt8(rest.prefix(2), radix: 16), rest.count >= 2 {
            bytes.append(byte)
            rest = rest.dropFirst(2)
        }
        return bytes.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

public struct PhotoPage: Decodable, Sendable {
    public let photos: [Photo]
    public let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case photos
        case nextCursor = "next"
    }
}

/// What a photo's own file says about it: EXIF capture time (local, with its offset when
/// recorded) and GPS position.
public struct PhotoMetadata: Hashable, Sendable {
    public let captured: String?
    public let geo: Photo.Geo?
}

public struct PhotoInput: Sendable {
    public var title: String
    public var description: String?
    public var tags: [String]
    public var date: String?
    public var geo: Photo.Geo?

    public init(title: String, description: String?, tags: [String], date: String?, geo: Photo.Geo?) {
        self.title = title
        self.description = description
        self.tags = tags
        self.date = date
        self.geo = geo
    }
}

/// A source image normalized for publication, as `media::prepare` produces it.
struct PreparedPhoto {
    let original: Data
    let thumbnail: Data
    let width: Int
    let height: Int
    let thumbHash: String
    let metadata: PhotoMetadata
}
