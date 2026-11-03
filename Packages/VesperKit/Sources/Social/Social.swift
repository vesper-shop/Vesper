import Consumers
import Foundation
import VesperMarkdown

/// Memo publication text and compose links, mirroring `crates/social`: public memos only, plain
/// text with a blank line between blocks, X without `#tags`, bounded per provider.
public enum Social {
    public static func text(_ memo: Memo, for provider: SocialProvider) throws -> String {
        guard memo.visibility == .public else { throw SocialError.notPublic }
        let source = provider == .x ? Memos.strip(memo.content) : memo.content
        let blocks = try MarkdownDocument(memo: source).blocks.map { block in
            switch block {
            case .text(let text): String(text.content.characters)
            case .code(let code): code.code
            case .table(let table): ([table.header] + table.rows).map { $0.map { String($0.characters) }.joined(separator: " ") }.joined(separator: "\n")
            case .rule: ""
            }
        }
        let plain = blocks
            .map { $0.split(separator: "\n", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n") }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard !plain.isEmpty else { throw SocialError.empty }
        guard provider.measure(plain) > provider.limit else { return plain }
        let target = provider.limit - provider.measure("…")
        var cut = ""
        for character in plain {
            guard provider.measure(cut + String(character)) <= target else { break }
            cut.append(character)
        }
        return cut.trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    /// Opens the provider's composer with the text filled in; posting stays one tap in that app.
    public static func compose(_ memo: Memo, on provider: SocialProvider) throws -> URL {
        let text = try text(memo, for: provider)
        var components = switch provider {
        case .x: URLComponents(string: "https://x.com/intent/post")!
        case .telegram: URLComponents(string: "tg://msg")!
        }
        components.queryItems = [URLQueryItem(name: "text", value: text)]
        return components.url!
    }
}
