import Identity
import SwiftUI
import VesperUI

struct RootView: View {
    @Bindable var model: AppModel
    @State private var launching = true
    @State private var played = false

    var body: some View {
        Group {
            if model.account != nil {
                TabView(selection: $model.tab) {
                    Tab("Timeline", systemImage: "text.below.photo", value: AppTab.timeline) {
                        TimelineView()
                    }
                    Tab("Photos", systemImage: "photo.on.rectangle.angled", value: AppTab.photos) {
                        PhotosView()
                    }
                    Tab("Atlas", systemImage: "map", value: AppTab.atlas) {
                        AtlasView()
                    }
                    Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                        SettingsView()
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
                #if os(iOS)
                .tabBarMinimizeBehavior(.onScrollDown)
                #endif
                .sheet(item: $model.compose) { EntryEditor(entry: nil, camera: $0.camera) }
                .transition(.opacity)
            } else if model.read {
                SignInView().transition(.opacity)
            }
        }
        .tint(Theme.accent)
        .overlay {
            if launching {
                Splash().transition(.opacity)
            }
        }
        // After two seconds a slow network is left to the page's skeleton.
        .onChange(of: model.timeline.loading) { lift() }
        .onChange(of: model.read) { lift() }
        .onChange(of: model.expired) {
            guard model.expired else { return }
            model.failure = IdentityError.expired.localizedDescription
            withAnimation(Theme.Motion.gentle) { model.signedOut() }
        }
        .task {
            do {
                model.account = try await Identity.shared.saved()
            } catch {
                model.failure = error.localizedDescription
            }
            model.read = true
        }
        .task {
            do {
                try await Task.sleep(for: .seconds(0.9))
                played = true
                lift()
                try await Task.sleep(for: .seconds(1.1))
            } catch {
                return
            }
            withAnimation(Theme.Motion.gentle) { launching = false }
        }
        .onOpenURL { url in Route(url).map(model.open) }
        .environment(model)
    }
}

extension RootView {
    private func lift() {
        guard played, model.read, model.account == nil || !model.timeline.loading else { return }
        withAnimation(Theme.Motion.gentle) { launching = false }
    }
}

#Preview {
    RootView(model: AppModel())
}
