import Consumers
import SwiftUI
import VesperUI
import WidgetKit

struct OnThisDay: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "me.youfind.vesper.on-this-day", provider: OnThisDayProvider()) { entry in
            OnThisDayView(entry: entry)
        }
        .configurationDisplayName("On This Day")
        .description("Photos taken on this day in earlier years.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct OnThisDayProvider: DailyProvider {
    func placeholder(in context: Context) -> OnThisDayEntry {
        OnThisDayEntry(date: .now, memories: [], problem: nil)
    }

    func fetch() async throws -> OnThisDayEntry {
        let today = Date.now
        let memories = try await withThrowingTaskGroup(of: Memory?.self) { group in
            for years in 1...6 {
                let day = Calendar.current.date(byAdding: .year, value: -years, to: today)!
                group.addTask {
                    guard let photo = try await Photos.list(days: day...day).photos.first else { return nil }
                    return Memory(id: photo.id, title: photo.title, years: years, image: try await Photos.image(photo, thumbnail: true))
                }
            }
            return try await group.compactMap { $0 }.reduce(into: []) { $0.append($1) }.sorted { $0.years < $1.years }
        }
        return OnThisDayEntry(date: today, memories: memories, problem: nil)
    }

    func failed(_ problem: WidgetProblem) -> OnThisDayEntry {
        OnThisDayEntry(date: .now, memories: [], problem: problem)
    }
}

struct OnThisDayView: View {
    let entry: OnThisDayEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let first = entry.memories.first {
                if family == .systemMedium && entry.memories.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(entry.memories.prefix(3)) { memory in
                            frame(memory)
                        }
                    }
                    .padding(4)
                } else {
                    frame(first)
                }
            } else {
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    Text("On This Day")
                        .font(Theme.Font.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(entry.date, format: .dateTime.month(.wide).day())
                        .font(Theme.Font.title)
                    Spacer(minLength: 0)
                    Group {
                        switch entry.problem {
                        case .signedOut: Text("Open Vesper to sign in.")
                        case .failed: Text("Couldn't reach Vesper.")
                        case nil: Text("Nothing from this day yet.")
                        }
                    }
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.mutedForeground)
                }
                .foregroundStyle(Theme.foreground)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(Theme.Space.md)
            }
        }
        .containerBackground(Theme.background, for: .widget)
        .widgetURL(Route.atlas.url)
    }

    private func frame(_ memory: Memory) -> some View {
        Color.clear
            .overlay {
                Image(decorative: memory.image, scale: 1)
                    .resizable()
                    .widgetAccentedRenderingMode(.desaturated)
                    .scaledToFill()
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("^[\(memory.years) year](inflect: true) ago")
                        .font(Theme.Font.caption.weight(.semibold))
                    Text(memory.title)
                        .font(Theme.Font.caption)
                        .lineLimit(1)
                        .opacity(0.85)
                }
                .foregroundStyle(Theme.onDark)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.clear, Theme.scrim], startPoint: .top, endPoint: .bottom))
            }
            .clipShape(.rect(cornerRadius: family == .systemMedium && entry.memories.count > 1 ? 14 : 0))
    }
}
