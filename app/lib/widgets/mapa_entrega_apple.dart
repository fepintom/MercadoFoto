import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:apple_maps_flutter/apple_maps_flutter.dart' as am;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart' as ll;

import '../services/apple_mapkit.dart';
import '../theme/app_theme.dart';
import 'pines_apple.dart';

/// Mapa de una entrega en iPhone (Apple Maps): dibuja la ruta en auto
/// desde [origen] hasta [destino] y muestra tiempo y distancia. La ruta se
/// recalcula cuando el origen avanza. Trae + / − y "ver ruta completa".
class MapaEntregaApple extends StatefulWidget {
  /// Quien se mueve (yo, el vendedor o el repartidor).
  final ll.LatLng? origen;
  final ll.LatLng? destino;

  /// true: el origen soy yo → se usa el punto azul de Apple.
  final bool origenSoyYo;
  final IconData iconoOrigen;
  final Color colorOrigen;
  final IconData iconoDestino;

  const MapaEntregaApple({
    super.key,
    required this.origen,
    required this.destino,
    this.origenSoyYo = true,
    this.iconoOrigen = Icons.directions_car_rounded,
    this.colorOrigen = Colors.green,
    this.iconoDestino = Icons.location_on_rounded,
  });

  @override
  State<MapaEntregaApple> createState() => _MapaEntregaAppleState();
}

class _MapaEntregaAppleState extends State<MapaEntregaApple> {
  am.AppleMapController? _ctrl;
  RutaApple? _ruta;
  ll.LatLng? _origenRuta;
  ll.LatLng? _destinoRuta;
  bool _encuadrado = false;
  bool _calculando = false;
  Uint8List? _pinOrigen;
  Uint8List? _pinDestino;
  Timer? _cada;

  @override
  void initState() {
    super.initState();
    _prepararPines();
    _recalcular();
    // Por si el tráfico cambia el tiempo estimado.
    _cada = Timer.periodic(
        const Duration(seconds: 90), (_) => _recalcular(forzar: true));
  }

  @override
  void didUpdateWidget(covariant MapaEntregaApple old) {
    super.didUpdateWidget(old);
    _recalcular();
  }

  @override
  void dispose() {
    _cada?.cancel();
    super.dispose();
  }

  Future<void> _prepararPines() async {
    // Destino: el pin de Okventín (el mismo de Encontrar y ubicaciones).
    Uint8List? d;
    try {
      d = (await rootBundle.load('assets/images/okventin_pin_mapa.png'))
          .buffer
          .asUint8List();
    } catch (_) {
      d = await PinesApple.circulo(
          clave: 'entrega_dest_${widget.iconoDestino.codePoint}',
          icono: widget.iconoDestino,
          color: colors.primary);
    }
    Uint8List? o;
    if (!widget.origenSoyYo) {
      o = await PinesApple.circulo(
          clave:
              'entrega_orig_${widget.iconoOrigen.codePoint}_${widget.colorOrigen.toARGB32()}',
          icono: widget.iconoOrigen,
          color: widget.colorOrigen);
    }
    if (mounted) {
      setState(() {
        _pinDestino = d;
        _pinOrigen = o;
      });
    }
  }

  static double _metros(ll.LatLng a, ll.LatLng b) =>
      ll.Distance().as(ll.LengthUnit.Meter, a, b);

  Future<void> _recalcular({bool forzar = false}) async {
    final o = widget.origen, d = widget.destino;
    if (o == null || d == null || _calculando) return;
    final mismoDestino = _destinoRuta != null && _metros(_destinoRuta!, d) < 15;
    final poco = _origenRuta != null && _metros(_origenRuta!, o) < 60;
    if (!forzar && mismoDestino && poco && _ruta != null) return;
    _calculando = true;
    final r = await AppleMapKit.ruta(
        desdeLat: o.latitude,
        desdeLng: o.longitude,
        hastaLat: d.latitude,
        hastaLng: d.longitude);
    _calculando = false;
    if (!mounted) return;
    if (r != null) {
      setState(() {
        _ruta = r;
        _origenRuta = o;
        _destinoRuta = d;
      });
      if (!_encuadrado) {
        _encuadrado = true;
        _verTodo();
      }
    } else if (!_encuadrado) {
      _encuadrado = true;
      _verTodo();
    }
  }

