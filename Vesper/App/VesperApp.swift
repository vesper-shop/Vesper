import AppIntents
import SwiftUI

@main
struct VesperApp: App {
    @State private var model: AppModel

    init() {
        // Photo thumbnails and originals are immutable, so a generous HTTP cache pays off.
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
        let model = AppModel()
        _model = State(initialValue: model)
        AppDependencyManager.shared.add(dependency: model)
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
