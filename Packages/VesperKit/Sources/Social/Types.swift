import Foundation

public enum SocialProvider: String, CaseIterable, Identifiable, Sendable {
    case x
    case telegram

    public var id: Self { self }

    public var title: String {
        switch self {
        case .x: "X"
        case .telegram: "Telegram"
        }
    }

    /// Counted as `social::text` counts: X weighs non-ASCII characters double, Telegram counts UTF-16.
    var limit: Int {
        switch self {
        case .x: 280
        case .telegram: 4_096
        }
    }

    func measure(_ text: String) -> Int {
        switch self {
        case .x: text.reduce(0) { $0 + ($1.isASCII ? 1 : 2) }
        case .telegram: text.utf16.count
        }
    }
}

public enum SocialError: LocalizedError, Sendable {
    case notPublic
    case empty

    public var errorDescription: String? {
        switch self {
        case .notPublic: "Only public memos can be published."
        case .empty: "The memo has no text to publish."
        }
    }
}
