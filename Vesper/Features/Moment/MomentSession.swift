import Consumers
import CoreLocation
import Foundation
import MapKit
import Observation
import os

@Observable
final class MomentSession {
    var tag: String?
    var notice: String?

    private(set) var photos: [Photo] = []
    private(set) var tags: [TagCount] = []
    private(set) var places: [PlaceKey: String] = [:]
    private(set) var cursor: String?
    private(set) var loading = true
    private(set) var paginating = false
    private(set) var problem: LoadProblem?

    private var generation = 0
    private var locating: Set<PlaceKey> = []
    private let log = Logger(subsystem: "me.youfind.vesper", category: "moment")

    /// Photos grouped by capture day, newest day first and each day read in order, as the
    /// timeline reads them. Undated photos come last, in the order the API returned them.
    var days: [MomentDay] {
        let calendar = Calendar.current
        var dated: [Date: [(date: Date, photo: Photo)]] = [:]
        var undated: [Photo] = []
        for photo in photos {
            if let date = photo.date {
                dated[calendar.startOfDay(for: date), default: []].append((date, photo))
            } else {
                undated.append(photo)
            }
        }
        let days = dated.keys.sorted(by: >).map { day in
            MomentDay(day: day, photos: dated[day]!.sorted { $0.date < $1.date }.map(\.photo))
        }
        return undated.isEmpty ? days : days + [MomentDay(day: nil, photos: undated)]
    }

    func load() async {
        generation += 1
        let current = generation
        loading = true
        defer { if current == generation { loading = false } }
        do {
            let page = try await Moment.list(tag: tag)
            guard current == generation else { return }
            photos = page.photos
            cursor = page.nextCursor
            problem = nil
        } catch {
            guard current == generation, let problem = failed(error) else { return }
            self.problem = problem
        }
    }

    func signedOut() {
        generation += 1
        clear()
        problem = .signedOut
        loading = false
    }

    private func clear() {
        photos = []
        tags = []
        cursor = nil
    }

    private func failed(_ error: any Error) -> LoadProblem? {
        guard let problem = LoadProblem(error) else { return nil }
        if problem == .signedOut { clear() }
        return problem
    }

    func paginate() async {
        guard let cursor, !loading, !paginating else { return }
        let current = generation
        paginating = true
        defer { paginating = false }
        do {
            let page = try await Moment.list(cursor: cursor, tag: tag)
            guard current == generation else { return }
            let known = Set(photos.map(\.id))
            photos += page.photos.filter { !known.contains($0.id) }
            self.cursor = page.nextCursor
        } catch {
            if case .failed? = failed(error) { notice = error.localizedDescription }
        }
    }

    func syncTags() async {
        do {
            tags = try await Moment.tags()
        } catch {
            if case .failed? = failed(error) { notice = error.localizedDescription }
        }
    }

    func publish(_ source: Data, input: PhotoInput) async throws {
        _ = try await Moment.upload(source, input: input)
    }

    /// Names the city a photo was taken in. Each ~100 m cell is looked up once; a failed lookup
    /// is logged and leaves the photo without a place rather than retrying against MapKit's limits.
    func locate(_ photo: Photo) async {
        guard let geo = photo.geo else { return }
        let key = PlaceKey(geo)
        guard places[key] == nil, locating.insert(key).inserted else { return }
        do {
            let request = MKReverseGeocodingRequest(location: CLLocation(latitude: geo.lat, longitude: geo.lng))!
            let items = try await request.mapItems
            if let city = items.first?.addressRepresentations?.cityName {
                places[key] = city
            }
        } catch {
            log.error("Reverse geocoding \(photo.id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