  /// Encuadra la ruta completa (o origen y destino si aún no hay ruta).
  void _verTodo() {
    final c = _ctrl;
    if (c == null) return;
    final pts = <(double, double)>[
      ...?_ruta?.puntos,
      if (widget.origen != null)
        (widget.origen!.latitude, widget.origen!.longitude),
      if (widget.destino != null)
        (widget.destino!.latitude, widget.destino!.longitude),
    ];
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      c.animateCamera(am.CameraUpdate.newLatLngZoom(
          am.LatLng(pts.first.$1, pts.first.$2), 15));
      return;
    }
    var s = pts.first.$1, n = s, w = pts.first.$2, e = w;
    for (final (la, ln) in pts) {
      s = math.min(s, la);
      n = math.max(n, la);
      w = math.min(w, ln);
      e = math.max(e, ln);
    }
    if ((n - s) < 0.003 && (e - w) < 0.003) {
      c.animateCamera(am.CameraUpdate.newLatLngZoom(
          am.LatLng((s + n) / 2, (w + e) / 2), 16));
      return;
    }
    c.animateCamera(am.CameraUpdate.newLatLngBounds(
        am.LatLngBounds(
            southwest: am.LatLng(s, w), northeast: am.LatLng(n, e)),
        50));
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.origen, d = widget.destino;
    final inicio = o ?? d ?? ll.LatLng(-33.45, -70.66);
    final r = _ruta;
    return Stack(
      fit: StackFit.expand,
      children: [
        am.AppleMap(
          initialCameraPosition: am.CameraPosition(
              target: am.LatLng(inicio.latitude, inicio.longitude), zoom: 14),
          onMapCreated: (c) {
            _ctrl = c;
            AppleMapKit.aplicarEstilo();
            if (_ruta != null || (o != null && d != null)) {
              Future.delayed(const Duration(milliseconds: 300), _verTodo);
            }
          },
          myLocationEnabled: widget.origenSoyYo,
          compassEnabled: false,
          annotations: {
            if (d != null)
              am.Annotation(
                annotationId: am.AnnotationId('destino'),
                position: am.LatLng(d.latitude, d.longitude),
                icon: _pinDestino != null
                    ? am.BitmapDescriptor.fromBytes(_pinDestino!)
                    : am.BitmapDescriptor.markerAnnotation,
                anchor: const Offset(0.5, 1.0),
              ),
            if (o != null && !widget.origenSoyYo)
              am.Annotation(
                annotationId: am.AnnotationId('origen'),
                position: am.LatLng(o.latitude, o.longitude),
                icon: _pinOrigen != null
                    ? am.BitmapDescriptor.fromBytes(_pinOrigen!)
                    : am.BitmapDescriptor.defaultAnnotation,
                anchor: const Offset(0.5, 0.5),
                zIndex: 10,
              ),
          },
          polylines: {
            if (r != null)
              am.Polyline(
                polylineId: am.PolylineId('ruta'),
                points: [for (final (la, ln) in r.puntos) am.LatLng(la, ln)],
                color: const Color(0xFF0A84FF),
                width: 6,
              ),
          },
        ),
        // Tiempo y distancia
        if (r != null)
          Positioned(
            left: 10,
            top: 10,
            child: Material(
              color: colors.surface,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.directions_car_rounded,
                      size: 18, color: Color(0xFF0A84FF)),
                  const SizedBox(width: 6),
                  Text('${r.tiempo} · ${r.distancia}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary)),
                ]),
              ),
            ),
          ),
        // + / − y ver ruta completa
        Positioned(
          right: 10,
          bottom: 10,
          child: Material(
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
              Container(width: 26, height: 0.6, color: colors.divider),
              _boton(Icons.route_rounded, _verTodo),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _boton(IconData i, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(i, size: 21, color: colors.textPrimary),
        ),
      );
}
