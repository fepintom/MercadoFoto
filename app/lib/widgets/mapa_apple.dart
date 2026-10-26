import 'dart:typed_data';

import 'package:apple_maps_flutter/apple_maps_flutter.dart' as am;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart' as ll;

import '../services/apple_mapkit.dart';
import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';

/// Mapa de Apple (iPhone) para elegir o mostrar un punto: tocar el mapa
/// mueve el pin, opcionalmente con un círculo de radio. Trae + / − y
/// "mi ubicación" (mismo diseño que el resto de la app) y sigue el modo
/// claro/oscuro de OkVenta.
class MapaApple extends StatefulWidget {
  final ll.LatLng centro;
  final double zoom;

  /// Pin (rojo, el de Apple). null = sin pin.
  final ll.LatLng? pin;
  final double? radioMetros;
  final ValueChanged<ll.LatLng>? onTap;

  /// Controles a la derecha: abajo (por defecto) o al centro.
  final bool controlesAlCentro;

  const MapaApple({
    super.key,
    required this.centro,
    this.zoom = 14,
    this.pin,
    this.radioMetros,
    this.onTap,
    this.controlesAlCentro = false,
  });

  @override
  State<MapaApple> createState() => _MapaAppleState();
}

class _MapaAppleState extends State<MapaApple> {
  am.AppleMapController? _ctrl;
  bool _buscando = false;

  // Pin de Okventín (el mismo de Encontrar).
  static Uint8List? _pinOkventin;

  @override
  void initState() {
    super.initState();
    if (_pinOkventin == null) {
      rootBundle.load('assets/images/okventin_pin_mapa.png').then((b) {
        _pinOkventin = b.buffer.asUint8List();
        if (mounted) setState(() {});
      }).catchError((_) {});
    }
  }

  Future<void> _miUbicacion() async {
    setState(() => _buscando = true);
    try {
      final yo = await UbicacionService.obtener(usarCache: false);
      if (yo != null) {
        await _ctrl?.animateCamera(
            am.CameraUpdate.newLatLngZoom(am.LatLng(yo.lat, yo.lng), 16));
      } else if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
              content: Text('No pudimos obtener tu ubicación')));
      }
    } catch (_) {}
    if (mounted) setState(() => _buscando = false);
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    final controles = Column(mainAxisSize: MainAxisSize.min, children: [
      Material(
        color: colors.surface,
        elevation: 3,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _boton(Icons.add_rounded,
              () => _ctrl?.animateCamera(am.CameraUpdate.zoomIn())),
          Container(width: 26, height: 0.6, color: colors.divider),
          _boton(Icons.remove_rounded,
              () => _ctrl?.animateCamera(am.CameraUpdate.zoomOut())),
        ]),
      ),
      const SizedBox(height: 10),
      Material(
        color: colors.surface,
        elevation: 3,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _buscando ? null : _miUbicacion,
          child: SizedBox(
            width: 44,
            height: 44,
            child: _buscando
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.primary))
                : Icon(Icons.my_location, size: 20, color: colors.primary),
          ),
        ),
      ),
    ]);

    return Stack(fit: StackFit.expand, children: [
      am.AppleMap(
        initialCameraPosition: am.CameraPosition(
          target: am.LatLng(widget.centro.latitude, widget.centro.longitude),
          zoom: widget.zoom,
        ),
        onMapCreated: (c) {
          _ctrl = c;
          AppleMapKit.aplicarEstilo();
        },
        myLocationEnabled: true,
        compassEnabled: false,
        onTap: widget.onTap == null
            ? null
            : (p) => widget.onTap!(ll.LatLng(p.latitude, p.longitude)),
        annotations: {
          if (pin != null)
            am.Annotation(
              annotationId: am.AnnotationId('pin'),
              position: am.LatLng(pin.latitude, pin.longitude),
              icon: _pinOkventin != null
                  ? am.BitmapDescriptor.fromBytes(_pinOkventin!)
                  : am.BitmapDescriptor.markerAnnotation,
              anchor: const Offset(0.5, 1.0),
            ),
        },
        circles: {
          if (pin != null && (widget.radioMetros ?? 0) > 0)
            am.Circle(
              circleId: am.CircleId('radio'),
              center: am.LatLng(pin.latitude, pin.longitude),
              radius: widget.radioMetros!,
              fillColor: colors.primary.withValues(alpha: 0.12),
              strokeColor: colors.primary.withValues(alpha: 0.6),
              strokeWidth: 2,
            ),
        },
      ),
      widget.controlesAlCentro
          ? Align(
              alignment: Alignment.centerRight,
              child: Padding(
                  padding: const EdgeInsets.only(right: 10), child: controles))
          : Positioned(right: 10, bottom: 10, child: controles),
    ]);
  }

  Widget _boton(IconData i, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(i, size: 22, color: colors.textPrimary),
        ),
      );
}
