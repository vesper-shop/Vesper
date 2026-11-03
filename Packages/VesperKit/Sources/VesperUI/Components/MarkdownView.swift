import SwiftUI
import VesperMarkdown

/// Renders a `MarkdownDocument` with the `.memo-content` typography of the desktop app.
public struct MarkdownView: View {
    let document: MarkdownDocument

    public init(_ document: MarkdownDocument) {
        self.document = document
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(document.blocks) { block in
                QuoteFrame(depth: block.layout.quoteDepth) {
                    BlockView(block: block)
                }
            }
        }
        .font(Theme.Font.body)
        .foregroundStyle(Theme.foreground)
        .tint(Theme.accent)
        .lineSpacing(5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum Metrics {
    static let markerWidth: CGFloat = 20
    static let quoteIndent: CGFloat = 14
}

private struct BlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case .text(let text):
            TextBlockView(block: text)
        case .code(let code):
            ScrollView(.horizontal) {
                Text(code.code)
                    .font(Theme.Font.mono)
                    .fixedSize()
                    .padding(12)
            }
            .scrollIndicators(.hidden)
            .background(Theme.muted.opacity(0.5), in: .rect(cornerRadius: Theme.Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.lg).strokeBorder(Theme.border)
            }
            .padding(.leading, CGFloat(code.layout.listDepth) * Metrics.markerWidth)
        case .table(let table):
            TableView(table: table)
                .padding(.leading, CGFloat(table.layout.listDepth) * Metrics.markerWidth)
        case .rule:
            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
                .padding(.vertical, 4)
        }
    }
}

private struct TextBlockView: View {
    let block: TextBlock

    var body: some View {
        let depth = CGFloat(block.layout.listDepth)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if let marker = block.marker {
                MarkerView(marker: marker)
                    .frame(width: Metrics.markerWidth, alignment: .leading)
            }
            Text(InlineStyle.apply(to: block.content))
                .font(font)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, block.marker == nil ? depth * Metrics.markerWidth : max(depth - 1, 0) * Metrics.markerWidth)
        .padding(.top, isHeading ? 4 : 0)
    }

    private var isHeading: Bool {
        if case .heading = block.style { true } else { false }
    }

    private var font: Font {
        switch block.style {
        case .paragraph: Theme.Font.body
        case .heading(let level) where level <= 1: Theme.Font.display
        case .heading(let level) where level == 2: Theme.Font.title
        case .heading: Theme.Font.headline
        }
    }
}

private struct MarkerView: View {
    let marker: ListMarker

    var body: some View {
        switch marker {
        case .bullet:
            Text("•").foregroundStyle(Theme.mutedForeground)
        case .number(let number):
            Text("\(number).").foregroundStyle(Theme.mutedForeground).monospacedDigit()
        case .task(let done):
            Image(systemName: done ? "checkmark.square.fill" : "square")
                .font(Theme.Font.meta)
                .foregroundStyle(done ? Theme.accent : Theme.mutedForeground)
        }
    }
}

private struct QuoteFrame<Content: View>: View {
    let depth: Int
    @ViewBuilder let content: Content

    var body: some View {
        if depth == 0 {
            content
        } else {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Theme.accent.opacity(0.45))
                    .frame(width: 3)
                content
                    .foregroundStyle(Theme.mutedForeground)
                    .padding(.leading, Metrics.quoteIndent - 3)
            }
            .padding(.leading, CGFloat(depth - 1) * Metrics.quoteIndent)
        }
    }
}

private struct TableView: View {
    let table: TableBlock

    var body: some View {
        ScrollView(.horizontal) {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(table.header.indices, id: \.self) { column in
                        cell(table.header[column], column: column).fontWeight(.semibold)
                    }
                }
                .background(Theme.muted.opacity(0.5))
                ForEach(table.rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(table.rows[row].indices, id: \.self) { column in
                            cell(table.rows[row][column], column: column)
                        }
                    }
                }
            }
            .overlay { Rectangle().strokeBorder(Theme.border) }
        }
        .scrollIndicators(.hidden)
    }

    private func cell(_ content: AttributedString, column: Int) -> some View {
        Text(InlineStyle.apply(to: content))
            .font(Theme.Font.detail)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: table.alignments[column].frame)
            .border(Theme.border, width: 0.5)
    }
}

private extension TableBlock.Alignment {
    var frame: Alignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

enum InlineStyle {
    static func apply(to content: AttributedString) -> AttributedString {
        var styled = content
        for run in content.runs {
            if run.inlinePresentationIntent?.contains(.code) == true {
                styled[run.range].font = Theme.Font.mono
                styled[run.range].backgroundColor = Theme.muted
            }
            if run.link != nil {
                styled[run.range].foregroundColor = Theme.accent
                styled[run.range].underlineStyle = .single
            }
        }
        return styled
    }
}

#Preview {
    ScrollView {
        MarkdownView(try! MarkdownDocument(memo: """
        # Heading
        Some **bold**, *italic*, `code` and https://you-find.me
        second line

        - [x] done
        - [ ] todo
          - nested
        1. first
        2. second

        > quoted text

        ```swift
        let greeting = "hello"
        ```

        | key | value |
        |-----|------:|
        | a   | 1     |

        ---
        """))
        .padding()
    }
    .background(Theme.background)
}
