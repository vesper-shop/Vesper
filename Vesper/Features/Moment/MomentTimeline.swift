import Consumers
import SwiftUI
import VesperUI

struct MomentTimeline: View {
    let session: MomentSession
    let zoom: Namespace.ID

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Space.xxs, pinnedViews: .sectionHeaders) {
                ForEach(session.days) { day in
                    Section {
                        // Keyed by photo, not position: a new tag filter must not reuse another photo's bubble.
                        ForEach(Array(day.photos.enumerated()), id: \.element.id) { index, photo in
                            NavigationLink(value: photo) {
                                PhotoBubble(
                                    photo: photo,
                                    place: photo.geo.flatMap { session.places[PlaceKey($0)] },
                                    joinedAbove: index > 0,
                                    joinedBelow: index < day.photos.count - 1,
                                    zoom: zoom
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                ShareLink(item: photo.imageURL)
                                if let geo = photo.geo {
                                    Link(destination: URL(string: "https://maps.apple.com/?ll=\(geo.lat),\(geo.lng)")!) {
                                        Label("Open in Maps", systemImage: "map")
                                    }
                                }
                            }
                            .task { await session.locate(photo) }
                            .onAppear {
                                if photo.id == session.photos.last?.id {
                                    Task { await session.paginate() }
                                }
                            }
                        }
                    } header: {
                        Group {
                            if let date = day.day {
                                Text(date, format: .dateTime.month(.wide).day().weekday(.abbreviated))
                            } else {
                                Text("Undated")
                            }
                        }
                        .font(Theme.Font.meta.weight(.medium))
                        .foregroundStyle(Theme.mutedForeground)
                        .padding(.horizontal, Theme.Space.sm)
                        .padding(.vertical, 5)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.top, Theme.Space.xl)
                        .padding(.bottom, Theme.Space.xs)
                    }
                }
                if session.paginating {
                    ProgressView().padding()
                }
            }
            .frame(maxWidth: Theme.readable)
            .padding(.horizontal, Theme.Space.md)
            .padding(.bottom, Theme.Space.tail)
            .frame(maxWidth: .infinity)
        }
        .backToTop()
        // A new filter starts from the top instead of an offset past the shorter result.
        .id(session.tag)
    }
}

extension MomentTimeline {
    struct Skeleton: View {
        var body: some View {
            ScrollView {
                VStack(spacing: Theme.Space.xxs) {
                    ForEach([2, 1], id: \.self) { count in
                        Bone(width: 128, height: 26)
                            .padding(.top, Theme.Space.xl)
                            .padding(.bottom, Theme.Space.xs)
                        ForEach(0..<count, id: \.self) { index in
                            HStack {
                                Spacer(minLength: 0)
                                VStack(alignment: .leading, spacing: 0) {
                                    Theme.skeleton.aspectRatio(4 / 3, contentMode: .fit)
                                    VStack(alignment: .leading, spacing: Theme.Space.xs) {
                                        Bone(width: 140, height: 14)
                                        Bone(height: 11)
                                        Bone(width: 96, height: 9)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    .padding(Theme.Space.md)
                                }
                                .background(Theme.muted)
                                .clipShape(UnevenRoundedRectangle(
                                    topLeadingRadius: 20,
                                    bottomLeadingRadius: 20,
                                    bottomTrailingRadius: index < count - 1 ? 6 : 20,
                                    topTrailingRadius: index > 0 ? 6 : 20,
                                    style: .continuous
                                ))
                                .shimmer()
                                .containerRelativeFrame(.horizontal) { width, _ in min(width * 0.88, 420) }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .frame(maxWidth: Theme.readable)
                .padding(.horizontal, Theme.Space.md)
                .frame(maxWidth: .infinity)
            }
            .scrollDisabled(true)
        }
    }
}

/// Inner corners of a run tighten so consecutive photos of a day read as one message group.
private struct PhotoBubble: View {
    let photo: Photo
    let place: String?
    let joinedAbove: Bool
    let joinedBelow: Bool
    let zoom: Namespace.ID

    var body: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 20,
            bottomLeadingRadius: 20,
            bottomTrailingRadius: joinedBelow ? 6 : 20,
            topTrailingRadius: joinedAbove ? 6 : 20,
            style: .continuous
        )
        HStack {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 0) {
                Theme.muted
                    // Very tall photos are cropped to 4:5 so one photo never fills the screen.
                    .aspectRatio(max(photo.ratio, 0.8), contentMode: .fit)
                    .overlay { PhotoImage(photo: photo, url: photo.thumbnailURL, mode: .fill) }
                    .clipped()
                    .matchedTransitionSource(id: photo.id, in: zoom)

                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(photo.title)
                        .font(Theme.Font.headline)
                    if let description = photo.description, !description.isEmpty {
                        Text(description)
                            .font(Theme.Font.body)
                            .lineLimit(8)
                            .lineSpacing(4)
                    }
                    HStack(spacing: Theme.Space.xs) {
                        Spacer(minLength: 0)
                        if let place {
                            Text(place).transition(.opacity)
                        }
                        if let date = photo.date {
                            Text(date, format: .dateTime.hour().minute())
                                .monospacedDigit()
                                .font(Theme.Font.monoCaption)
                        }
                    }
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.mutedForeground)
                    .animation(Theme.Motion.gentle, value: place)
                }
                .foregroundStyle(Theme.foreground)
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.sm)
                .padding(.bottom, Theme.Space.xs)
            }
            .background(Theme.muted)
            .clipShape(shape)
            .overlay { shape.strokeBorder(Theme.border) }
            .containerRelativeFrame(.horizontal) { width, _ in min(width * 0.88, 420) }
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }
}

#Preview("Skeleton") {
    MomentTimeline.Skeleton().background(Theme.background)
}
