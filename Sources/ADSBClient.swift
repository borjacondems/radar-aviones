import Foundation

enum ADSBSource: String, CaseIterable {
    case lol, fi

    var name: String { self == .lol ? "adsb.lol" : "adsb.fi" }

    func url(lat: Double, lon: Double, nm: Int) -> URL {
        let la = String(format: "%.4f", lat), lo = String(format: "%.4f", lon)
        switch self {
        case .lol: return URL(string: "https://api.adsb.lol/v2/point/\(la)/\(lo)/\(nm)")!
        case .fi: return URL(string: "https://opendata.adsb.fi/api/v2/lat/\(la)/lon/\(lo)/dist/\(nm)")!
        }
    }
}

enum ADSBClient {
    /// planespotters.net exige un User-Agent con una URL o email de contacto.
    /// Con nil no se consultan sus fotos (se usarán solo las de adsbdb).
    static let planespottersContact: String? = "https://github.com/borjacondems/radar-aviones"

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.httpAdditionalHeaders = ["User-Agent": "RadarAviones/1.0 (macOS)"]
        return URLSession(configuration: config)
    }()

    private static func get<T: Decodable>(_ url: URL, as: T.Type, snakeCase: Bool = false, headers: [String: String] = [:]) async throws -> T {
        var request = URLRequest(url: url)
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        if snakeCase { decoder.keyDecodingStrategy = .convertFromSnakeCase }
        return try decoder.decode(T.self, from: data)
    }

    /// Aviones cerca de un punto. Prueba la fuente preferida y, si falla, la otra.
    static func nearby(lat: Double, lon: Double, nm: Int, preferred: ADSBSource = .lol) async throws -> (ADSBSource, [Aircraft]) {
        let order = [preferred] + ADSBSource.allCases.filter { $0 != preferred }
        var lastError: Error = URLError(.unknown)
        for source in order {
            do {
                let res = try await get(source.url(lat: lat, lon: lon, nm: nm), as: NearbyResponse.self)
                return (source, res.all)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private struct RouteEnvelope: Decodable {
        struct Inner: Decodable { let flightroute: FlightRoute }
        let response: Inner
    }

    private struct AircraftEnvelope: Decodable {
        struct Inner: Decodable { let aircraft: AircraftInfo }
        let response: Inner
    }

    static func route(callsign: String) async -> FlightRoute? {
        guard !callsign.isEmpty, let cs = callsign.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        let url = URL(string: "https://api.adsbdb.com/v0/callsign/\(cs)")!
        return try? await get(url, as: RouteEnvelope.self, snakeCase: true).response.flightroute
    }

    static func info(hex: String) async -> AircraftInfo? {
        let url = URL(string: "https://api.adsbdb.com/v0/aircraft/\(hex)")!
        return try? await get(url, as: AircraftEnvelope.self, snakeCase: true).response.aircraft
    }

    private struct PlanespottersResponse: Decodable {
        struct Item: Decodable {
            struct Thumb: Decodable { let src: String }
            let thumbnailLarge: Thumb?
            let photographer: String?
            let link: String?
        }
        let photos: [Item]
    }

    static func photo(hex: String, info: AircraftInfo?) async -> Photo? {
        if let contact = planespottersContact {
            let url = URL(string: "https://api.planespotters.net/pub/photos/hex/\(hex)")!
            let ua = ["User-Agent": "RadarAviones/1.0 (+\(contact))"]
            if let item = try? await get(url, as: PlanespottersResponse.self, snakeCase: true, headers: ua).photos.first,
               let src = item.thumbnailLarge?.src, let photoURL = URL(string: src) {
                return Photo(url: photoURL, photographer: item.photographer, link: item.link.flatMap(URL.init(string:)))
            }
        }
        if let s = info?.urlPhoto ?? info?.urlPhotoThumbnail, let url = URL(string: s) {
            return Photo(url: url, photographer: nil, link: nil)
        }
        return nil
    }
}
