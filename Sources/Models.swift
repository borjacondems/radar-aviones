import CoreLocation
import Foundation

// MARK: - ADS-B (adsb.lol / adsb.fi, formato readsb)

struct Aircraft: Decodable, Hashable {
    let hex: String
    let flight: String?
    let registration: String?
    let type: String?
    let desc: String?
    let category: String?
    /// Altitud barométrica en pies; nil si no la emite o está en tierra.
    let altBaro: Double?
    let onGround: Bool
    let groundSpeed: Double?
    let track: Double?
    let trueHeading: Double?
    let baroRate: Double?
    let geomRate: Double?
    let squawk: String?
    let lat: Double?
    let lon: Double?
    let dbFlags: Int?

    var callsign: String { (flight ?? "").trimmingCharacters(in: .whitespaces) }
    var heading: Double? { track ?? trueHeading }
    var verticalRate: Double? { baroRate ?? geomRate }
    var isMilitary: Bool { (dbFlags ?? 0) & 1 == 1 }

    enum CodingKeys: String, CodingKey {
        case hex, flight, registration = "r", type = "t", desc, category, altBaro = "alt_baro", groundSpeed = "gs"
        case track, trueHeading = "true_heading", baroRate = "baro_rate", geomRate = "geom_rate", squawk, lat, lon, dbFlags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hex = try c.decode(String.self, forKey: .hex)
        flight = try? c.decodeIfPresent(String.self, forKey: .flight)
        registration = try? c.decodeIfPresent(String.self, forKey: .registration)
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        desc = try? c.decodeIfPresent(String.self, forKey: .desc)
        category = try? c.decodeIfPresent(String.self, forKey: .category)
        // alt_baro es un número o la cadena "ground".
        if let alt = try? c.decodeIfPresent(Double.self, forKey: .altBaro) {
            altBaro = alt
            onGround = false
        } else {
            altBaro = nil
            onGround = (try? c.decodeIfPresent(String.self, forKey: .altBaro)) == "ground"
        }
        groundSpeed = try? c.decodeIfPresent(Double.self, forKey: .groundSpeed)
        track = try? c.decodeIfPresent(Double.self, forKey: .track)
        trueHeading = try? c.decodeIfPresent(Double.self, forKey: .trueHeading)
        baroRate = try? c.decodeIfPresent(Double.self, forKey: .baroRate)
        geomRate = try? c.decodeIfPresent(Double.self, forKey: .geomRate)
        squawk = try? c.decodeIfPresent(String.self, forKey: .squawk)
        lat = try? c.decodeIfPresent(Double.self, forKey: .lat)
        lon = try? c.decodeIfPresent(Double.self, forKey: .lon)
        dbFlags = try? c.decodeIfPresent(Int.self, forKey: .dbFlags)
    }
}

/// adsb.lol devuelve "ac" y adsb.fi devuelve "aircraft".
struct NearbyResponse: Decodable {
    let ac: [Aircraft]?
    let aircraft: [Aircraft]?
    var all: [Aircraft] { ac ?? aircraft ?? [] }
}

/// Un avión con posición, ya situado respecto a ti.
struct Contact: Identifiable, Equatable {
    let aircraft: Aircraft
    let coordinate: CLLocationCoordinate2D
    let km: Double
    var id: String { aircraft.hex }

    static func == (l: Contact, r: Contact) -> Bool { l.aircraft == r.aircraft }
}

// MARK: - adsbdb (rutas y datos de la aeronave)

struct FlightRoute: Decodable {
    struct Airline: Decodable { let name: String }
    struct Airport: Decodable {
        let iataCode: String?
        let icaoCode: String?
        let municipality: String?
        let latitude: Double
        let longitude: Double
        var code: String { iataCode ?? icaoCode ?? "?" }
        var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    }

    let callsignIata: String?
    let airline: Airline?
    let origin: Airport
    let destination: Airport
}

struct AircraftInfo: Decodable {
    let type: String?
    let icaoType: String?
    let manufacturer: String?
    let registration: String?
    let registeredOwner: String?
    let urlPhoto: String?
    let urlPhotoThumbnail: String?
}

struct Photo {
    let url: URL
    let photographer: String?
    let link: URL?
    /// Foto genérica del modelo (Wikipedia), no de este avión concreto.
    var modelArticle: String? = nil
}

/// Estado de una consulta secundaria (ruta, datos, foto) del avión mostrado.
enum Lookup<T> {
    case loading
    case loaded(T?)

    var value: T? { if case .loaded(let v) = self { return v } else { return nil } }
    var isLoading: Bool { if case .loading = self { return true } else { return false } }
}
