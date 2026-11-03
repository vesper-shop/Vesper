import Consumers
import Foundation
import ImageIO

struct MomentQuery: Hashable {
    let tag: String?
    let revision: Int
}

enum MomentLayout: String, CaseIterable, Identifiable {
    case timeline
    case grid

    var id: Self { self }

    var other: MomentLayout {
        switch self {
        case .timeline: .grid
        case .grid: .timeline
        }
    }

    var title: String {
        switch self {
        case .timeline: "Timeline"
        case .grid: "Grid"
        }
    }

    var symbol: String {
        switch self {
        case .timeline: "bubble.right"
        case .grid: "square.grid.2x2"
        }
    }
}

/// One calendar day of the timeline; `day` is nil for the group of photos without a capture date.
struct MomentDay: Identifiable {
    let day: Date?
    let photos: [Photo]

    var id: Date? { day }
}

/// Reverse-geocoding cache key: coordinates rounded to about 100 m, so nearby photos share a lookup.
struct PlaceKey: Hashable {
    let lat: Int
    let lng: Int

    init(_ geo: Photo.Geo) {
        lat = Int((geo.lat * 1000).rounded())
        lng = Int((geo.lng * 1000).rounded())
    }
}

/// The one photo a post carries: its bytes with EXIF intact, a preview, and what the file says.
struct ComposedPhoto {
    let source: Data
    let preview: CGImage
    let metadata: PhotoMetadata

    init(_ source: Data) throws {
        guard let image = CGImageSourceCreateWithData(source as CFData, nil),
              let preview = CGImageSourceCreateThumbnailAtIndex(image, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 1200,
              ] as CFDictionary)
        else { throw ConsumerError.media("the file is not a supported image") }
        self.source = source
        self.preview = preview
        metadata = try Moment.metadata(source)
    }
}
