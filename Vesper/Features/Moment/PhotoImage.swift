import Consumers
import SwiftUI
import VesperUI

struct PhotoImage: View {
    let photo: Photo
    let url: URL
    let mode: ContentMode

    var body: some View {
        AsyncImage(url: url, transaction: .init(animation: Theme.Motion.gentle)) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: mode)
            } else if let placeholder = photo.placeholder {
                Image(decorative: placeholder, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: mode)
            } else {
                Theme.muted
            }
        }
    }
}
