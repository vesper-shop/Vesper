import SwiftUI

public struct TagBar: View {
    let tags: [TagChip]
    @Binding var selection: String?

    public init(tags: [TagChip], selection: Binding<String?>) {
        self.tags = tags
        _selection = selection
    }

    public var body: some View {
        // The container wraps the scroll view; nesting it inside misplaces the glass layer.
        GlassEffectContainer(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.name) { tag in
                        chip(tag)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            .rail()
        }
    }

    private func chip(_ tag: TagChip) -> some View {
        let selected = selection == tag.name
        return Button {
            withAnimation(Theme.Motion.gentle) {
                selection = selected ? nil : tag.name
            }
        } label: {
            HStack(spacing: 4) {
                Text("#\(tag.name)")
                Text("\(tag.count)")
                    .contentTransition(.numericText(value: Double(tag.count)))
                    .font(Theme.Font.monoCaption)
                    .opacity(0.65)
            }
            .font(Theme.Font.detail.weight(.medium))
            .foregroundStyle(selected ? Theme.accentForeground : Theme.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(selected ? .regular.tint(Theme.accent).interactive() : .regular.interactive(), in: .capsule)
    }
}

#Preview {
    @Previewable @State var selection: String? = "日常"
    TagBar(
        tags: [.init(name: "思考", count: 54), .init(name: "日常", count: 32), .init(name: "开发", count: 31)],
        selection: $selection
    )
}
