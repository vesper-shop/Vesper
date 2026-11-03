import Consumers
import SwiftUI
import VesperUI

struct AtlasView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom
    @State private var path: [AtlasRoute] = []
    @AppStorage("atlas.mode") private var mode = AtlasMode.allCases[0]
    @State private var composing = false
    @State private var tracking = false
    @State private var position: MapCoordinate?
    @State private var toast: ToastMessage?

    var body: some View {
        let session = model.atlas
        let revision = model.revisions[.moment, default: 0]
        NavigationStack(path: $path) {
            content(session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .symmetricInsets()
                .background(Theme.background)
                .navigationTitle(mode.title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    if let other = AtlasMode.allCases.first(where: { $0 != mode }) {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                withAnimation(Theme.Motion.gentle) { mode = other }
                            } label: {
                                Label(other.title, systemImage: other.symbol)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .help("Show the \(other.title.lowercased())")
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    VStack(spacing: Theme.Space.sm) {
                        #if os(iOS)
                        if mode == .map {
                            Button {
                                tracking.toggle()
                                if !tracking { position = nil }
                            } label: {
                                Image(systemName: tracking ? "location.fill" : "location")
                                    .contentTransition(.symbolEffect(.replace))
                                    .font(.title3.weight(.semibold))
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)
                            .sensoryFeedback(.selection, trigger: tracking)
                            .accessibilityLabel(tracking ? "Hide Current Location" : "Current Location")
                            .help(tracking ? "Stop showing where you are" : "Show where you are")
                        }
                        #endif
                        if session.problem != .signedOut {
                            Button { composing = true } label: {
                                Image(systemName: "camera.fill")
                                    .font(.title2.weight(.semibold))
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.glassProminent)
                            .buttonBorderShape(.circle)
                            .accessibilityLabel("New Moment")
                            .help("New moment")
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(Theme.Space.lg)
                    .animation(Theme.Motion.bouncy, value: session.problem)
                }
                .overlay(alignment: .top) {
                    #if os(iOS)
                    if mode == .map, session.photos.isEmpty, let problem = session.problem {
                        Button {
                            if problem == .signedOut {
                                model.tab = .settings
                            } else {
                                Task { await session.load() }
                            }
                        } label: {
                            Label(
                                problem == .signedOut ? "Sign in to see your photos here" : "Couldn't load photos · Retry",
                                systemImage: problem == .signedOut ? "person.crop.circle" : "arrow.clockwise"
                            )
                            .font(Theme.Font.meta.weight(.medium))
                            .foregroundStyle(Theme.foreground)
                            .padding(.horizontal, Theme.Space.md)
                            .padding(.vertical, Theme.Space.xs)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .padding(.top, Theme.Space.xs)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else if mode == .map, let position {
                        let text = String(format: "%.5f, %.5f", position.latitude, position.longitude)
                        Button {
                            UIPasteboard.general.string = text
                            toast = ToastMessage("Coordinates copied")
                        } label: {
                            Label(text, systemImage: "doc.on.doc")
                                .font(Theme.Font.mono)
                                .padding(.horizontal, Theme.Space.md)
                                .padding(.vertical, Theme.Space.xs)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .accessibilityHint("Copies the coordinates")
                        .padding(.top, Theme.Space.xs)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    #endif
                }
                .animation(Theme.Motion.gentle, value: position)
                .sheet(isPresented: $composing) { PhotoComposer() }
                .toast($toast)
                .refreshable { await session.load() }
                .task(id: revision) { await session.load() }
                .navigationDestination(for: AtlasRoute.self) { route in
                    switch route {
                    case .photos(let photos, let start):
                        PhotoDetailView(photos: photos, start: start)
                            #if os(iOS)
                            .navigationTransition(.zoom(sourceID: start.id, in: zoom))
                            #endif
                    }
                }
        }
    }

    @ViewBuilder
    private func content(_ session: AtlasSession) -> some View {
        switch mode {
        case .calendar:
            if !session.photos.isEmpty {
                AtlasCalendar(months: session.months, zoom: zoom) { path.append($0) }
                    .tabSwipe()
            } else if let problem = session.problem {
                ProblemView(problem: problem, page: "Atlas") { await session.load() }
            } else if session.loading {
                AtlasCalendar.Skeleton()
            } else {
                EmptyState("No Photos", message: Text("Photos you publish appear here."))
            }
        #if os(iOS)
        case .map:
            // Panning the map owns horizontal drags, so it does not switch tabs.
            let located = session.photos.filter { $0.geo != nil }
            TileMap(
                pins: located.map { MapPin(id: $0.id, latitude: $0.geo!.lat, longitude: $0.geo!.lng, image: $0.thumbnailURL) },
                camera: .britain,
                tracking: tracking,
                select: { id in path.append(.photos(located, start: located.first { $0.id == id }!)) },
                located: { position = $0 }
            )
            .ignoresSafeArea()
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        #endif
        }
    }
}

#Preview {
    AtlasView()
        .environment(AppModel())
}
