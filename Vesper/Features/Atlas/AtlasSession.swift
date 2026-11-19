import Consumers
import Foundation
import Observation

/// Every photo and when every entry happened, unfiltered: the calendar and the map cover the
/// whole journal, independently of the other tabs' filters.
@Observable
final class AtlasSession {
    private(set) var photos: [Photo] = []
    private(set) var dates: [Date] = []
    private(set) var loading = true
    private(set) var problem: LoadProblem?

    private var generation = 0

    var months: [AtlasMonth] {
        let calendar = Calendar.current
        // The current month always shows, so today has a place even before its first entry.
        var photos: [Date: [Date: [Photo]]] = [calendar.dateInterval(of: .month, for: .now)!.start: [:]]
        var entries: [Date: [Date: Int]] = [:]
        for photo in self.photos {
            guard let date = photo.date else { continue }
            photos[calendar.dateInterval(of: .month, for: date)!.start, default: [:]][calendar.startOfDay(for: date), default: []].append(photo)
        }
        for date in dates {
            entries[calendar.dateInterval(of: .month, for: date)!.start, default: [:]][calendar.startOfDay(for: date), default: 0] += 1
        }
        return Set(photos.keys).union(entries.keys).sorted(by: >).map { month in
            AtlasMonth(
                month: month,
                days: (photos[month] ?? [:]).mapValues { $0.sorted { $0.date! < $1.date! } },
                entries: entries[month] ?? [:]
            )
        }
    }

    /// Reads every page before publishing, so the views never show a partial stream.
    func load() async {
        generation += 1
        let current = generation
        loading = true
        defer { if current == generation { loading = false } }
        do {
            async let dates = Entries.dates()
            let photos = try await Photos.all()
            let loaded = try await dates
            guard current == generation else { return }
            self.photos = photos
            self.dates = loaded
            problem = nil
        } catch {
            guard current == generation, let problem = LoadProblem(error) else { return }
            self.problem = problem
            if problem == .signedOut {
                photos = []
                dates = []
            }
        }
    }
}
