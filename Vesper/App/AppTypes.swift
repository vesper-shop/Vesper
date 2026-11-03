import Identity
import Foundation

enum AppTab: CaseIterable, Hashable {
    case memos
    case moment
    case atlas
    case settings

    func neighbor(_ offset: Int) -> AppTab? {
        let tabs = Self.allCases
        let index = tabs.firstIndex(of: self)! + offset
        return tabs.indices.contains(index) ? tabs[index] : nil
    }
}

enum LoadProblem: Equatable {
    case signedOut
    case failed(String)

    /// Nil for cancellations, which are expected when a newer request supersedes one.
    init?(_ error: any Error) {
        switch error {
        case is CancellationError:
            return nil
        case let error as URLError where error.code == .cancelled:
            return nil
        case IdentityError.signedOut:
            self = .signedOut
        default:
            self = .failed(error.localizedDescription)
        }
    }
}
