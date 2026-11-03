import Consumers
import SwiftUI
import VesperUI

struct PhotoDetailView: View {
    let photos: [Photo]
    @State private var selection: Photo.ID?
    @State private var info = true
    @State private var zoomed = false

    init(photos: [Photo], start: Photo) {
        self.photos = photos
        _selection = State(initialValue: start.id)
    }

    private var current: Photo {
        photos.first { $0.id == selection }!
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(photos) { photo in
                    Zoomable(zoomed: $zoomed) {
                        withAnimation(Theme.Motion.gentle) { info.toggle() }
                    } content: {
                        // The cached thumbnail shows while the original downloads.
                        AsyncImage(url: photo.imageURL, transaction: .init(animation: Theme.Motion.gentle)) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFit()
                            } else {
                                PhotoImage(photo: photo, url: photo.thumbnailURL, mode: .fit)
                            }
                        }
                        .aspectRatio(photo.ratio, contentMode: .fit)
                    }
                    .containerRelativeFrame([.horizontal, .vertical])
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $selection)
        .scrollDisabled(zoomed)
        .scrollIndicators(.hidden)
        .background {
            ZStack {
                Color.black
                PhotoImage(photo: current, url: current.thumbnailURL, mode: .fill)
                    .blur(radius: 60, opaque: true)
                    .overlay(Theme.scrim)
                    .id(current.id)
                    .transition(.opacity)
            }
            .animation(Theme.Motion.gentle, value: current.id)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            if info && !zoomed {
                panel(current).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(current.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        // The page is always black, so its title and floating buttons are always the dark scheme's white.
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarVisibility(.hidden, for: .tabBar)
        #endif
        .environment(\.colorScheme, .dark)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: current.imageURL)
            }
        }
    }

    private func panel(_ photo: Photo) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(photo.title)
                .font(Theme.Font.title)
            HStack(spacing: Theme.Space.sm) {
                if let date = photo.date {
                    Text(date, format: .dateTime.year().month().day().hour().minute())
                }
                if let geo = photo.geo {
                    Link(destination: URL(string: "https://maps.apple.com/?ll=\(geo.lat),\(geo.lng)")!) {
                        Label("Map", systemImage: "mappin.and.ellipse")
                    }
                }
                if let format = photo.format {
                    Text("\(format) · \(photo.width)×\(photo.height)")
                }
            }
            .font(Theme.Font.meta)
            .opacity(0.75)

            if let description = photo.description, !description.isEmpty {
                ScrollView {
                    Text(description)
                        .font(Theme.Font.detail)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 140)
                .fixedSize(horizontal: false, vertical: true)
                .scrollIndicators(.hidden)
            }

            if !photo.tags.isEmpty {
                Text(photo.tags.map { "#\($0)" }.joined(separator: "  "))
                    .font(Theme.Font.meta.weight(.medium))
                    .opacity(0.75)
            }
        }
        .foregroundStyle(Theme.onDark)
        .tint(Theme.onDark)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Space.lg)
        .padding(.top, 72)
        .padding(.bottom, Theme.Space.sm)
        .background {
            LinearGradient(colors: [.clear, Theme.scrim], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PhotoDetailView(photos: [.sample], start: .sample)
    }
}
#endif
