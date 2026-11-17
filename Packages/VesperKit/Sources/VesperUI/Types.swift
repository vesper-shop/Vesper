import Foundation

public struct TagChip: Hashable, Sendable {
    public let name: String
    public let count: Int

    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

/// Equal by id, since the image loader cannot be compared.
public struct MapPin: Identifiable, Hashable, Sendable {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public let image: @Sendable () async throws -> Data

    public init(id: String, latitude: Double, longitude: Double, image: @escaping @Sendable () async throws -> Data) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.image = image
    }

    public static func == (left: MapPin, right: MapPin) -> Bool { left.id == right.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Where a map opens: a center and a web-map zoom level (0 is the whole world).
public struct MapCamera: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let zoom: Double

    public init(latitude: Double, longitude: Double, zoom: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.zoom = zoom
    }
}

public struct MapCoordinate: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct ToastMessage: Identifiable, Equatable {
    public let id = UUID()
    public let text: String
    public let action: ToastAction?

    public init(_ text: String, action: ToastAction? = nil) {
        self.text = text
        self.action = action
    }

    public static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

public struct ToastAction {
    public let title: String
    public let perform: @MainActor () -> Void

    public init(_ title: String, perform: @escaping @MainActor () -> Void) {
        self.title = title
        self.perform = perform
    }
}

struct ScrollSpan: Equatable {
    var offset: CGFloat = 0
    var visible: CGFloat = 0
    var total: CGFloat = 0
}
