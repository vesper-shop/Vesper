import Consumers
import SwiftUI
import VesperUI

struct PhotosView: View {
    @Environment(AppModel.self) private var model
    @Namespace private var zoom
    @State private var toast: ToastMessage?

    var body: some View {
        @Bindable var session = model.photos
        let revision = model.revision
        NavigationStack {
            content(session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .symmetricInsets()
                .background(Theme.background)
                .navigationTitle("Photos")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .safeAreaBar(edge: .top) {
                    if !session.tags.isEmpty {
                        TagBar(tags: session.tags.map { .init(name: $0.name, count: $0.count) }, selection: $session.tag)
                    }
                }
                .refreshable {
                    await session.load()
                    await session.syncTags()
                }
                .task(id: PhotosQuery(tag: session.tag, revision: revision)) { await session.load() }
                .task(id: revision) { await session.syncTags() }
                .photoStacks(zoom)
                .onChange(of: session.notice) {
                    guard let notice = session.notice else { return }
                    toast = ToastMessage(notice)
                    session.notice = nil
                }
                .toast($toast)
        }
    }

    @ViewBuilder
    private func content(_ session: PhotosSession) -> some View {
        if session.photos.isEmpty {
            if let problem = session.problem {
                ProblemView(problem: problem, page: "Photos") { await session.load() }
            } else if session.loading {
                PhotoWall.Skeleton()
            } else if let tag = session.tag {
                EmptyState("No Photos Here", message: Text("No photo is tagged #\(tag) yet."))
            } else {
                EmptyState("No Photos Yet", message: Text("Photos added to entries appear here."))
            }
        } else {
            PhotoWall(session: session, zoom: zoom).tabSwipe()
        }
    }
}

#Preview {
    PhotosView()
        .environment(AppModel())
}
