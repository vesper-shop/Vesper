import Consumers
import Foundation
import Identity
import Observation
import VesperUI
import WidgetKit

@Observable
final class AppModel {
    var account: Account?
    /// False until the Keychain has been read, so a signed-in launch never flashes the sign-in page.
    var read = false
    var failure: String?
    var tab = AppTab.timeline
    var compose: Compose?
    private(set) var timeline = TimelineSession()
    private(set) var photos = PhotosSession()
    private(set) var atlas = AtlasSession()
    /// Bumped when entries are written, so every view of them reloads.
    private(set) var revision = 0

    var expired: Bool {
        [timeline.problem, photos.problem, atlas.problem].contains(.signedOut)
    }

    func invalidate() {
        revision += 1
        WidgetCenter.shared.reloadAllTimelines()
    }

    func open(_ route: Route) {
        switch route {
        case .write: compose = Compose(camera: false)
        case .shoot: compose = Compose(camera: true)
        case .atlas: tab = .atlas
        }
    }

    func signedOut() {
        account = nil
        tab = .timeline
        compose = nil
        WidgetCenter.shared.reloadAllTimelines()
        timeline = TimelineSession()
        photos = PhotosSession()
        atlas = AtlasSession()
    }
}
