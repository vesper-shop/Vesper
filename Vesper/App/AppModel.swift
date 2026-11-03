import Consumers
import Observation

/// Shell state: the selected tab, one session per feature, and a revision per consumer. Saving a
/// key or publishing bumps only that consumer's revision, so only the features reading it reload.
@Observable
final class AppModel {
    var tab = AppTab.memos
    let memos = MemosSession()
    let moment = MomentSession()
    let atlas = AtlasSession()
    private(set) var revisions: [ConsumerAPI: Int] = [:]

    func invalidate(_ api: ConsumerAPI) {
        revisions[api, default: 0] += 1
    }
}
