import SwiftUI

// Siluetas vistas desde arriba, morro hacia arriba, en un lienzo de -16…16 (las mismas que la versión web).

enum Primitive {
    case path(String)
    case rect(CGFloat, CGFloat, CGFloat, CGFloat, radius: CGFloat = 0)
    case circle(CGFloat, CGFloat, r: CGFloat)
    case ellipse(CGFloat, CGFloat, rx: CGFloat, ry: CGFloat)
}

struct Silhouette {
    var fill: [Primitive]
    /// Trazos sin relleno (aspas del rotor, cuerdas del globo, brazos del dron).
    var lines: [Primitive] = []
    var lineScale: CGFloat = 1.3
    /// Relleno translúcido (disco del rotor).
    var halo: [Primitive] = []

    private static let jet = "M0-15C1.3-15 1.8-13.5 1.8-11L1.8-3.5L14 3L14 4.8L1.8 1.5L1.4 9L5.5 12L5.5 13.6L0 12.6L-5.5 13.6L-5.5 12L-1.4 9L-1.8 1.5L-14 4.8L-14 3L-1.8-3.5L-1.8-11C-1.8-13.5-1.3-15 0-15Z"

    private static func pods(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 1.8, _ h: CGFloat = 3.6) -> [Primitive] {
        [.rect(x - w / 2, y, w, h, radius: w / 2), .rect(-x - w / 2, y, w, h, radius: w / 2)]
    }

    static func of(_ kind: AircraftKind) -> Silhouette {
        switch kind {
        case .jumbo:
            return Silhouette(fill: [.path(jet)] + pods(5, -3.8) + pods(10, -1.2))
        case .wide:
            return Silhouette(fill: [.path(jet)] + pods(6, -3.2, 2.2, 4))
        case .narrow:
            return Silhouette(fill: [.path(jet)] + pods(6, -3.2))
        case .bizjet:
            return Silhouette(fill: [.path("M0-14C1-14 1.3-12.5 1.3-10L1.3-2L11 2.5L11 3.8L1.3 2L1.1 8L5 10.5L5 11.8L0 11L-5 11.8L-5 10.5L-1.1 8L-1.3 2L-11 3.8L-11 2.5L-1.3-2L-1.3-10C-1.3-12.5-1-14 0-14Z")]
                + pods(2.6, 3.5, 2, 4.5))
        case .turboprop:
            return Silhouette(fill: [.path("M0-14C1.2-14 1.6-12 1.6-10L1.6-3L14-2L14 .5L1.6 1L1.2 9L5 10.5L5 12L0 11.5L-5 12L-5 10.5L-1.2 9L-1.6 1L-14 .5L-14-2L-1.6-3L-1.6-10C-1.6-12-1.2-14 0-14Z")]
                + pods(5.5, -5.5, 1.8, 6) + [.rect(3, -6.4, 5, 0.9), .rect(-8, -6.4, 5, 0.9)])
        case .light:
            return Silhouette(fill: [.path("M-1-11L1-11L1.3-4L14-4L14-1.3L1.3-1.3L.8 8L4.5 9L4.5 10.6L0 10.2L-4.5 10.6L-4.5 9L-.8 8L-1.3-1.3L-14-1.3L-14-4L-1.3-4Z"),
                                     .rect(-3, -12.2, 6, 0.9)])
        case .heli:
            return Silhouette(fill: [.ellipse(0, -2, rx: 3.2, ry: 5.5), .rect(-0.7, 2, 1.4, 11), .rect(-3, 11.5, 6, 1.2)],
                              lines: [.path("M-11-11L11 11M11-11L-11 11")],
                              halo: [.circle(0, 0, r: 13)])
        case .glider:
            return Silhouette(fill: [.path("M0-9C.7-9 .9-7 .9-5L.9-3L15.5-2.2L15.5-.8L.9-.6L.5 10L3.5 10.8L3.5 12L-3.5 12L-3.5 10.8L-.5 10L-.9-.6L-15.5-.8L-15.5-2.2L-.9-3L-.9-5C-.9-7-.7-9 0-9Z")])
        case .fighter:
            return Silhouette(fill: [.path("M0-15L1.5-9L1.6-4L11 6L11 8L2 7L3.5 12L3.5 13L0 12L-3.5 13L-3.5 12L-2 7L-11 8L-11 6L-1.6-4L-1.5-9Z")])
        case .balloon:
            return Silhouette(fill: [.path("M0-14C6-14 9-9.5 9-5C9 0 3 4 1.5 6L-1.5 6C-3 4-9 0-9-5C-9-9.5-6-14 0-14Z"), .rect(-2.5, 10, 5, 3.5, radius: 0.6)],
                              lines: [.path("M-1.5 6L-2 10M1.5 6L2 10")], lineScale: 1)
        case .drone:
            return Silhouette(fill: [.circle(-8, -8, r: 4), .circle(8, -8, r: 4), .circle(-8, 8, r: 4), .circle(8, 8, r: 4), .rect(-2.5, -3.5, 5, 7, radius: 1.5)],
                              lines: [.path("M-8-8L8 8M8-8L-8 8")], lineScale: 2.6)
        }
    }
}

