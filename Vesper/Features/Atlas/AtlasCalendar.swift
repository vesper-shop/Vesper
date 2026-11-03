import Consumers
import SwiftUI
import VesperUI

struct AtlasCalendar: View {
    let months: [AtlasMonth]
    let zoom: Namespace.ID
    let open: (AtlasRoute) -> Void

    var body: some View {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let weekdays = Array(symbols[(calendar.firstWeekday - 1)...] + symbols[..<(calendar.firstWeekday - 1)])
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 28, alignment: .top)], alignment: .leading, spacing: 28) {
                ForEach(months) { month in
                    let days = calendar.range(of: .day, in: .month, for: month.month)!
                    let lead = (calendar.component(.weekday, from: month.month) - calendar.firstWeekday + 7) % 7
                    let count = month.days.values.reduce(0) { $0 + $1.count }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(month.month, format: .dateTime.year().month(.wide))
                                .font(Theme.Font.title)
                            Spacer()
                            Text("\(count) \(count == 1 ? "photo" : "photos")")
                                .font(Theme.Font.monoCaption)
                                .foregroundStyle(Theme.mutedForeground)
                        }
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(weekdays.indices, id: \.self) { index in
                                Text(weekdays[index])
                                    .font(Theme.Font.monoCaption)
                                    .foregroundStyle(Theme.mutedForeground)
                            }
                            ForEach(0..<lead, id: \.self) { _ in
                                Color.clear.aspectRatio(1, contentMode: .fit)
                            }
                            ForEach(days, id: \.self) { number in
                                let day = calendar.date(byAdding: .day, value: number - 1, to: month.month)!
                                let today = calendar.isDateInToday(day)
                                Group {
                                    if let photos = month.days[day] {
                                        Button { open(.photos(photos, start: photos[0])) } label: {
                                            Theme.muted
                                                .aspectRatio(1, contentMode: .fit)
                                                .overlay { PhotoImage(photo: photos[0], url: photos[0].thumbnailURL, mode: .fill) }
                                                .clipShape(.rect(cornerRadius: Theme.Radius.md))
                                                .overlay(alignment: .topLeading) {
                                                    Text("\(number)")
                                                        .font(Theme.Font.monoCaption.weight(.semibold))
                                                        .foregroundStyle(Theme.onDark)
                                                        .shadow(color: Theme.shadow.opacity(0.6), radius: 2)
                                                        .padding(4)
                                                }
                                                .overlay(alignment: .bottomTrailing) {
                                                    if photos.count > 1 {
                                                        Text("\(photos.count)")
                                                            .font(Theme.Font.monoCaption)
                                                            .foregroundStyle(Theme.onDark)
                                                            .padding(.horizontal, 4)
                                                            .background(Theme.scrim, in: .capsule)
                                                            .padding(3)
                                                    }
                                                }
                                                .matchedTransitionSource(id: photos[0].id, in: zoom)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(Text(day, format: .dateTime.month().day()))
                                    } else {
                                        Theme.muted.opacity(0.4)
                                            .aspectRatio(1, contentMode: .fit)
                                            .clipShape(.rect(cornerRadius: Theme.Radius.md))
                                            .overlay {
                                                Text("\(number)")
                                                    .font(Theme.Font.monoCaption.weight(today ? .semibold : .regular))
                                                    .foregroundStyle(today ? Theme.accent : Theme.mutedForeground.opacity(0.6))
                                            }
                                    }
                                }
                                .overlay {
                                    if today {
                                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                            .strokeBorder(Theme.accent, lineWidth: 2)
                                    }
                                }
                                .accessibilityAddTraits(today ? .isSelected : [])
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.top, Theme.Space.xs)
            .padding(.bottom, Theme.Space.tail)
        }
        .backToTop()
    }
}

extension AtlasCalendar {
    struct Skeleton: View {
        var body: some View {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(0..<2, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Bone(width: 132, height: 18)
                                Spacer()
                                Bone(width: 56, height: 10)
                            }
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(0..<35, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                        .fill(Theme.skeleton.opacity(0.6))
                                        .aspectRatio(1, contentMode: .fit)
                                }
                            }
                        }
                        .shimmer()
                    }
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.xs)
            }
            .scrollDisabled(true)
        }
    }
}

#Preview("Skeleton") {
    AtlasCalendar.Skeleton().background(Theme.background)
}
