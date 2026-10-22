#!/bin/bash
# Compila «Radar de aviones.app» sin Xcode (solo Command Line Tools).
# Uso: ./build.sh            -> build/Radar de aviones.app (binario universal: Apple Silicon + Intel)
#      ./build.sh --install  -> además la copia a ~/Applications
#      ./build.sh --release  -> además crea build/Radar-de-aviones-macOS.zip para publicar
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Radar de aviones.app"
BIN="$APP/Contents/MacOS/RadarAviones"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/obj

echo "→ Compilando…"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library \
    -target "$arch-apple-macos14.0" \
    Sources/*.swift -o "build/obj/RadarAviones-$arch"
done
lipo -create build/obj/RadarAviones-arm64 build/obj/RadarAviones-x86_64 -output "$BIN"
cp Info.plist "$APP/Contents/Info.plist"

echo "→ Generando icono…"
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
"$BIN" --make-icon build/icon-1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon-1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) build/icon-1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "→ Firmando (ad hoc)…"
codesign --force --deep --sign - "$APP"

case "${1:-}" in
  --install)
    mkdir -p ~/Applications
    rm -rf ~/Applications/"Radar de aviones.app"
    cp -R "$APP" ~/Applications/
    echo "✓ Instalada en ~/Applications/Radar de aviones.app"
    ;;
  --release)
    rm -f build/Radar-de-aviones-macOS.zip
    ditto -c -k --keepParent "$APP" build/Radar-de-aviones-macOS.zip
    echo "✓ build/Radar-de-aviones-macOS.zip"
    ;;
  *)
    echo "✓ $APP"
    ;;
esac
