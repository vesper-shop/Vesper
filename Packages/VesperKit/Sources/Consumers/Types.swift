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

    public var baseURL: URL {
        switch self {
        case .memos: URL(string: "https://memos.you-find.me")!
        case .moment: URL(string: "https://moment.you-find.me")!
        }
    }
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

public struct Memo: Decodable, Identifiable, Hashable, Sendable {
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

public struct MemoPage: Decodable, Sendable {
    public let memos: [Memo]
    public let nextCursor: String?
}

struct MemoEnvelope: Decodable {
    let memo: Memo
}

struct MemoDraft: Encodable {
    let content: String
    let tags: [String] = []
    let visibility: Memo.Visibility
    let favorite = false
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
public struct MemoUpdate: Encodable, Sendable {
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

// MARK: - Moment

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
    public let url: String
    public let thumbnailUrl: String
    /// Hex-encoded; photos posted before hashes were kept have none.
    public let thumbHash: String?
    public let title: String
    public let width: Int
    public let height: Int
    public let tags: [String]
    public let date: Date?
    public let description: String?
    public let format: String?
    public let geo: Geo?

    /// The API returns site-relative image paths; images need no key.
    public var imageURL: URL { URL(string: url, relativeTo: ConsumerAPI.moment.baseURL)!.absoluteURL }
    public var thumbnailURL: URL { URL(string: thumbnailUrl, relativeTo: ConsumerAPI.moment.baseURL)!.absoluteURL }
    public var ratio: Double { Double(width) / Double(height) }
    public var placeholder: CGImage? { thumbHash.map(ThumbHash.image) }
}

public struct PhotoPage: Decodable, Sendable {
    public let photos: [Photo]
    public let nextCursor: String?
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
