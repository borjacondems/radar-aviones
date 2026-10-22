import CoreLocation
import SwiftUI

private let es = Locale(identifier: "es_ES")
private func num(_ v: Double) -> String { Int(v.rounded()).formatted(.number.locale(es)) }

struct InfoPanel: View {
    @ObservedObject var model: RadarModel
    var onRetry: () -> Void
    /// ImageRenderer no dibuja ScrollView; el modo --snapshot lo desactiva.
    var scrolls = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(model.stale ? Color.orange : Color.green).frame(width: 8, height: 8)
                Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            Divider()
            if scrolls {
                ScrollView { content.padding(20) }
            } else {
                content.padding(20)
                Spacer(minLength: 0)
            }
        }
        .background(.background)
    }

    @ViewBuilder private var content: some View {
        if model.needsPoint {
            VStack(alignment: .leading, spacing: 12) {
                Text("No he podido obtener tu ubicación. Haz clic en el mapa para elegir un punto.")
                    .foregroundStyle(.secondary)
                Button("Reintentar", action: onRetry)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if model.me == nil {
            Text("Esperando ubicación…").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        } else if let c = model.closest, let me = model.me {
            Card(contact: c, me: me, route: model.route, info: model.info, photo: model.photo)
        } else {
            let kind = model.useFilter.map { " \($0.singular)" } ?? ""
            Text("Ningún avión\(kind) en vuelo cerca ahora mismo. Seguiré mirando…")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct Card: View {
    let contact: Contact
    let me: CLLocationCoordinate2D
    let route: Lookup<FlightRoute>
    let info: Lookup<AircraftInfo>
    let photo: Lookup<Photo>

    private var a: Aircraft { contact.aircraft }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            routeView
            LookDirection(contact: contact, me: me)
            stats
            aircraftSection
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Eyebrow("El avión más cercano")
                UseBadge(use: Classifier.use(a, info: info.value, hasAirline: route.value?.airline != nil))
            }
            HStack(alignment: .firstTextBaseline) {
                Text(route.value?.callsignIata ?? (a.callsign.isEmpty ? a.hex.uppercased() : a.callsign))
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                VStack(alignment: .trailing) {
                    if let airline = route.value?.airline?.name { Text(airline) }
                    if route.value?.callsignIata != nil { Text(a.callsign).foregroundStyle(.secondary) }
                }
                .font(.callout)
                .multilineTextAlignment(.trailing)
            }
        }
    }

    @ViewBuilder private var routeView: some View {
        VStack(spacing: 0) {
            Divider()
            Group {
                if let r = route.value {
                    HStack {
                        airport(r.origin, alignment: .leading)
                        Spacer()
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        Spacer()
                        airport(r.destination, alignment: .trailing)
                    }
                } else {
                    Text(route.isLoading ? "Buscando ruta…" : "Ruta desconocida")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 14)
            Divider()
        }
    }

    private func airport(_ apt: FlightRoute.Airport, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(apt.code).font(.system(size: 28, weight: .bold))
            Text(apt.municipality ?? "").font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        }
        .frame(maxWidth: 130, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var stats: some View {
        let altM = a.altBaro.map { $0 * 0.3048 }
        let vr = a.verticalRate
        let vertical: String = {
            guard let vr else { return "—" }
            if abs(vr) < 200 { return "Nivelado" }
            return vr > 0 ? "↑ \(num(vr * 0.3048)) m/min" : "↓ \(num(-vr * 0.3048)) m/min"
        }()
        return Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 14) {
            GridRow {
                Stat(title: "Altitud", value: altM.map { "\(num($0)) m" } ?? "—", detail: a.altBaro.map { "\(num($0)) ft" })
                Stat(title: "Velocidad", value: a.groundSpeed.map { "\(num($0 * 1.852)) km/h" } ?? "—", detail: a.groundSpeed.map { "\(num($0)) nudos" })
            }
            GridRow {
                Stat(title: "Rumbo", value: a.track.map { "\(num($0))° \(Geo.compassShort[Geo.index($0)])" } ?? "—")
                Stat(title: "Vertical", value: vertical)
            }
        }
    }

    private var aircraftSection: some View {
        let i = info.value
        let kind = Classifier.kind(a, info: i)
        let model = i.map { "\($0.manufacturer ?? "") \($0.type ?? "")".trimmingCharacters(in: .whitespaces) } ?? (a.desc ?? a.type ?? "Modelo desconocido")
        let details = [a.registration ?? i?.registration, i?.registeredOwner, a.squawk.map { "squawk \($0)" }].compactMap { $0 }
        return VStack(alignment: .leading, spacing: 6) {
            Eyebrow("Aeronave")
            HStack(spacing: 12) {
                AircraftIcon(kind: kind, size: 36, shadow: false)
                VStack(alignment: .leading) {
                    Text(model).fontWeight(.semibold)
                    Text(kind.label).foregroundStyle(.secondary)
                }
            }
            if !details.isEmpty {
                Text(details.joined(separator: " · ")).foregroundStyle(.secondary)
            }
            PhotoView(photo: photo, alt: a.registration ?? a.callsign)
                .padding(.top, 6)
        }
    }
}

private struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased()).font(.caption2).tracking(0.8).foregroundStyle(.secondary)
    }
}

