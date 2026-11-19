import Consumers
import SwiftUI

struct PhotoMenu: View {
    let photo: Photo

    var body: some View {
        ShareLink(item: photo.shareURL)
        if let map = photo.mapURL {
            Link(destination: map) {
                Label("Open in Maps", systemImage: "map")
            }
        }
    }
}
