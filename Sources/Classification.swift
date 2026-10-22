import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

// MARK: - Tipo de aeronave (silueta)

enum AircraftKind: String, CaseIterable {
    case jumbo, wide, narrow, bizjet, turboprop, light, heli, glider, fighter, balloon, drone

    var label: String {
        switch self {
        case .jumbo: "Cuatrimotor de fuselaje ancho"
        case .wide: "Bimotor de fuselaje ancho"
        case .narrow: "Avión de pasillo único"
        case .bizjet: "Reactor regional o ejecutivo"
        case .turboprop: "Turbohélice"
        case .light: "Avioneta"
        case .heli: "Helicóptero"
        case .glider: "Planeador"
        case .fighter: "Militar de alto rendimiento"
        case .balloon: "Globo"
        case .drone: "Dron"
        }
    }

    var color: Color {
        switch self {
        case .jumbo: Color(hex: 0x8b5cf6)
        case .wide: Color(hex: 0x3b82f6)
        case .narrow: Color(hex: 0xfacc15)
        case .bizjet: Color(hex: 0x22d3ee)
        case .turboprop: Color(hex: 0x22c55e)
        case .light: Color(hex: 0xfb923c)
        case .heli: Color(hex: 0xef4444)
        case .glider: Color(hex: 0xa3e635)
        case .fighter: Color(hex: 0x94a3b8)
        case .balloon: Color(hex: 0xf472b6)
        case .drone: Color(hex: 0xc084fc)
        }
    }

    /// Tamaño en el mapa, en puntos.
    var size: CGFloat {
        switch self {
        case .jumbo: 46
        case .wide: 42
        case .narrow: 34
        case .bizjet: 28
        case .turboprop, .heli, .glider: 30
        case .light: 24
        case .fighter: 32
        case .balloon: 26
        case .drone: 22
        }
    }

    /// El globo y el dron no tienen morro: no giran con el rumbo.
    var rotates: Bool { self != .balloon && self != .drone }
}

// MARK: - Uso: comercial, privado, militar o policial

enum FlightUse: String, CaseIterable, Identifiable {
    case commercial, general, military, police

    /// Opciones del filtro de la barra de herramientas. «Policía» solo se muestra como etiqueta.
    static let filterable: [FlightUse] = [.commercial, .general, .military]

    var id: String { rawValue }
    var label: String {
        switch self {
        case .commercial: "Comercial"
        case .general: "Privada"
        case .military: "Militar"
        case .police: "Policía"
        }
    }
    var singular: String {
        switch self {
        case .commercial: "comercial"
        case .general: "privado"
        case .military: "militar"
        case .police: "policial"
        }
    }
    var plural: String {
        switch self {
        case .commercial: "comerciales"
        case .general: "privados"
        case .military: "militares"
        case .police: "policiales"
        }
    }
    var color: Color {
        switch self {
        case .commercial: Color(hex: 0x2563eb)
        case .general: Color(hex: 0xea580c)
        case .military: Color(hex: 0x475569)
        case .police: Color(hex: 0x0f766e)
        }
    }
}

// MARK: - Clasificador

enum Classifier {
    private static let types: [AircraftKind: String] = [
        .jumbo: "A388 A380 A342 A343 A345 A346 A340 B741 B742 B743 B744 B748 B74S B74R BLCF A124 A225 IL76 IL96 C17 C5 C5M K35R E3TF E3CF A400",
        .wide: "A306 A30B A310 A332 A333 A337 A338 A339 A359 A35K B762 B763 B764 B772 B773 B77L B77W B778 B779 B788 B789 B78X MD11 DC10 L101 IL86 KC10 A3ST",
        .heli: "EC20 EC25 EC30 EC35 EC45 EC55 EC75 EC120 EC130 EC135 EC145 AS32 AS35 AS50 AS55 AS65 AS3B H125 H130 H135 H145 H155 H160 H175 H215 H225 "
            + "A109 A119 A129 A139 A149 A169 A189 AW09 AW101 B06 B06T B105 B212 B222 B230 B407 B412 B427 B429 B430 B505 BK17 R22 R44 R66 S61 S64 S70 S76 S92 "
            + "UH1 UH60 H47 H53 H60 H64 MI8 MI17 MI24 MI26 NH90 EH10 TIGR LYNX PUMA SUCO GAZL ALO3 EXPL MD52 MD60 H500 H269 HUCO",
        .turboprop: "AT43 AT44 AT45 AT46 AT72 AT73 AT75 AT76 DH8A DH8B DH8C DH8D DHC6 DHC7 DHC5 SF34 SB20 JS31 JS32 JS41 D228 D328 F27 F50 SH36 E120 "
            + "B190 BE20 BE30 BE9L BE9T B350 PC12 PC6T C208 C212 CN35 C295 C130 C30J C160 P180 PAY2 PAY3 TBM7 TBM8 TBM9 M600 L410 AN26 AN28 AN32 Y12 DHC2T KODI",
        .bizjet: "C25A C25B C25C C25M C500 C501 C510 C525 C550 C551 C55B C560 C56X C650 C680 C68A C700 C750 E50P E55P E545 E550 LJ31 LJ35 LJ40 LJ45 LJ60 LJ75 "
            + "GLF2 GLF3 GLF4 GLF5 GLF6 GL5T GL7T GLEX G150 G200 G280 CL30 CL35 CL60 F2TH F900 FA10 FA20 FA50 FA7X FA8X H25B H25C HDJT PC24 PRM1 BE40 SF50 EA50 "
            + "CRJ1 CRJ2 CRJ7 CRJ9 CRJX E135 E145 E35L F28 F70 F100 B712 DC93 RJ70 RJ85 RJ1H B461 B462 B463",
        .fighter: "F16 F15 F18 F18S F22 F35 F5 EUFI TORN MIR2 M2KC RFAL GRIF HAWK T38 HARR AV8B F4 SU27 SU30 SU35 MG29 L39 C101 PC21 TEX2 T6",
        .glider: "GLID ASK21 ASK13 DG80 DG1T LS8 DUOD ARCP JANU NIMB",
        .balloon: "BALL",
    ]

