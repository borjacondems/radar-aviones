import CoreLocation

/// Envuelve CLLocationManager: pide permiso y entrega una única posición.
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    var onLocation: ((CLLocationCoordinate2D) -> Void)?
    var onFailure: ((String) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            onFailure?("permiso de ubicación denegado; actívalo en Ajustes del Sistema › Privacidad")
        default:
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined: break
        case .denied, .restricted: onFailure?("permiso de ubicación denegado")
        default: manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        DispatchQueue.main.async { self.onLocation?(c) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { self.onFailure?(error.localizedDescription) }
    }
}
