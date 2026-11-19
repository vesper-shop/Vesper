import Foundation
import Identity
import Testing
import VesperUI
@testable import Vesper

@MainActor
struct AppModelTests {
    @Test("Signing out drops the account and starts every feature afresh") func signedOut() throws {
        let model = AppModel()
        let timeline = model.timeline
        let photos = model.photos
        let atlas = model.atlas
        model.account = try JSONDecoder().decode(Account.self, from: Data(#"{"email": "@a", "name": "A"}"#.utf8))
        model.tab = .settings
        model.signedOut()
        #expect(model.account == nil)
        #expect(model.tab == .timeline)
        #expect(model.timeline !== timeline && model.photos !== photos && model.atlas !== atlas)
        #expect(!model.expired)
    }

    @Test("A compose link opens the editor where the app is; the Atlas link opens its tab") func open() throws {
        let model = AppModel()
        model.tab = .photos
        model.open(try #require(Route(URL(string: "vesper://shoot")!)))
        #expect(model.tab == .photos && model.compose == Compose(camera: true))
        model.open(try #require(Route(URL(string: "vesper://write")!)))
        #expect(model.compose == Compose(camera: false))
        model.open(try #require(Route(URL(string: "vesper://atlas")!)))
        #expect(model.tab == .atlas)
        #expect(Route(URL(string: "vesper://oauth/callback?code=x")!) == nil)
    }
}
