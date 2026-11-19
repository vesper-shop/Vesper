import Consumers
import Foundation
import Observation

@Observable
final class TimelineSession {
    var filters = EntryFilters()
    var pinnedOpen = false
    var notice: String?

    private(set) var items: [EntryItem] = []
    private(set) var tags: [TagCount] = []
    private(set) var cursor: String?
    private(set) var loading = true
    private(set) var paginating = false
    private(set) var problem: LoadProblem?
    private(set) var busy: Set<Entry.ID> = []

    /// Responses from superseded requests are dropped.
    private var generation = 0

    var sections: (pinned: [EntryItem], timeline: [EntryItem]) {
        guard !filters.active else { return ([], items) }
        let sorted = items.sorted { $0.entry.occurred > $1.entry.occurred }
        return (sorted.filter(\.entry.pinned), sorted.filter { !$0.entry.pinned })
    }

    func load() async {
        generation += 1
        let current = generation
        loading = true
        defer { if current == generation { loading = false } }
        do {
            let page = try await Entries.list(filters: filters)
            let items = try page.entries.map(EntryItem.init)
            guard current == generation else { return }
            self.items = items
            cursor = page.nextCursor
            problem = nil
        } catch {
            guard current == generation, let problem = failed(error) else { return }
            self.problem = problem
        }
    }

    private func clear() {
        items = []
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
            let page = try await Entries.list(cursor: cursor, filters: filters)
            let known = Set(items.map(\.id))
            let next = try page.entries.filter { !known.contains($0.id) }.map(EntryItem.init)
            guard current == generation else { return }
            items += next
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

    /// `content` nil keeps the text, so an entry of photos alone can still change visibility.
    func edit(_ entry: Entry, content: String?, visibility: Entry.Visibility) async throws {
        try apply(await Entries.update(entry.id, EntryUpdate(content: content, visibility: visibility)))
        await syncTags()
    }

    /// Returns the entry as the server now has it, or nil after reporting a failure.
    @discardableResult
    func toggle(_ flag: EntryFlag, of entry: Entry) async -> Entry? {
        let update = switch flag {
        case .pinned: EntryUpdate(pinned: !entry.pinned)
        case .favorite: EntryUpdate(favorite: !entry.favorite)
        case .archived: EntryUpdate(archived: !entry.archived)
        }
        busy.insert(entry.id)
        defer { busy.remove(entry.id) }
        do {
            let updated = try await Entries.update(entry.id, update)
            try apply(updated)
            return updated
        } catch {
            notice = error.localizedDescription
            return nil
        }
    }

    func delete(_ entry: Entry) async {
        busy.insert(entry.id)
        defer { busy.remove(entry.id) }
        do {
            try await Entries.delete(entry.id)
            items.removeAll { $0.id == entry.id }
            await syncTags()
        } catch {
            notice = error.localizedDescription
        }
    }

    private func apply(_ entry: Entry) throws {
        guard let index = items.firstIndex(where: { $0.id == entry.id }) else { return }
        if filters.display.contains(entry) {
            items[index] = try EntryItem(entry)
        } else {
            items.remove(at: index)
        }
    }
}
