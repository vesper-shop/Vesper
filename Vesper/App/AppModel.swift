import Consumers
import Identity
import Observation

@Observable
final class AppModel {
    var account: Account?
    /// False until the Keychain has been read, so a signed-in launch never flashes the sign-in page.
    var read = false
    var failure: String?
    var tab = AppTab.memos
    private(set) var memos = MemosSession()
    private(set) var moment = MomentSession()
    private(set) var atlas = AtlasSession()
    private(set) var revisions: [ConsumerAPI: Int] = [:]

    var expired: Bool {
        [memos.problem, moment.problem, atlas.problem].contains(.signedOut)
    }

    func invalidate(_ api: ConsumerAPI) {
        revisions[api, default: 0] += 1
    }

    func signedOut() {
        account = nil
        tab = .memos
        memos = MemosSession()
        moment = MomentSession()
        atlas = AtlasSession()
    }
}