    private static let byType: [String: AircraftKind] = {
        var map: [String: AircraftKind] = [:]
        for (kind, list) in types {
            for t in list.split(separator: " ") { map[String(t)] = kind }
        }
        return map
    }()

    private static let byCategory: [String: AircraftKind] = [
        "A1": .light, "A2": .turboprop, "A3": .narrow, "A4": .narrow, "A5": .wide, "A6": .fighter, "A7": .heli,
        "B1": .glider, "B2": .balloon, "B4": .light, "B6": .drone,
    ]

    /// Modelos de aerolínea fuera de las clases de reactor de línea (regionales y turbohélices de pasajeros).
    private static let airliner = Set(("CRJ1 CRJ2 CRJ7 CRJ9 CRJX E135 E145 E35L F28 F70 F100 B712 DC93 RJ70 RJ85 RJ1H B461 B462 B463 "
        + "AT43 AT44 AT45 AT46 AT72 AT73 AT75 AT76 DH8A DH8B DH8C DH8D DHC7 SF34 SB20 JS31 JS32 JS41 D328 F27 F50 SH36 E120 L410 AN26 AN28 AN32 Y12")
        .split(separator: " ").map(String.init))

    /// El código de tipo ICAO manda; si no se reconoce, la categoría ADS-B.
    static func kind(type: String?, category: String?) -> AircraftKind {
        let t = (type ?? "").uppercased()
        if let k = byType[t] { return k }
        if let c = category, let k = byCategory[c] { return k }
        // Avionetas de pistón habituales sin categoría emitida.
        if t.range(of: #"^(C1[0-9]{2}|C2[0-9]{2}|P28|PA|SR2|DA[0-9]|BE3[3-6]|M20|TB[12])"#, options: .regularExpression) != nil { return .light }
        return .narrow
    }

    static func kind(_ a: Aircraft, info: AircraftInfo? = nil) -> AircraftKind {
        kind(type: a.type ?? info?.icaoType, category: a.category)
    }

    /// Propietarios policiales según adsbdb (p. ej. «National Police Air Service», «Guardia Civil», «Polizei»).
    private static let policeOwner = #"(?i)polic|polizei|politie|policja|gendarm|guardia civil|carabinieri|ertzaintza|mossos|sheriff|highway patrol|state patrol|garda"#
    /// Indicativos policiales conocidos: POLICE y UKP (Reino Unido), POF (Police aux frontières, Francia),
    /// BPO (Bundespolizei), PPH/PMV (Polizei de Baja Sajonia / Mecklemburgo), ZEUS (Policía Nacional)
    /// y CUCO (Guardia Civil). Los dos españoles son indicativos de radio habituales, no códigos OACI oficiales.
    private static let policeCallsign = #"^(POLICE|UKP|NPAS|POF|BPO|PPH|PMV|ZEUS|CUCO)"#

    static func isPolice(_ a: Aircraft, info: AircraftInfo?) -> Bool {
        if a.callsign.range(of: policeCallsign, options: .regularExpression) != nil { return true }
        if let owner = info?.registeredOwner, owner.range(of: policeOwner, options: .regularExpression) != nil { return true }
        return false
    }

    /// `hasAirline`: adsbdb devolvió una aerolínea para este indicativo.
    static func use(_ a: Aircraft, info: AircraftInfo? = nil, hasAirline: Bool = false) -> FlightUse {
        // Antes que militar: cuerpos como la Guardia Civil o la Gendarmerie aparecen marcados como militares en ADS-B.
        if isPolice(a, info: info) { return .police }
        if a.isMilitary { return .military }
        let k = kind(a, info: info)
        if k == .fighter { return .military }
        let cs = a.callsign
        let type = (a.type ?? info?.icaoType ?? "").uppercased()
        let airlinerType = [.jumbo, .wide, .narrow].contains(k) || airliner.contains(type)
        // Indicativo de aerolínea: código OACI de 3 letras seguido de un número de vuelo (IBE3166, RYR61VG).
        let airlineCallsign = cs.range(of: #"^[A-Z]{3}\d[0-9A-Z]{0,3}$"#, options: .regularExpression) != nil
        // Un avión de línea sin indicativo (p. ej. rodando) se asume comercial; con un indicativo no de aerolínea, privado.
        if airlinerType && (cs.isEmpty || hasAirline || airlineCallsign) { return .commercial }
        return .general
    }
}
