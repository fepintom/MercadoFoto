import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../screens/ajustes_mapa_screen.dart';
import 'ajustes_mapa.dart';
import 'theme_service.dart';

/// El fondo de todos los mapas de la app (Encontrar, direcciones, entregas,
/// "Estoy por aquí"...): mapas de CARTO, uno para modo claro y otro para
/// modo oscuro, cada uno con su filtro de color (ver [AjustesMapa]). Se
/// eligen y prueban en vivo desde "Ajustes del mapa"; los definitivos
/// quedan fijos en AjustesMapa.claroFijo / oscuroFijo.
class MapasConfig {
  MapasConfig._();

  /// Capas de fondo para poner al comienzo de los hijos de un FlutterMap
  /// (`...MapasConfig.capas()`). [oscuro] fuerza un modo (para el panel de
  /// ajustes); si no, sigue el modo de la app.
  static List<Widget> capas({bool? oscuro}) {
    return [
      AnimatedBuilder(
        animation:
            Listenable.merge([AjustesMapa.cambios, ThemeService.isDarkNotifier]),
        builder: (context, _) {
          final a = AjustesMapa.para(oscuro ?? ThemeService.isDarkMode);
          final url = MapasCarto.url(a.mapa);
          return ColorFiltered(
            colorFilter: a.filtro(),
            child: TileLayer(
              key: ValueKey(url),
              urlTemplate: url,
              subdomains: const ['a', 'b', 'c', 'd'],
              tileSize: 256,
              userAgentPackageName: 'com.okventa.app',
            ),
          );
        },
      ),
    ];
  }

  /// Crédito que CARTO y OpenStreetMap piden mostrar sobre el mapa. Mantenerlo
  /// presionado abre "Ajustes del mapa".
  static Widget atribucion() {
    return Builder(
      builder: (context) => GestureDetector(
        onLongPress: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AjustesMapaScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('© CARTO © OpenStreetMap',
              style: TextStyle(fontSize: 9, color: Color(0xFF333333))),
        ),
      ),
    );
  }
}
