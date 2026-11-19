import Consumers
import SwiftUI
import VesperUI

/// Every entry of one day, read-only; their actions stay on the timeline.
struct DayView: View {
    let day: Date
    let count: Int
    let zoom: Namespace.ID
    @State private var items: [EntryItem] = []
    @State private var loading = true
    @State private var problem: LoadProblem?

    var body: some View {
        Group {
            if let problem {
                ProblemView(problem: problem, page: "This Day") { await load() }
            } else if !loading && items.isEmpty {
                EmptyState("Nothing Here", message: Text("No entries on this day."))
            } else {
                ScrollView {
                    VStack(spacing: Theme.Space.lg) {
                        if loading {
                            ForEach(0..<count, id: \.self) { _ in
                                EntryCard.Skeleton(lines: [0.92, 0.6], tag: false)
                            }
                        } else {
                            ForEach(items) { item in
                                EntryCard(item: item, busy: false, zoom: zoom, perform: nil)
                            }
                        }
                    }
                    .frame(maxWidth: Theme.readable)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.top, Theme.Space.sm)
                    .padding(.bottom, Theme.Space.tail)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle(Text(day, format: .dateTime.weekday(.wide).month(.wide).day()))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        var filters = EntryFilters()
        filters.day = day
        do {
            var entries: [Entry] = []
            var cursor: String?
            repeat {
                let page = try await Entries.list(cursor: cursor, filters: filters)
                entries += page.entries
                cursor = page.nextCursor
            } while cursor != nil
            items = try entries.sorted { $0.occurred < $1.occurred }.map(EntryItem.init)
            problem = nil
        } catch {
            problem = LoadProblem(error)
        }
    }
}
