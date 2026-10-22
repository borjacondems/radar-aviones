import AppKit
import MapKit
import SwiftUI

struct ContentView: View {
    @StateObject private var model = RadarModel()
    @State private var location = LocationProvider()
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038),
        span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)))
    @State private var follow = true
    @State private var showOthers = false

    var body: some View {
        HStack(spacing: 0) {
            map
            Divider()
            InfoPanel(model: model, onRetry: { location.request() })
                .frame(width: 380)
        }
        .toolbar {
            ToolbarItemGroup {
                Picker("Tipo", selection: $model.useFilter) {
                    Text("Todos").tag(FlightUse?.none)
                    ForEach(FlightUse.allCases) { Text($0.label).tag(Optional($0)) }
                }
                .pickerStyle(.segmented)
                .help("Mostrar el más cercano de este tipo")

                Toggle(isOn: $showOthers) { Label("Ver el resto", systemImage: "airplane.circle") }
                    .help("Mostrar también los demás aviones en el mapa")

                Button { location.request() } label: { Label("Mi ubicación", systemImage: "location") }
                    .help("Usar mi ubicación actual")
            }
        }
        .onAppear {
            location.onLocation = { model.setPoint($0) }
            location.onFailure = { model.locationFailed($0) }
            location.request()
        }
        .onChange(of: model.pointID) { _, _ in
            follow = true
            recenter()
        }
        .onChange(of: model.closest) { _, _ in recenter() }
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $camera, interactionModes: [.pan, .zoom]) {
                if let me = model.me {
                    Annotation("Tú", coordinate: me, anchor: .center) {
                        Circle().fill(Color(hex: 0x1d4ed8))
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(radius: 2)
                    }
                    .annotationTitles(.hidden)
                }

                if let r = model.route.value {
                    MapPolyline(coordinates: [r.origin.coordinate, r.destination.coordinate], contourStyle: .geodesic)
                        .stroke(Color(hex: 0x1d4ed8).opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                    ForEach([r.origin, r.destination], id: \.code) { apt in
                        Annotation(apt.code, coordinate: apt.coordinate, anchor: .center) {
                            AirportPin(code: apt.code)
                        }
                        .annotationTitles(.hidden)
                    }
                }

                if showOthers {
                    ForEach(model.others) { c in
                        Annotation(c.aircraft.callsign, coordinate: c.coordinate, anchor: .center) {
                            AircraftIcon(kind: Classifier.kind(c.aircraft), heading: c.aircraft.heading ?? 0)
                                .opacity(0.55)
                        }
                        .annotationTitles(.hidden)
                    }
                }

                if let c = model.closest, let me = model.me {
                    MapPolyline(coordinates: [me, c.coordinate])
                        .stroke(Color(hex: 0x111111).opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [2, 5]))
                    if model.trail.count > 1 {
                        MapPolyline(coordinates: model.trail).stroke(Color(hex: 0xf59e0b), lineWidth: 3)
                    }
                    Annotation(c.aircraft.callsign, coordinate: c.coordinate, anchor: .center) {
                        let kind = Classifier.kind(c.aircraft, info: model.info.value)
                        AircraftIcon(kind: kind, heading: c.aircraft.heading ?? 0, size: kind.size * 1.25)
                            .animation(.easeInOut(duration: 0.6), value: c.aircraft.heading)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapZoomStepper()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { _ in
                if camera.positionedByUser { follow = false }
            }
            // ⌥-clic (o clic, si aún no hay ubicación) fija el punto de observación.
            .onTapGesture { point in
                guard model.me == nil || NSEvent.modifierFlags.contains(.option),
                      let c = proxy.convert(point, from: .local) else { return }
                model.setPoint(c)
            }
            .overlay(alignment: .topLeading) {
                if !follow {
                    Button {
                        follow = true
                        recenter()
                    } label: { Label("Volver a seguir", systemImage: "scope") }
                        .buttonStyle(.borderedProminent)
                        .padding(12)
                }
            }
        }
    }

    /// Encuadra tu posición y el avión más cercano, salvo que hayas movido el mapa a mano.
    private func recenter() {
        guard follow, let me = model.me else { return }
        let region: MKCoordinateRegion
        if let c = model.closest?.coordinate {
            let center = CLLocationCoordinate2D(latitude: (me.latitude + c.latitude) / 2, longitude: (me.longitude + c.longitude) / 2)
            region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(
                latitudeDelta: max(abs(me.latitude - c.latitude) * 1.8, 0.04),
                longitudeDelta: max(abs(me.longitude - c.longitude) * 1.8, 0.04)))
        } else {
            region = MKCoordinateRegion(center: me, latitudinalMeters: 40_000, longitudinalMeters: 40_000)
        }
        withAnimation(.easeInOut(duration: 0.8)) { camera = .region(region) }
    }
}

struct AirportPin: View {
    let code: String

    var body: some View {
        VStack(spacing: 2) {
            Text(code)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(.background))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
            Circle().fill(.white)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color(hex: 0x1d4ed8), lineWidth: 2))
        }
        .offset(y: -9)
    }
}
