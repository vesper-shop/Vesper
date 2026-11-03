import Foundation

/// A flat, renderable block. Nesting is expressed through `BlockLayout` rather than a tree, so a
/// view can lay blocks out in one stack.
public enum MarkdownBlock: Identifiable, Hashable, Sendable {
    case text(TextBlock)
    case code(CodeBlock)
    case table(TableBlock)
    case rule(id: Int, layout: BlockLayout)

    public var id: Int {
        switch self {
        case .text(let block): block.id
        case .code(let block): block.id
        case .table(let block): block.id
        case .rule(let id, _): id
        }
    }

    public var layout: BlockLayout {
        switch self {
        case .text(let block): block.layout
        case .code(let block): block.layout
        case .table(let block): block.layout
        case .rule(_, let layout): layout
        }
    }
}

public struct BlockLayout: Hashable, Sendable {
    public var listDepth = 0
    public var quoteDepth = 0
}

public struct TextBlock: Hashable, Sendable {
    public enum Style: Hashable, Sendable {
        case paragraph
        case heading(level: Int)
    }

    public let id: Int
    public let style: Style
    /// Inline Markdown attributes (emphasis, code, links) are preserved for the view to style.
    public let content: AttributedString
    /// Set on the first block of a list item.
    public let marker: ListMarker?
    public let layout: BlockLayout
}

public enum ListMarker: Hashable, Sendable {
    case bullet
    case number(Int)
    case task(done: Bool)
}

public struct CodeBlock: Hashable, Sendable {
    public let id: Int
    public let language: String?
    public let code: String
    public let layout: BlockLayout
}

public struct TableBlock: Hashable, Sendable {
    public enum Alignment: Hashable, Sendable {
        case leading
        case center
        case trailing
    }

    public let id: Int
    public let alignments: [Alignment]
    public internal(set) var header: [AttributedString]
    public internal(set) var rows: [[AttributedString]]
    public let layout: BlockLayout
}