/// Intérprete mínimo de trazados SVG: solo M, L, C y Z absolutos, que es lo que usan las siluetas.
enum SVGPath {
    private static var cache: [String: Path] = [:]

    static func parse(_ d: String) -> Path {
        if let p = cache[d] { return p }
        var tokens: [String] = []
        var num = ""
        func flush() { if !num.isEmpty { tokens.append(num); num = "" } }
        for ch in d {
            if ch.isLetter { flush(); tokens.append(String(ch)) }
            else if ch == "-" { flush(); num = "-" }
            else if ch == "." { if num.contains(".") { flush() }; num.append(ch) }
            else if ch.isNumber { num.append(ch) }
            else { flush() }
        }
        flush()

        var path = Path()
        var i = 0, cmd = "M"
        func next() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i]) ?? 0) }
        while i < tokens.count {
            if tokens[i].first?.isLetter == true {
                cmd = tokens[i]; i += 1
                if cmd == "Z" { path.closeSubpath() }
                continue
            }
            switch cmd {
            case "M":
                path.move(to: CGPoint(x: next(), y: next()))
                cmd = "L" // pares siguientes implícitos = líneas
            case "L":
                path.addLine(to: CGPoint(x: next(), y: next()))
            case "C":
                let c1 = CGPoint(x: next(), y: next()), c2 = CGPoint(x: next(), y: next()), p = CGPoint(x: next(), y: next())
                path.addCurve(to: p, control1: c1, control2: c2)
            default:
                i += 1
            }
        }
        cache[d] = path
        return path
    }
}

struct SilhouetteShape: Shape {
    let primitives: [Primitive]

    func path(in rect: CGRect) -> Path {
        var p = Path()
        for prim in primitives {
            switch prim {
            case .path(let d): p.addPath(SVGPath.parse(d))
            case let .rect(x, y, w, h, r): p.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h), cornerSize: CGSize(width: r, height: r))
            case let .circle(cx, cy, r): p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
            case let .ellipse(cx, cy, rx, ry): p.addEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry))
            }
        }
        let s = min(rect.width, rect.height) / 32
        return p.applying(CGAffineTransform(translationX: rect.midX, y: rect.midY).scaledBy(x: s, y: s))
    }
}

struct AircraftIcon: View {
    let kind: AircraftKind
    var heading: Double = 0
    var size: CGFloat? = nil
    var shadow = true

    var body: some View {
        let s = size ?? kind.size
        let sil = Silhouette.of(kind)
        let line = 0.9 * s / 32
        let ink = Color(hex: 0x111111)
        ZStack {
            SilhouetteShape(primitives: sil.halo).fill(kind.color.opacity(0.18))
            SilhouetteShape(primitives: sil.lines).stroke(ink, lineWidth: line * sil.lineScale)
            SilhouetteShape(primitives: sil.fill).fill(kind.color)
            SilhouetteShape(primitives: sil.fill).stroke(ink, style: StrokeStyle(lineWidth: line, lineJoin: .round))
        }
        .frame(width: s, height: s)
        .rotationEffect(.degrees(kind.rotates ? heading : 0))
        .shadow(color: .black.opacity(shadow ? 0.4 : 0), radius: 1.5, y: 1)
    }
}

struct UseBadge: View {
    let use: FlightUse

    var body: some View {
        Text(use.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(use.color))
    }
}
