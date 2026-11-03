import Consumers
import SwiftUI
import VesperUI

struct MomentGrid: View {
    let session: MomentSession
    let zoom: Namespace.ID
    @AppStorage("moment.lanes") private var lanes = 2
    @Environment(\.horizontalSizeClass) private var width

    var body: some View {
        ScrollView {
            Masonry(session.photos, lanes: width == .regular ? lanes + 2 : lanes, spacing: Theme.Space.xs, ratio: \.ratio) { photo in
                NavigationLink(value: photo) {
                    Theme.muted
                        .overlay { PhotoImage(photo: photo, url: photo.thumbnailURL, mode: .fill) }
                        .clipShape(.rect(cornerRadius: Theme.Radius.lg))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.border)
                        }
                        .matchedTransitionSource(id: photo.id, in: zoom)
                        .accessibilityLabel(photo.title)
                }
                .buttonStyle(.plain)
                .onAppear {
                    // Any lane can hold the newest photos, so the tail of each lane triggers the next page.
                    if session.photos.suffix(lanes).contains(photo) {
                        Task { await session.paginate() }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.top, Theme.Space.xs)
            .animation(Theme.Motion.gentle, value: lanes)
            if session.paginating {
                ProgressView().padding()
            }
            Color.clear.frame(height: Theme.Space.tail)
        }
        .backToTop()
        .id(session.tag)
        .sensoryFeedback(.selection, trigger: lanes)
        .simultaneousGesture(
            MagnifyGesture().onEnded { value in
                if value.magnification > 1.15 { lanes = max(lanes - 1, 1) }
                if value.magnification < 0.85 { lanes = min(lanes + 1, 4) }
            }
        )
    }
}

extension MomentGrid {
    struct Skeleton: View {
        @AppStorage("moment.lanes") private var lanes = 2
        @Environment(\.horizontalSizeClass) private var width

        var body: some View {
            let count = width == .regular ? lanes + 2 : lanes
            let ratios: [CGFloat] = [0.75, 1.33, 1, 0.8, 1.5, 0.75, 1.2, 1, 0.8, 1.33, 0.75, 1]
            ScrollView {
                HStack(alignment: .top, spacing: Theme.Space.xs) {
                    ForEach(0..<count, id: \.self) { lane in
                        VStack(spacing: Theme.Space.xs) {
                            ForEach(Array(stride(from: lane, to: ratios.count, by: count)), id: \.self) { index in
                                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                                    .fill(Theme.skeleton)
                                    .aspectRatio(ratios[index], contentMode: .fit)
                            }
                        }
                    }
                }
                .shimmer()
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.xs)
            }
            .scrollDisabled(true)
        }
    }
}

#Preview("Skeleton") {
    MomentGrid.Skeleton().background(Theme.background)
}
