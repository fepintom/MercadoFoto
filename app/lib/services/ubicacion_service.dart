import 'package:geolocator/geolocator.dart';

/// Un par de coordenadas, sin depender de ninguna librería de mapas.
///
/// A propósito NO usa `LatLng` de latlong2: ese tipo viene de flutter_map y
/// atarlo aquí obligaría a tocar toda la lógica el día que cambiemos a
/// Google Maps. Cada mapa convierte esto a su propio tipo en el momento de
/// dibujar, que es la única parte que debería cambiar.
class Coordenadas {
  final double lat;
  final double lng;

  const Coordenadas(this.lat, this.lng);
}

/// Ubicación del usuario y cálculo de distancias.
///
/// Es la pieza que sobrevive a un cambio de proveedor de mapas: pedir
/// permisos, leer el GPS y medir distancias no tiene nada que ver con quién
/// dibuja el mapa. Lo específico del proveedor son los marcadores y la
/// cámara, que viven en cada pantalla.
class UbicacionService {
  UbicacionService._();

  /// Última posición conocida en esta sesión. Evita volver a pedirle el GPS
  /// al teléfono en cada pantalla que la necesite.
  static Coordenadas? ultimaConocida;

  /// Devuelve la ubicación actual, o null si el usuario no dio permiso o
  /// tiene el GPS apagado. Nunca lanza: quien la llama decide qué mostrar
  /// cuando no hay ubicación.
  static Future<Coordenadas?> obtener({bool usarCache = true}) async {
    if (usarCache && ultimaConocida != null) return ultimaConocida;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      ultimaConocida = Coordenadas(pos.latitude, pos.longitude);
      return ultimaConocida;
    } catch (_) {
      return null;
    }
  }

  /// Distancia en kilómetros entre dos puntos.
  static double distanciaKm(Coordenadas a, Coordenadas b) {
    return Geolocator.distanceBetween(a.lat, a.lng, b.lat, b.lng) / 1000;
  }
}
