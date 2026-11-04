import Consumers
import Foundation
import Observation

@Observable
final class MemosSession {
    var filters = MemoFilters()
    var pinnedOpen = false
    var notice: String?

    private(set) var items: [MemoItem] = []
    private(set) var tags: [TagCount] = []
    private(set) var cursor: String?
    private(set) var loading = true
    private(set) var paginating = false
    private(set) var problem: LoadProblem?
    private(set) var busy: Set<Memo.ID> = []

    /// Responses from superseded requests are dropped.
    private var generation = 0

    var sections: (pinned: [MemoItem], timeline: [MemoItem]) {
        guard !filters.active else { return ([], items) }
        let sorted = items.sorted { $0.memo.createdAt > $1.memo.createdAt }
        return (sorted.filter(\.memo.pinned), sorted.filter { !$0.memo.pinned })
    }

    func load() async {
        generation += 1
        let current = generation
        loading = true
        defer { if current == generation { loading = false } }
        do {
            let page = try await Memos.list(filters: filters)
            let items = try page.memos.map(MemoItem.init)
            guard current == generation else { return }
            self.items = items
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
            let page = try await Memos.list(cursor: cursor, filters: filters)
            let known = Set(items.map(\.id))
            let next = try page.memos.filter { !known.contains($0.id) }.map(MemoItem.init)
            guard current == generation else { return }
            items += next
            self.cursor = page.nextCursor
        } catch {
            if case .failed? = failed(error) { notice = error.localizedDescription }
        }
    }

    func syncTags() async {
        do {
            tags = try await Memos.tags()
        } catch {
            if case .failed? = failed(error) { notice = error.localizedDescription }
        }
    }

    func create(content: String, visibility: Memo.Visibility) async throws {
        _ = try await Memos.create(content: content, visibility: visibility)
        await load()
        await syncTags()
    }

    func edit(_ memo: Memo, content: String, visibility: Memo.Visibility) async throws {
        try apply(await Memos.update(memo.id, MemoUpdate(content: content, visibility: visibility)))
        await syncTags()
    }

    /// Returns the memo as the server now has it, or nil after reporting a failure.
    @discardableResult
    func toggle(_ flag: MemoFlag, of memo: Memo) async -> Memo? {
        let update = switch flag {
        case .pinned: MemoUpdate(pinned: !memo.pinned)
        case .favorite: MemoUpdate(favorite: !memo.favorite)
        case .archived: MemoUpdate(archived: !memo.archived)
        }
        busy.insert(memo.id)
        defer { busy.remove(memo.id) }
        do {
            let updated = try await Memos.update(memo.id, update)
            try apply(updated)
            return updated
        } catch {
            notice = error.localizedDescription
            return nil
        }
    }

    func delete(_ memo: Memo) async {
        busy.insert(memo.id)
        defer { busy.remove(memo.id) }
        do {
            try await Memos.delete(memo.id)
            items.removeAll { $0.id == memo.id }
            await syncTags()
        } catch {
            notice = error.localizedDescription
        }
    }

    private func apply(_ memo: Memo) throws {
        guard let index = items.firstIndex(where: { $0.id == memo.id }) else { return }
        if filters.display.contains(memo) {
            items[index] = try MemoItem(memo)
        } else {
            items.remove(at: index)
        }
    }
}
