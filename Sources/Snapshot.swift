import AppKit
import CoreLocation
import SwiftUI

/// Modo de prueba sin ventana: carga datos reales para un punto y guarda el panel como PNG.
enum Snapshot {
    @MainActor static func run(to path: String, lat: Double, lon: Double) {
        let model = RadarModel()
        model.setPoint(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        // Espera a que lleguen el avión, la ruta, los datos y la foto.
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.25))
            if model.closest != nil, !model.photo.isLoading { break }
        }
        print(model.status)
        if let c = model.closest {
            print("closest:", c.aircraft.callsign, c.aircraft.type ?? "-", String(format: "%.1f km", c.km),
                  Classifier.kind(c.aircraft, info: model.info.value).rawValue,
                  Classifier.use(c.aircraft, info: model.info.value, hasAirline: model.route.value?.airline != nil).rawValue)
            print("route:", model.route.value.map { "\($0.origin.code)→\($0.destination.code)" } ?? "none",
                  "photo:", model.photo.value?.url.absoluteString ?? "none")
        }
        // Las fotos de AsyncImage no se dibujan en ImageRenderer; el panel sí.
        let view = InfoPanel(model: model, onRetry: {}, scrolls: false).frame(width: 380, height: 900)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let tiff = renderer.nsImage?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }
}
