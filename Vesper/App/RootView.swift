import SwiftUI
import VesperUI

struct RootView: View {
    @State private var model = AppModel()
    @State private var launching = true
    @State private var played = false

    var body: some View {
        TabView(selection: $model.tab) {
            Tab("Memos", systemImage: "note.text", value: AppTab.memos) {
                MemosView()
            }
            Tab("Moment", systemImage: "photo.on.rectangle.angled", value: AppTab.moment) {
                MomentView()
            }
            Tab("Atlas", systemImage: "map", value: AppTab.atlas) {
                AtlasView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
        .tint(Theme.accent)
        .overlay {
            if launching {
                Splash().transition(.opacity)
            }
        }
        // After two seconds a slow network is left to the page's skeleton.
        .onChange(of: model.memos.loading) { lift() }
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
        .environment(model)
    }
}

extension RootView {
    private func lift() {
        guard played, !model.memos.loading else { return }
        withAnimation(Theme.Motion.gentle) { launching = false }
    }
}

#Preview {
    RootView()
}
