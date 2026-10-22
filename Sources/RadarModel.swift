import CoreLocation
import Foundation

enum Geo {
    static let rad = Double.pi / 180

    static func distanceKm(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dLat = (b.latitude - a.latitude) * rad, dLon = (b.longitude - a.longitude) * rad
        let h = pow(sin(dLat / 2), 2) + cos(a.latitude * rad) * cos(b.latitude * rad) * pow(sin(dLon / 2), 2)
        return 2 * 6371 * asin(sqrt(h))
    }

    static func bearing(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let y = sin((b.longitude - a.longitude) * rad) * cos(b.latitude * rad)
        let x = cos(a.latitude * rad) * sin(b.latitude * rad) - sin(a.latitude * rad) * cos(b.latitude * rad) * cos((b.longitude - a.longitude) * rad)
        return (atan2(y, x) / rad + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Ángulo sobre el horizonte, con corrección por curvatura terrestre.
    static func elevation(km: Double, altitudeM: Double) -> Double {
        let drop = pow(km * 1000, 2) / (2 * 6_371_000)
        return atan2(altitudeM - drop, km * 1000) / rad
    }

    static let compass = ["norte", "nornoreste", "noreste", "estenoreste", "este", "estesureste", "sureste", "sursureste",
                          "sur", "sursuroeste", "suroeste", "oestesuroeste", "oeste", "oestenoroeste", "noroeste", "nornoroeste"]
    static let compassShort = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO"]
    static func index(_ deg: Double) -> Int { Int((deg / 22.5).rounded()) % 16 }
}

@MainActor
final class RadarModel: ObservableObject {
    static let refreshSeconds: TimeInterval = 5
    static let searchNM = 40      // ≈ 74 km
    static let trailMax = 120     // puntos de estela por avión

    @Published private(set) var me: CLLocationCoordinate2D?
    /// Cambia cada vez que se fija un punto nuevo (CLLocationCoordinate2D no es Equatable).
    @Published private(set) var pointID = 0
    @Published private(set) var closest: Contact?
    @Published private(set) var others: [Contact] = []
    @Published private(set) var trail: [CLLocationCoordinate2D] = []
    @Published private(set) var route: Lookup<FlightRoute> = .loading
    @Published private(set) var info: Lookup<AircraftInfo> = .loading
    @Published private(set) var photo: Lookup<Photo> = .loading
    @Published private(set) var status = "Buscando tu ubicación…"
    @Published private(set) var stale = false
    @Published private(set) var needsPoint = false
    @Published var useFilter: FlightUse? {
        didSet {
            UserDefaults.standard.set(useFilter?.rawValue, forKey: "useFilter")
            Task { await refresh() }
        }
    }

    private var timer: Timer?
    private var trails: [String: [CLLocationCoordinate2D]] = [:]
    private var routeCache: [String: FlightRoute?] = [:]
    private var infoCache: [String: AircraftInfo?] = [:]
    private var photoCache: [String: Photo?] = [:]

    init() {
        useFilter = UserDefaults.standard.string(forKey: "useFilter").flatMap(FlightUse.init(rawValue:))
    }

    func setPoint(_ c: CLLocationCoordinate2D) {
        me = c
        needsPoint = false
        pointID += 1
        UserDefaults.standard.set([c.latitude, c.longitude], forKey: "lastPoint")
        closest = nil
        timer?.invalidate()
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    /// Sin geolocalización: usamos el último punto guardado o pedimos uno en el mapa.
    func locationFailed(_ reason: String) {
        if me != nil { return }
        if let saved = UserDefaults.standard.array(forKey: "lastPoint") as? [Double], saved.count == 2 {
            setPoint(CLLocationCoordinate2D(latitude: saved[0], longitude: saved[1]))
            return
        }
        needsPoint = true
        status = "Sin ubicación (\(reason))"
    }

    func refresh() async {
        guard let me else { return }
        do {
            let (_, list) = try await ADSBClient.nearby(lat: me.latitude, lon: me.longitude, nm: Self.searchNM)
            let contacts = list
                .compactMap { a -> Contact? in
                    guard let lat = a.lat, let lon = a.lon, a.altBaro != nil else { return nil }
                    let c = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    return Contact(aircraft: a, coordinate: c, km: Geo.distanceKm(me, c))
                }
                // Si ya consultamos sus datos en adsbdb, el propietario ayuda a detectar aviones policiales.
                .filter { useFilter == nil || Classifier.use($0.aircraft, info: infoCache[$0.id] ?? nil) == useFilter }
                .sorted { $0.km < $1.km }

            for c in contacts {
                var t = trails[c.id] ?? []
                if let last = t.last, last.latitude == c.coordinate.latitude, last.longitude == c.coordinate.longitude {} else {
                    t.append(c.coordinate)
                }
                trails[c.id] = Array(t.suffix(Self.trailMax))
            }

            let first = contacts.first
            let changed = first?.id != closest?.id
            closest = first
            others = Array(contacts.dropFirst())
            trail = first.flatMap { trails[$0.id] } ?? []
            stale = false

            let n = contacts.count
            let kind = useFilter.map { " " + (n == 1 ? $0.singular : $0.plural) } ?? ""
            let time = Date().formatted(date: .omitted, time: .standard)
            status = "\(n) \(n == 1 ? "avión" : "aviones")\(kind) en \(Int((Double(Self.searchNM) * 1.852).rounded())) km · \(time)"

            if changed, let first { Task { await lookups(for: first.aircraft) } }
        } catch {
            stale = true
            status = "Error al obtener datos: \(error.localizedDescription)"
        }
    }

    private func lookups(for a: Aircraft) async {
        route = .loading
        info = .loading
        photo = .loading
        async let r = cachedRoute(a.callsign)
        async let i = cachedInfo(a.hex)
        let (routeResult, infoResult) = await (r, i)
        guard closest?.id == a.hex else { return } // cambió el más cercano mientras cargaba
        route = .loaded(routeResult)
        info = .loaded(infoResult)
        let p = await cachedPhoto(a.hex, info: infoResult)
        guard closest?.id == a.hex else { return }
        photo = .loaded(p)
    }

    private func cachedRoute(_ cs: String) async -> FlightRoute? {
        if let hit = routeCache[cs] { return hit }
        let r = await ADSBClient.route(callsign: cs)
        routeCache[cs] = r
        return r
    }

    private func cachedInfo(_ hex: String) async -> AircraftInfo? {
        if let hit = infoCache[hex] { return hit }
        let r = await ADSBClient.info(hex: hex)
        infoCache[hex] = r
        return r
    }

    private func cachedPhoto(_ hex: String, info: AircraftInfo?) async -> Photo? {
        if let hit = photoCache[hex] { return hit }
        let r = await ADSBClient.photo(hex: hex, info: info)
        photoCache[hex] = r
        return r
    }
}
