import Consumers
import SwiftUI
import UIKit
import VesperUI

struct PhotoImage: View {
    let photo: Photo
    let thumbnail: Bool
    let mode: ContentMode

    @State private var image: UIImage?

    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: mode)
            } else if let placeholder = photo.placeholder {
                Image(decorative: placeholder, scale: 1).resizable().aspectRatio(contentMode: mode)
            } else {
                Theme.muted
            }
        }
        .animation(Theme.Motion.gentle, value: image)
        .task(id: "\(photo.id)-\(thumbnail)") {
            if !thumbnail { image = await Self.load(photo, thumbnail: true) }
            if let loaded = await Self.load(photo, thumbnail: thumbnail) { image = loaded }
        }
    }

    static func load(_ photo: Photo, thumbnail: Bool) async -> UIImage? {
        let key = "\(photo.id)-\(thumbnail)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = try? await Moment.image(photo, thumbnail: thumbnail),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
