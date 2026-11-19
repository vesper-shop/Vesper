import Consumers
import SwiftUI
import VesperUI
import WidgetKit

struct Heatmap: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "me.youfind.vesper.month", provider: HeatmapProvider()) { entry in
            HeatmapView(entry: entry)
        }
        .configurationDisplayName("Heatmap")
        .description("Days with photos: this month, or the last six months when wide.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HeatmapProvider: DailyProvider {
    static let weeks = 26

    static func start(_ today: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .weekOfYear, value: 1 - weeks, to: calendar.dateInterval(of: .weekOfYear, for: today)!.start)!
    }

    func placeholder(in context: Context) -> HeatmapEntry {
        HeatmapEntry(date: .now, days: [:], problem: nil)
    }

    func fetch() async throws -> HeatmapEntry {
        let today = Date.now
        var days: [Date: Int] = [:]
        for date in try await Photos.all(days: Self.start(today)...today).compactMap(\.date) {
            days[Calendar.current.startOfDay(for: date), default: 0] += 1
        }
        return HeatmapEntry(date: today, days: days, problem: nil)
    }

    func failed(_ problem: WidgetProblem) -> HeatmapEntry {
        HeatmapEntry(date: .now, days: [:], problem: problem)
    }
}

struct HeatmapView: View {
    let entry: HeatmapEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let calendar = Calendar.current
        let wide = family == .systemMedium
        let month = calendar.dateInterval(of: .month, for: entry.date)!
        let first = wide ? HeatmapProvider.start(entry.date) : month.start
        let photos = entry.days.filter { $0.key >= first }.values.reduce(0, +)
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(alignment: .firstTextBaseline) {
                if wide {
                    Text("\(first, format: .dateTime.month(.abbreviated)) – \(entry.date, format: .dateTime.month(.abbreviated))")
                        .font(Theme.Font.headline)
                } else {
                    Text(entry.date, format: .dateTime.month(.wide))
                        .font(Theme.Font.headline)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                switch entry.problem {
                case .signedOut:
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .accessibilityLabel("Open Vesper to sign in")
                case .failed:
                    Image(systemName: "wifi.exclamationmark")
                        .accessibilityLabel("Couldn't reach Vesper")
                case nil:
                    Text(wide ? "^[\(photos) photo](inflect: true)" : "\(photos)")
                        .font(Theme.Font.monoCaption)
                        .foregroundStyle(Theme.mutedForeground)
                        .accessibilityLabel("^[\(photos) photo](inflect: true)")
                }
            }
            .foregroundStyle(Theme.foreground)

            if wide {
                Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                    GridRow {
                        ForEach(0..<HeatmapProvider.weeks, id: \.self) { week in
                            let opening = calendar.date(byAdding: .weekOfYear, value: week, to: first)!
                            let opens = calendar.component(.day, from: opening) <= 7
                            Text(opens ? opening.formatted(.dateTime.month(.abbreviated)) : "")
                                .font(Theme.Font.monoCaption)
                                .foregroundStyle(Theme.mutedForeground)
                                .fixedSize()
                                .frame(width: 1, alignment: .leading)
                        }
                    }
                    ForEach(0..<7, id: \.self) { weekday in
                        GridRow {
                            ForEach(0..<HeatmapProvider.weeks, id: \.self) { week in
                                cell(calendar.date(byAdding: .day, value: week * 7 + weekday, to: first)!)
                            }
                        }
                    }
                }
            } else {
                let lead = calendar.dateComponents([.day], from: calendar.dateInterval(of: .weekOfYear, for: month.start)!.start, to: month.start).day!
                let count = calendar.range(of: .day, in: .month, for: month.start)!.count
                Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                    ForEach(0..<((lead + count + 6) / 7), id: \.self) { week in
                        GridRow {
                            ForEach(0..<7, id: \.self) { weekday in
                                let day = calendar.date(byAdding: .day, value: week * 7 + weekday - lead, to: month.start)!
                                if month.contains(day) {
                                    cell(day)
                                } else {
                                    Color.clear.aspectRatio(1, contentMode: .fit)
                                }
                            }
                        }
                    }
                }
            }
        }
        .containerBackground(Theme.background, for: .widget)
        .widgetURL(Route.atlas.url)
    }

    private func cell(_ day: Date) -> some View {
        let count = entry.days[day]
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(day > entry.date ? Theme.muted.opacity(0.4) : count.map { Theme.accent.opacity(min(0.35 + Double($0) * 0.2, 1)) } ?? Theme.muted)
            .widgetAccentable(count != nil)
            .overlay {
                if Calendar.current.isDate(day, inSameDayAs: entry.date) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Theme.foreground, lineWidth: 1.5)
                }
            }
            .aspectRatio(1, contentMode: .fit)
    }
}
