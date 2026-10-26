import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../services/apple_mapkit.dart';
import '../services/mapas_config.dart';
import '../services/theme_service.dart';

/// Mapa chiquito y quieto con un pin, para mostrar una ubicación compartida
/// en un chat ("Estoy aquí" en Comunidad, chats privados, etc.). Tocarlo
/// abre la ubicación en la app de mapas del teléfono.
///
/// En iPhone es una foto del mapa de Apple (liviana, ideal para listas de
/// mensajes) con el mismo estilo que el resto de los mapas de la app.
class MapaMini extends StatelessWidget {
  final double lat;
  final double lng;
  final double alto;
  final double? ancho;
  final bool abrirAlTocar;
  final double zoom;

  /// Ícono del punto (por defecto, el pin rojo de ubicación).
  final IconData? icono;
  final Color? colorIcono;

  const MapaMini({
    super.key,
    required this.lat,
    required this.lng,
    this.alto = 120,
    this.ancho,
    this.abrirAlTocar = true,
    this.zoom = 15,
    this.icono,
    this.colorIcono,
  });

  static Future<void> abrirEnMapas(double lat, double lng) async {
    final uri = Platform.isIOS
        ? Uri.parse('maps://?ll=$lat,$lng&q=Ubicaci%C3%B3n')
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _pin() {
    final i = icono;
    if (i != null) {
      return Icon(i, color: colorIcono ?? Colors.green, size: 28);
    }
    // El mismo pin de Okventín (pixel art) que se usa en Encontrar.
    return Image.asset('assets/images/okventin_pin_mapa.png',
        width: 44, height: 44, filterQuality: FilterQuality.none);
  }

  Widget _apple() {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkNotifier,
      builder: (context, oscuro, _) => LayoutBuilder(
        builder: (context, c) {
          final w = ancho ??
              (c.maxWidth.isFinite ? c.maxWidth : 260.0);
          return FutureBuilder<Uint8List?>(
            future: AppleMapKit.foto(lat, lng,
                ancho: w, alto: alto, zoom: zoom),
            builder: (context, snap) {
              final png = snap.data;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (png != null)
                    Image.memory(png, fit: BoxFit.cover, gaplessPlayback: true)
                  else
                    Container(
                        color: oscuro
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFEDEBE6)),
                  // El pin apunta al centro (su punta en el punto exacto).
                  Align(
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: Offset(0, icono == null ? -22 : 0),
                      child: _pin(),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _flutterMap() {
    final punto = LatLng(lat, lng);
    return AbsorbPointer(
      child: FlutterMap(
        options: MapOptions(
          center: punto,
          zoom: zoom,
          interactiveFlags: InteractiveFlag.none,
        ),
        children: [
          ...MapasConfig.capas(),
          MarkerLayer(markers: [
            Marker(
              point: punto,
              width: 44,
              height: 44,
              anchorPos: icono == null
                  ? AnchorPos.align(AnchorAlign.top)
                  : AnchorPos.align(AnchorAlign.center),
              builder: (_) => _pin(),
            ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapa = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: alto,
        width: ancho,
        child: Platform.isIOS ? _apple() : _flutterMap(),
      ),
    );
    if (!abrirAlTocar) return mapa;
    return GestureDetector(onTap: () => abrirEnMapas(lat, lng), child: mapa);
  }
}
