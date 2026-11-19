import CoreGraphics
import Foundation
import WidgetKit

enum WidgetProblem {
    case signedOut
    case failed
}

protocol DailyEntry: TimelineEntry, Sendable {
    var problem: WidgetProblem? { get }
}

protocol DailyProvider: TimelineProvider, Sendable where Entry: DailyEntry {
    func fetch() async throws -> Entry
    func failed(_ problem: WidgetProblem) -> Entry
}

struct Memory: Identifiable {
    let id: String
    let title: String
    let years: Int
    let image: CGImage
}

struct OnThisDayEntry: DailyEntry {
    let date: Date
    let memories: [Memory]
    let problem: WidgetProblem?
}

struct HeatmapEntry: DailyEntry {
    let date: Date
    /// Photos per day, keyed by the start of the day.
    let days: [Date: Int]
    let problem: WidgetProblem?
}
