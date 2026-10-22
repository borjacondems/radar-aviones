import AppKit
import SwiftUI

@main
enum Main {
    static func main() {
        // `RadarAviones --make-icon salida.png` dibuja el icono de la app (lo usa build.sh).
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--make-icon"), i + 1 < args.count {
            MainActor.assumeIsolated { AppIconView.render(to: args[i + 1]) }
            return
        }
        // `RadarAviones --snapshot salida.png lat lon`: consulta los datos reales y dibuja el panel (para pruebas).
        if let i = args.firstIndex(of: "--snapshot"), i + 3 < args.count,
           let lat = Double(args[i + 2]), let lon = Double(args[i + 3]) {
            MainActor.assumeIsolated { Snapshot.run(to: args[i + 1], lat: lat, lon: lon) }
            return
        }
        RadarApp.main()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct RadarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("Radar de aviones", id: "main") {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1240, height: 780)
    }
}

/// Icono: avión de pasillo único sobre una pantalla de radar.
struct AppIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x0b1f4d), Color(hex: 0x1d4ed8)], startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
            ForEach([180, 300, 420], id: \.self) { r in
                Circle().stroke(.white.opacity(0.18), lineWidth: 6).frame(width: CGFloat(r) * 2 - 120, height: CGFloat(r) * 2 - 120)
            }
            Rectangle().fill(.white.opacity(0.12)).frame(width: 4, height: 700)
            Rectangle().fill(.white.opacity(0.12)).frame(width: 700, height: 4)
            AircraftIcon(kind: .narrow, heading: 45, size: 500, shadow: false)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
        }
        .frame(width: 1024, height: 1024)
    }

    @MainActor static func render(to path: String) {
        let renderer = ImageRenderer(content: AppIconView())
        renderer.scale = 1
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else {
            fputs("No se pudo generar el icono\n", stderr)
            exit(1)
        }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
