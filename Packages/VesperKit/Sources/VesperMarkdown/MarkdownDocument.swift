import Foundation

public struct MarkdownDocument: Hashable, Sendable {
    public let blocks: [MarkdownBlock]

    public init(_ source: String) throws {
        let parsed = try AttributedString(markdown: source, options: .init(interpretedSyntax: .full))
        var blocks: [MarkdownBlock] = []
        var markedItems = Set<Int>()
        var tables: [Int: Int] = [:]

        for (intent, range) in parsed.runs[\.presentationIntent] {
            guard let intent, let leaf = intent.components.first else { continue }
            let ancestors = intent.components.dropFirst()
            let layout = BlockLayout(
                listDepth: ancestors.count { $0.kind == .orderedList || $0.kind == .unorderedList },
                quoteDepth: ancestors.count { $0.kind == .blockQuote }
            )
            var content = AttributedString(parsed[range])

            switch leaf.kind {
            case .codeBlock(let language):
                var code = String(content.characters)
                if code.hasSuffix("\n") { code.removeLast() }
                blocks.append(.code(CodeBlock(id: leaf.identity, language: language, code: code, layout: layout)))

            case .thematicBreak:
                blocks.append(.rule(id: leaf.identity, layout: layout))

            case .tableCell(let column):
                // Ancestors run cell row → table; an empty cell yields no run, so cells are placed by index.
                let row = ancestors[ancestors.startIndex]
                let table = ancestors[ancestors.startIndex + 1]
                guard case .table(let columns) = table.kind else { continue }
                if tables[table.identity] == nil {
                    tables[table.identity] = blocks.count
                    let alignments: [TableBlock.Alignment] = columns.map {
                        switch $0.alignment {
                        case .center: .center
                        case .right: .trailing
                        default: .leading
                        }
                    }
                    let empty = Array(repeating: AttributedString(), count: columns.count)
                    blocks.append(.table(TableBlock(id: table.identity, alignments: alignments, header: empty, rows: [], layout: layout)))
                }
                guard let index = tables[table.identity], case .table(var block) = blocks[index] else { continue }
                if case .tableRow(let rowIndex) = row.kind {
                    while block.rows.count < rowIndex {
                        block.rows.append(Array(repeating: AttributedString(), count: columns.count))
                    }
                    block.rows[rowIndex - 1][column] = content
                } else {
                    block.header[column] = content
                }
                blocks[index] = .table(block)

            default:
                var marker: ListMarker?
                if let item = ancestors.first, case .listItem(let ordinal) = item.kind, markedItems.insert(item.identity).inserted {
                    if ancestors.dropFirst().first?.kind == .orderedList {
                        marker = .number(ordinal)
                    } else {
                        // GFM task items reach Foundation as plain `[ ] ` / `[x] ` text.
                        let prefix = String(content.characters.prefix(4))
                        if ["[ ] ", "[x] ", "[X] "].contains(prefix) {
                            content.removeSubrange(content.startIndex..<content.characters.index(content.startIndex, offsetBy: 4))
                            marker = .task(done: prefix != "[ ] ")
                        } else {
                            marker = .bullet
                        }
                    }
                }
                let style: TextBlock.Style = if case .header(let level) = leaf.kind { .heading(level: level) } else { .paragraph }
                Self.autolink(&content)
                blocks.append(.text(TextBlock(id: leaf.identity, style: style, content: content, marker: marker, layout: layout)))
            }
        }
        self.blocks = blocks
    }

    /// Memo flavor, matching `markdown::render_memo`: every newline outside fenced code is a line
    /// break. Two trailing spaces are CommonMark's hard break; the parser drops them at paragraph ends.
    public init(memo source: String) throws {
        var fenced = false
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let fence = trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~")
            if fence { fenced.toggle() }
            return fenced || fence || trimmed.isEmpty ? String(line) : line + "  "
        }
        try self.init(lines.joined(separator: "\n"))
    }

    private static let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// Links bare URLs outside links and inline code, like the desktop compiler's `autolink_text`.
    private static func autolink(_ text: inout AttributedString) {
        let plain = String(text.characters)
        for match in detector.matches(in: plain, range: NSRange(plain.startIndex..., in: plain)) {
            let range = Range(match.range, in: plain)!
            let span = AttributedString.Index(range.lowerBound, within: text)!..<AttributedString.Index(range.upperBound, within: text)!
            let plainSpan = text[span].runs.allSatisfy { $0.link == nil && $0.inlinePresentationIntent?.contains(.code) != true }
            if plainSpan { text[span].link = match.url }
        }
    }
}
