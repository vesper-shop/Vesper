#if os(iOS)
import MapLibre
import os
import SwiftUI
import UIKit

/// While `tracking`, the map shows the user's position, centres on it once it is known and reports
/// it through `located`; turned off, it flies back to `camera`. Location access is asked for the
/// first time tracking turns on.
public struct TileMap: UIViewRepresentable {
    let pins: [MapPin]
    let camera: MapCamera
    let tracking: Bool
    let select: (MapPin.ID) -> Void
    let located: (MapCoordinate) -> Void
    @Environment(\.colorScheme) private var scheme

    public init(
        pins: [MapPin],
        camera: MapCamera,
        tracking: Bool,
        select: @escaping (MapPin.ID) -> Void,
        located: @escaping (MapCoordinate) -> Void
    ) {
        self.pins = pins
        self.camera = camera
        self.tracking = tracking
        self.select = select
        self.located = located
    }

    public func makeCoordinator() -> TileMapCoordinator {
        TileMapCoordinator(select: select, located: located)
    }

    public func makeUIView(context: Context) -> MLNMapView {
        let view = MLNMapView(frame: .zero, styleURL: style)
        view.delegate = context.coordinator
        view.logoView.isHidden = true
        view.attributionButtonPosition = .bottomLeft
        view.tintColor = UIColor(Theme.accent)
        view.setCenter(CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude), zoomLevel: camera.zoom, animated: false)
        return view
    }

    public func updateUIView(_ view: MLNMapView, context: Context) {
        context.coordinator.select = select
        context.coordinator.located = located
        if view.showsUserLocation != tracking {
            view.showsUserLocation = tracking
            context.coordinator.pending = tracking
            if !tracking {
                view.setCenter(CLLocationCoordinate2D(latitude: camera.latitude, longitude: camera.longitude), zoomLevel: camera.zoom, animated: true)
            } else if let location = view.userLocation?.location {
                context.coordinator.center(view, on: location.coordinate)
            }
        }
        if view.styleURL != style {
            view.styleURL = style
        }
        let shown = (view.annotations ?? []).compactMap { $0 as? PinAnnotation }
        let wanted = Set(pins.map(\.id))
        let present = Set(shown.map(\.pin.id))
        view.removeAnnotations(shown.filter { !wanted.contains($0.pin.id) })
        view.addAnnotations(pins.filter { !present.contains($0.id) }.map(PinAnnotation.init))
    }

    private var style: URL {
        URL(string: "https://tiles.openfreemap.org/styles/\(scheme == .dark ? "dark" : "positron")")!
    }
}

@MainActor
public final class TileMapCoordinator: NSObject, @preconcurrency MLNMapViewDelegate {
    var select: (MapPin.ID) -> Void
    var located: (MapCoordinate) -> Void
    var pending = false

    init(select: @escaping (MapPin.ID) -> Void, located: @escaping (MapCoordinate) -> Void) {
        self.select = select
        self.located = located
    }

    func center(_ mapView: MLNMapView, on coordinate: CLLocationCoordinate2D) {
        pending = false
        mapView.setCenter(coordinate, zoomLevel: max(mapView.zoomLevel, 13), animated: true)
        located(MapCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    public func mapView(_ mapView: MLNMapView, didUpdate userLocation: MLNUserLocation?) {
        guard pending, let location = userLocation?.location else { return }
        center(mapView, on: location.coordinate)
    }

    public func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
        guard let annotation = annotation as? PinAnnotation else { return nil }
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: PinView.reuse) as? PinView ?? PinView(reuseIdentifier: PinView.reuse)
        view.show(annotation.pin)
        return view
    }

    public func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
        guard let annotation = annotation as? PinAnnotation else { return }
        mapView.deselectAnnotation(annotation, animated: false)
        select(annotation.pin.id)
    }

    /// The tiles' own paper becomes Vesper's, so the map sits on the page rather than in a hole.
    public func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        let paper = UIColor(Theme.background).resolvedColor(with: mapView.traitCollection)
        (style.layer(withIdentifier: "background") as! MLNBackgroundStyleLayer).backgroundColor = NSExpression(forConstantValue: paper)
    }
}

@MainActor
final class PinAnnotation: NSObject, @preconcurrency MLNAnnotation {
    let pin: MapPin

    init(_ pin: MapPin) {
        self.pin = pin
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
    }
}

final class PinView: MLNAnnotationView {
    static let reuse = "pin"
    private static let log = Logger(subsystem: "me.youfind.vesper", category: "map")
    private let image = UIImageView()
    private var loading: Task<Void, Never>?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        centerOffset = CGVector(dx: 0, dy: -22)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
        image.frame = bounds
        image.contentMode = .scaleAspectFill
        image.clipsToBounds = true
        image.layer.cornerRadius = Theme.Radius.md
        image.layer.borderWidth = 2
        image.layer.borderColor = UIColor.white.cgColor
        image.backgroundColor = UIColor(Theme.muted)
        addSubview(image)
    }

    required init?(coder: NSCoder) {
        fatalError("PinView is created in code")
    }

    func show(_ pin: MapPin) {
        loading?.cancel()
        image.image = nil
        loading = Task { [image] in
            do {
                let (data, _) = try await URLSession.shared.data(from: pin.image)
                try Task.checkCancellation()
                image.image = UIImage(data: data)
            } catch is CancellationError {
            } catch {
                Self.log.error("Pin thumbnail \(pin.id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
#endif
