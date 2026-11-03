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

struct AtlasMonth: Identifiable {
    let month: Date
    let days: [Date: [Photo]]

    var id: Date { month }
}

enum AtlasRoute: Hashable {
    case photos([Photo], start: Photo)
}

extension MapCamera {
    static let britain = MapCamera(latitude: 54.4, longitude: -3.2, zoom: 4.6)
}
