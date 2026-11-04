import Consumers
import Foundation
import Observation

/// Every photo, unfiltered: the calendar and the map cover the whole stream, independently of
/// the Moment tab's tag filter.
@Observable
final class AtlasSession {
    private(set) var photos: [Photo] = []
    private(set) var loading = true
    private(set) var problem: LoadProblem?

    private var generation = 0

    var months: [AtlasMonth] {
        let calendar = Calendar.current
        // The current month always shows, so today has a place even before its first photo.
        var months: [Date: [Date: [Photo]]] = [calendar.dateInterval(of: .month, for: .now)!.start: [:]]
        for photo in photos {
            guard let date = photo.date else { continue }
            let month = calendar.dateInterval(of: .month, for: date)!.start
            months[month, default: [:]][calendar.startOfDay(for: date), default: []].append(photo)
        }
        return months.keys.sorted(by: >).map { month in
            AtlasMonth(month: month, days: months[month]!.mapValues { $0.sorted { $0.date! < $1.date! } })
        }
    }

    /// Reads every page before publishing, so the views never show a partial stream.
    func load() async {
        generation += 1
        let current = generation
        loading = true
        defer { if current == generation { loading = false } }
        do {
            var photos: [Photo] = []
            var cursor: String?
            repeat {
                let page = try await Moment.list(cursor: cursor)
                photos += page.photos
                cursor = page.nextCursor
            } while cursor != nil
            guard current == generation else { return }
            self.photos = photos
            problem = nil
        } catch {
            guard current == generation, let problem = LoadProblem(error) else { return }
            self.problem = problem
            if problem == .signedOut { photos = [] }
        }
    }

    func signedOut() {
        generation += 1
        photos = []
        problem = .signedOut
        loading = false
    }
}
