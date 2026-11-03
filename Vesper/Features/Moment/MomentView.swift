import Consumers
import SwiftUI
import VesperUI

struct MomentView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom
    @AppStorage("moment.layout") private var layout = MomentLayout.grid
    @State private var toast: ToastMessage?

    var body: some View {
        @Bindable var session = model.moment
        let revision = model.revisions[.moment, default: 0]
        NavigationStack {
            content(session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .symmetricInsets()
                .background(Theme.background)
                .navigationTitle("Moment")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            withAnimation(Theme.Motion.gentle) { layout = layout.other }
                        } label: {
                            Label(layout.other.title, systemImage: layout.other.symbol)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .help("Show as \(layout.other.title.lowercased())")
                    }
                }
                .safeAreaBar(edge: .top) {
                    if !session.tags.isEmpty {
                        TagBar(tags: session.tags.map { .init(name: $0.name, count: $0.count) }, selection: $session.tag)
                    }
                }
                .refreshable {
                    await session.load()
                    await session.syncTags()
                }
                .task(id: MomentQuery(tag: session.tag, revision: revision)) { await session.load() }
                .task(id: revision) { await session.syncTags() }
                .navigationDestination(for: Photo.self) { photo in
                    PhotoDetailView(photos: session.photos, start: photo)
                        #if os(iOS)
                        .navigationTransition(.zoom(sourceID: photo.id, in: zoom))
                        #endif
                }
                .onChange(of: session.notice) {
                    guard let notice = session.notice else { return }
                    toast = ToastMessage(notice)
                    session.notice = nil
                }
                .toast($toast)
        }
    }

    @ViewBuilder
    private func content(_ session: MomentSession) -> some View {
        if session.photos.isEmpty {
            if let problem = session.problem {
                ProblemView(problem: problem, page: "Moment") { await session.load() }
            } else if session.loading {
                switch layout {
                case .timeline: MomentTimeline.Skeleton()
                case .grid: MomentGrid.Skeleton()
                }
            } else {
                EmptyState("No Photos", message: Text("Photos you publish appear here."))
            }
        } else {
            switch layout {
            case .timeline:
                MomentTimeline(session: session, zoom: zoom).tabSwipe()
            case .grid:
                MomentGrid(session: session, zoom: zoom).tabSwipe()
            }
        }
    }
}

#Preview {
    MomentView()
        .environment(AppModel())
}
