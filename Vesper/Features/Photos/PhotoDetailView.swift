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
                        PhotoImage(photo: photo, thumbnail: false, mode: .fit)
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
                PhotoImage(photo: current, thumbnail: true, mode: .fill)
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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        // The page is always black, so its floating buttons are always the dark scheme's white.
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarVisibility(.hidden, for: .tabBar)
        .toolbarVisibility(info ? .visible : .hidden, for: .navigationBar)
        .statusBarHidden(!info)
        #endif
        .environment(\.colorScheme, .dark)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: current.shareURL)
            }
        }
    }

    private func panel(_ photo: Photo) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
                Text(photo.title)
                    .font(Theme.Font.title)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if photos.count > 1 {
                    Text("\(photos.firstIndex { $0.id == photo.id }! + 1) / \(photos.count)")
                        .font(Theme.Font.monoCaption)
                        .contentTransition(.numericText())
                        .opacity(0.6)
                }
            }
            HStack(spacing: Theme.Space.sm) {
                if let date = photo.date {
                    Text(date, format: .dateTime.year().month().day().hour().minute())
                }
                if let map = photo.mapURL {
                    Link(destination: map) {
                        Label("Map", systemImage: "mappin.and.ellipse")
                    }
                }
                Text("\(photo.width)×\(photo.height)")
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
        .padding(Theme.Space.lg)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .frame(maxWidth: Theme.readable)
        .padding(.horizontal, Theme.Space.sm)
        .padding(.bottom, Theme.Space.xs)
        .animation(Theme.Motion.quick, value: photo.id)
    }
}

extension View {
    func photoStacks(_ zoom: Namespace.ID) -> some View {
        navigationDestination(for: PhotoStack.self) { stack in
            PhotoDetailView(photos: stack.photos, start: stack.start)
                #if os(iOS)
                .navigationTransition(.zoom(sourceID: stack.start.id, in: zoom))
                #endif
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
