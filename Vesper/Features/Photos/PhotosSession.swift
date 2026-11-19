import Consumers
import Foundation
import Observation

@Observable
final class PhotosSession {
    var tag: String?
    var notice: String?

    private(set) var photos: [Photo] = []
    private(set) var tags: [TagCount] = []
    private(set) var cursor: String?
    private(set) var loading = true
    private(set) var paginating = false
    private(set) var problem: LoadProblem?

    private var generation = 0

    func load() async {
        generation += 1
        let current = generation
        loading = true
        defer { if current == generation { loading = false } }
        do {
            let page = try await Photos.list(tag: tag)
            guard current == generation else { return }
            photos = page.photos
            cursor = page.nextCursor
            problem = nil
        } catch {
            guard current == generation, let problem = failed(error) else { return }
            self.problem = problem
        }
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
            let page = try await Photos.list(cursor: cursor, tag: tag)
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
            tags = try await Entries.tags()
        } catch {
            if case .failed? = failed(error) { notice = error.localizedDescription }
        }
    }
}
