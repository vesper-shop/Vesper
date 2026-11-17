import Foundation
import Identity
import Testing
@testable import Vesper

@MainActor
struct AppModelTests {
    @Test("Signing out drops the account and starts every feature afresh") func signedOut() throws {
        let model = AppModel()
        let memos = model.memos
        let moment = model.moment
        let atlas = model.atlas
        model.account = try JSONDecoder().decode(Account.self, from: Data(#"{"email": "@a", "name": "A"}"#.utf8))
        model.tab = .settings
        model.signedOut()
        #expect(model.account == nil)
        #expect(model.tab == .memos)
        #expect(model.memos !== memos && model.moment !== moment && model.atlas !== atlas)
        #expect(!model.expired)
    }
}
