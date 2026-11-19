import Consumers
import Foundation
import VesperUI

/// The map is iOS-only: MapLibre ships no macOS binary.
/// The first case is the default.
enum AtlasMode: String, CaseIterable, Identifiable {
    #if os(iOS)
    case map
    #endif
    case calendar

    var id: Self { self }

    var title: String {
        switch self {
        #if os(iOS)
        case .map: "Map"
        #endif
        case .calendar: "Calendar"
        }
    }

    var symbol: String {
        switch self {
        #if os(iOS)
        case .map: "map"
        #endif
        case .calendar: "calendar"
        }
    }
}

/// `days` are each day's photos; `entries` count every entry a day has, with photos or not.
struct AtlasMonth: Identifiable {
    let month: Date
    let days: [Date: [Photo]]
    let entries: [Date: Int]

    var id: Date { month }
}

enum AtlasRoute: Hashable {
    case day(Date)
}

extension MapCamera {
    static let britain = MapCamera(latitude: 54.4, longitude: -3.2, zoom: 4.6)
}
