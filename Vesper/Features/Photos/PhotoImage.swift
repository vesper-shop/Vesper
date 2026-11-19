import Consumers
import os
import SwiftUI
import VesperUI

struct PhotoImage: View {
    let photo: Photo
    let thumbnail: Bool
    let mode: ContentMode

    @State private var image: CGImage?

    nonisolated(unsafe) private static let cache = NSCache<NSString, CGImage>()
    nonisolated private static let log = Logger(subsystem: "me.youfind.vesper", category: "photos")

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: mode)
            } else if let placeholder = photo.placeholder {
                Image(decorative: placeholder, scale: 1).resizable().aspectRatio(contentMode: mode)
            } else {
                Theme.muted
            }
        }
        .animation(Theme.Motion.gentle, value: image)
        .task(id: "\(photo.id)-\(thumbnail)") {
            if !thumbnail, let loaded = await Self.load(photo, thumbnail: true) { image = loaded }
            if let loaded = await Self.load(photo, thumbnail: thumbnail) { image = loaded }
        }
    }

    /// Nil when cancelled or after logging the failure, leaving the placeholder in place.
    nonisolated static func load(_ photo: Photo, thumbnail: Bool) async -> CGImage? {
        let key = "\(photo.id)-\(thumbnail)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        do {
            let image = try await Photos.image(photo, thumbnail: thumbnail)
            cache.setObject(image, forKey: key)
            return image
        } catch {
            if LoadProblem(error) != nil {
                log.error("Photo \(photo.id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
            return nil
        }
    }
}
