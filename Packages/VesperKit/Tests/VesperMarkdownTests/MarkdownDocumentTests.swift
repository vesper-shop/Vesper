import Foundation
import Testing
@testable import VesperMarkdown

struct MarkdownDocumentTests {
    @Test("Memo newlines become line breaks") func breaks() throws {
        let document = try MarkdownDocument(memo: "line one\nline two")
        let block = try #require(texts(document).first)
        #expect(String(block.content.characters) == "line one\nline two")
    }

    @Test("Standard Markdown joins soft breaks") func soft() throws {
        let block = try #require(texts(try MarkdownDocument("line one\nline two")).first)
        #expect(String(block.content.characters) == "line one line two")
    }

    @Test("Lists carry markers and depth") func lists() throws {
        let blocks = texts(try MarkdownDocument(memo: "- [ ] todo\n- [x] done\n  - nested\n1. first\n2. second"))
        #expect(blocks.map(\.marker) == [.task(done: false), .task(done: true), .bullet, .number(1), .number(2)])
        #expect(blocks.map(\.layout.listDepth) == [1, 1, 2, 1, 1])
        #expect(String(blocks[0].content.characters) == "todo")
    }

    @Test("Quotes, headings, code and rules") func blocks() throws {
        let document = try MarkdownDocument(memo: "# Title\n\n> quoted\n\n```swift\nlet x = 1\n```\n\n---")
        guard document.blocks.count == 4,
              case .text(let heading) = document.blocks[0],
              case .text(let quote) = document.blocks[1],
              case .code(let code) = document.blocks[2],
              case .rule = document.blocks[3]
        else {
            Issue.record("unexpected blocks: \(document.blocks)")
            return
        }
        #expect(heading.style == .heading(level: 1))
        #expect(quote.layout.quoteDepth == 1)
        #expect(code.language == "swift")
        #expect(code.code == "let x = 1")
    }

    @Test("Tables collect header and rows") func tables() throws {
        let document = try MarkdownDocument(memo: "| a | b |\n|---|--:|\n| 1 | 2 |\n| 3 | 4 |")
        guard case .table(let table) = try #require(document.blocks.first) else {
            Issue.record("expected a table")
            return
        }
        #expect(table.header.map { String($0.characters) } == ["a", "b"])
        #expect(table.rows.map { $0.map { String($0.characters) } } == [["1", "2"], ["3", "4"]])
        #expect(table.alignments == [.leading, .trailing])
    }

    @Test("Bare URLs link outside code") func autolink() throws {
        let block = try #require(texts(try MarkdownDocument(memo: "see https://you-find.me and `https://code.example`")).first)
        let links = block.content.runs.compactMap(\.link)
        #expect(links == [URL(string: "https://you-find.me")!])
    }

    private func texts(_ document: MarkdownDocument) -> [TextBlock] {
        document.blocks.compactMap { if case .text(let block) = $0 { block } else { nil } }
    }
}
