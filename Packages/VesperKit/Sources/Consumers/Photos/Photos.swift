import Foundation
import ImageIO

public enum Photos {
    /// `days` are local calendar days; a single day matches the workspace's own midnight.
    public static func list(cursor: String? = nil, tag: String? = nil, days: ClosedRange<Date>? = nil) async throws -> PhotoPage {
        var query: [URLQueryItem] = []
        if let cursor { query.append(.init(name: "before", value: cursor)) }
        if let tag { query.append(.init(name: "tag", value: tag)) }
        if let days {
            if Calendar.current.isDate(days.lowerBound, inSameDayAs: days.upperBound) {
                query.append(.init(name: "day", value: Client.day(days.lowerBound)))
            } else {
                query.append(.init(name: "fromDate", value: Client.day(days.lowerBound)))
                query.append(.init(name: "toDate", value: Client.day(days.upperBound)))
            }
        }
        return try await Client().json("photos", query: query, operation: "List photos")
    }

    public static func all(days: ClosedRange<Date>? = nil) async throws -> [Photo] {
        var photos: [Photo] = []
        var cursor: String?
        repeat {
            let page = try await list(cursor: cursor, days: days)
            photos += page.photos
            cursor = page.nextCursor
        } while cursor != nil
        return photos
    }

    public static func metadata(_ source: Data) throws -> PhotoMetadata {
        try Media.metadata(source)
    }

    /// Vesper serves photos only to the owner. Decoded up front, with the EXIF orientation applied.
    public static func image(_ photo: Photo, thumbnail: Bool) async throws -> CGImage {
        let data = try await Client().data(
            "photos/\(photo.id)",
            method: "GET",
            query: [.init(name: "size", value: thumbnail ? "thumb" : "original")],
            operation: "Read photo"
        )
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceShouldCacheImmediately: true,
              ] as CFDictionary)
        else { throw ConsumerError.media("the photo is not a supported image") }
        return image
    }

    static func milliseconds(_ value: String) -> Int? {
        Client.date(value).map { Int($0.timeIntervalSince1970 * 1000) }
    }
}
