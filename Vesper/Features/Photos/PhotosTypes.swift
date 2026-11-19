import Consumers
import Foundation

struct PhotosQuery: Hashable {
    let tag: String?
    let revision: Int
}

struct PhotoStack: Hashable {
    let photos: [Photo]
    let start: Photo
}

extension Photo {
    var mapURL: URL? {
        geo.map { URL(string: "https://maps.apple.com/?ll=\($0.lat),\($0.lng)")! }
    }
}
