import Identity
import os
import WidgetKit

private let log = Logger(subsystem: "me.youfind.vesper", category: "widgets")

extension DailyProvider {
    func getSnapshot(in context: Context, completion: @escaping @Sendable (Entry) -> Void) {
        Task { completion(await load()) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<Entry>) -> Void) {
        Task {
            let entry = await load()
            let next = entry.problem == .failed
                ? Date.now.addingTimeInterval(30 * 60)
                : Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func load() async -> Entry {
        do {
            return try await fetch()
        } catch IdentityError.signedOut {
            return failed(.signedOut)
        } catch {
            log.error("\(String(describing: Self.self), privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return failed(.failed)
        }
    }
}
