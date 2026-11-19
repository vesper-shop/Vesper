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
                    let count = month.entries.values.reduce(0, +)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(month.month, format: .dateTime.year().month(.wide))
                                .font(Theme.Font.title)
                            Spacer()
                            Text("^[\(count) entry](inflect: true)")
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
                                let photos = month.days[day]
                                Group {
                                    if photos != nil || month.entries[day] != nil {
                                        Button { open(.day(day)) } label: {
                                            Theme.muted
                                                .aspectRatio(1, contentMode: .fit)
                                                .overlay {
                                                    if let photos {
                                                        PhotoImage(photo: photos[0], thumbnail: true, mode: .fill)
                                                    }
                                                }
                                                .clipShape(.rect(cornerRadius: Theme.Radius.md))
                                                .overlay(alignment: photos == nil ? .center : .topLeading) {
                                                    Text("\(number)")
                                                        .font(Theme.Font.monoCaption.weight(.semibold))
                                                        .foregroundStyle(photos == nil ? Theme.foreground : Theme.onDark)
                                                        .shadow(color: Theme.shadow.opacity(photos == nil ? 0 : 0.6), radius: 2)
                                                        .padding(4)
                                                }
                                                .overlay(alignment: .bottom) {
                                                    if photos == nil {
                                                        Circle()
                                                            .fill(Theme.accent)
                                                            .frame(width: 5, height: 5)
                                                            .padding(.bottom, 5)
                                                    }
                                                }
                                                .overlay(alignment: .bottomTrailing) {
                                                    if let photos, photos.count > 1 {
                                                        Text("\(photos.count)")
                                                            .font(Theme.Font.monoCaption)
                                                            .foregroundStyle(Theme.onDark)
                                                            .padding(.horizontal, 4)
                                                            .background(Theme.scrim, in: .capsule)
                                                            .padding(3)
                                                    }
                                                }
                                                .matchedTransitionSource(id: day, in: zoom)
                                        }
                                        .buttonStyle(.press)
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
