# Radar de aviones

App nativa de macOS que muestra **el avión que pasa más cerca de ti**, su posición en el mapa y toda su información: vuelo, aerolínea, origen y destino, altitud, velocidad, modelo y hacia dónde mirar para verlo.

Hecha en SwiftUI y MapKit, con datos abiertos de ADS-B.

## Descargar

1. Descarga **`Radar-de-aviones-macOS.zip`** desde la [última versión](../../releases/latest).
2. Descomprímelo y arrastra **Radar de aviones** a tu carpeta Aplicaciones.
3. La primera vez, macOS la bloqueará porque no está firmada con una cuenta de desarrollador de Apple:
   - Intenta abrirla, cierra el aviso y ve a **Ajustes del Sistema › Privacidad y seguridad**.
   - Abajo verás «Se ha bloqueado “Radar de aviones”»: pulsa **Abrir igualmente**.
   - O, desde Terminal: `xattr -dr com.apple.quarantine "/Applications/Radar de aviones.app"`
4. Acepta el permiso de ubicación. Si lo deniegas, haz clic en el mapa para elegir un punto.

Requiere **macOS 14 Sonoma o posterior**. Funciona en Mac con Apple Silicon e Intel.

## Qué muestra

- **El avión más cercano** en vuelo (busca en unos 74 km), actualizado cada 5 segundos.
- **En el mapa:** el avión con un icono según su tipo, la línea hasta ti, la estela de su recorrido y la ruta entre aeropuertos.
- **Ficha:** número de vuelo y aerolínea, origen → destino, distancia y dirección con el ángulo sobre el horizonte, altitud, velocidad, rumbo, velocidad vertical, modelo, matrícula y foto.
- **Tipo de vuelo:** comercial, privado, militar o policial, con un filtro en la barra de herramientas. Los aviones policiales se reconocen por su indicativo (POLICE, UKP, ZEUS, CUCO…) o por su propietario (Police, Policía, Polizei, Guardia Civil, Gendarmerie…).
- **Iconos por tipo de nave:** cuatrimotor, fuselaje ancho, pasillo único, reactor regional o ejecutivo, turbohélice, avioneta, helicóptero, planeador, militar, globo y dron.

Controles: arrastra el mapa para explorar (deja de seguir al avión; «Volver a seguir» lo recupera), **⌥-clic** para fijar otro punto de observación y «Ver el resto» para mostrar los demás aviones.

## Compilar desde el código

Solo hacen falta las Command Line Tools de Xcode (`xcode-select --install`):

```bash
./build.sh            # build/Radar de aviones.app
./build.sh --install  # y la copia a ~/Applications
./build.sh --release  # y crea el .zip para publicar
```

## Fuentes de datos

- Posiciones: [adsb.lol](https://adsb.lol) y [adsb.fi](https://adsb.fi) (si una falla, se usa la otra).
- Rutas y datos de la aeronave: [adsbdb](https://www.adsbdb.com).
- Fotos: [planespotters.net](https://www.planespotters.net).

Los datos los aportan redes de voluntarios: puede haber huecos de cobertura o información incompleta.

## Licencia

[MIT](LICENSE)
