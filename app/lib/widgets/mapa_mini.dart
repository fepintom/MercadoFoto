import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/mapas_config.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

/// Mapa chiquito y quieto con un pin, para mostrar una ubicación compartida
/// en un chat. Tocarlo abre la ubicación en la app de mapas del teléfono.
class MapaMini extends StatelessWidget {
  final double lat;
  final double lng;
  final double alto;
  final double? ancho;
  final bool abrirAlTocar;

  const MapaMini({
    super.key,
    required this.lat,
    required this.lng,
    this.alto = 120,
    this.ancho,
    this.abrirAlTocar = true,
  });

  static Future<void> abrirEnMapas(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final punto = LatLng(lat, lng);
    final mapa = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: alto,
        width: ancho,
        child: AbsorbPointer(
          child: FlutterMap(
            options: MapOptions(
              center: punto,
              zoom: 15,
              interactiveFlags: InteractiveFlag.none,
            ),
            children: [
              ...MapasConfig.capas(),
              MarkerLayer(markers: [
                Marker(
                  point: punto,
                  width: 34,
                  height: 34,
                  anchorPos: AnchorPos.align(AnchorAlign.top),
                  builder: (_) => const Icon(Icons.location_on_rounded,
                      color: Color(0xFFE53935), size: 34),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (!abrirAlTocar) return mapa;
    return GestureDetector(onTap: () => abrirEnMapas(lat, lng), child: mapa);
  }
}
