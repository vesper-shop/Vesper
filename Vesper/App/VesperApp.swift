import SwiftUI

@main
struct VesperApp: App {
    init() {
        // Moment thumbnails and originals are immutable, so a generous HTTP cache pays off.
        URLCache.shared = URLCache(memoryCapacity: 64 << 20, diskCapacity: 512 << 20)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