private struct Stat: View {
    let title: String
    let value: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: 22, weight: .bold)).monospacedDigit()
            Text(detail ?? " ").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Hacia dónde mirar: distancia, dirección y ángulo sobre el horizonte.
private struct LookDirection: View {
    let contact: Contact
    let me: CLLocationCoordinate2D

    var body: some View {
        let brg = Geo.bearing(me, contact.coordinate)
        let idx = Geo.index(brg)
        let elev = contact.aircraft.altBaro.map { Geo.elevation(km: contact.km, altitudeM: $0 * 0.3048) }
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(.secondary.opacity(0.3), lineWidth: 2)
                Text("N").font(.system(size: 9)).foregroundStyle(.secondary).offset(y: -18)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: 0xf59e0b))
                    .offset(y: -10)
                    .rotationEffect(.degrees(brg))
                Circle().fill(Color(hex: 0x1d4ed8)).frame(width: 6, height: 6)
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(String(format: "%.1f", contact.km).replacingOccurrences(of: ".", with: ",")) km al \(Geo.compass[idx])")
                    .font(.headline)
                Text(elev.map { "Mira hacia el \(Geo.compassShort[idx]) (\(num(brg))°), unos \(num(max(0, $0)))° sobre el horizonte" }
                     ?? "Rumbo desde ti: \(num(brg))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
    }
}

private struct PhotoView: View {
    let photo: Lookup<Photo>
    let alt: String

    var body: some View {
        switch photo {
        case .loading:
            placeholder(loading: true)
        case .loaded(nil):
            placeholder(loading: false)
        case .loaded(let p?):
            VStack(alignment: .leading, spacing: 4) {
                AsyncImage(url: p.url) { phase in
                    switch phase {
                    case .success(let image):
                        // El hueco fija el tamaño y la foto lo rellena por encima: una foto con
                        // .fill dentro del flujo de la vista ensancharía todo el panel.
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: 214)
                            .overlay { image.resizable().scaledToFill() }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityLabel("Foto de \(alt)")
                    case .failure:
                        placeholder(loading: false)
                    default:
                        placeholder(loading: true)
                    }
                }
                if let article = p.modelArticle {
                    Text(referenceCaption(article: article, link: p.link))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let by = p.photographer, let link = p.link {
                    Link("© \(by) / planespotters.net", destination: link).font(.caption2)
                }
            }
        }
    }

    /// «Imagen de referencia del modelo, no de este avión · Wikipedia: Eurocopter EC135», con el artículo enlazado.
    private func referenceCaption(article: String, link: URL?) -> AttributedString {
        var text = AttributedString("Imagen de referencia del modelo, no de este avión · ")
        var source = AttributedString("Wikipedia: \(article)")
        source.link = link
        text.append(source)
        return text
    }

    private func placeholder(loading: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "photo").font(.system(size: 30)).opacity(0.6)
            Text(loading ? "Buscando foto…" : "No hay imagen disponible").font(.callout)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 214)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }
}
