import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';

/// Botones del mapa, iguales en toda la app: acercar (+), alejar (−) y
/// "mi ubicación". Van flotando sobre el mapa, a la derecha.
class ControlesMapa extends StatefulWidget {
  final MapController controller;

  /// Si se pasa, reemplaza el "ir a mi ubicación" por defecto (p. ej. en
  /// Encontrar, que además vuelve a calcular lo que hay cerca).
  final Future<void> Function()? onMiUbicacion;
  final bool cargandoUbicacion;

  const ControlesMapa({
    super.key,
    required this.controller,
    this.onMiUbicacion,
    this.cargandoUbicacion = false,
  });

  /// Pone los controles sobre un mapa (abajo a la derecha, o al centro a la
  /// derecha si [alCentro]).
  static Widget sobre({
    required MapController controller,
    required Widget mapa,
    bool alCentro = false,
    Future<void> Function()? onMiUbicacion,
  }) {
    final c = ControlesMapa(controller: controller, onMiUbicacion: onMiUbicacion);
    return Stack(fit: StackFit.expand, children: [
      mapa,
      alCentro
          ? Align(
              alignment: Alignment.centerRight,
              child: Padding(padding: const EdgeInsets.only(right: 10), child: c))
          : Positioned(right: 10, bottom: 10, child: c),
    ]);
  }

  @override
  State<ControlesMapa> createState() => _ControlesMapaState();
}

class _ControlesMapaState extends State<ControlesMapa> {
  bool _buscando = false;

  void _zoom(double delta) {
    final c = widget.controller;
    try {
      final z = (c.zoom + delta).clamp(3.0, 19.0).toDouble();
      c.move(c.center, z);
    } catch (_) {}
  }

  Future<void> _miUbicacion() async {
    if (widget.onMiUbicacion != null) {
      await widget.onMiUbicacion!();
      return;
    }
    setState(() => _buscando = true);
    try {
      final yo = await UbicacionService.obtener(usarCache: false);
      if (yo != null) {
        final c = widget.controller;
        c.move(ll.LatLng(yo.lat, yo.lng), c.zoom < 15 ? 15 : c.zoom);
      } else if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
              content: Text('No pudimos obtener tu ubicación')));
      }
    } catch (_) {}
    if (mounted) setState(() => _buscando = false);
  }

  Widget _boton(IconData icono, VoidCallback onTap, {String? tip}) {
    return Tooltip(
      message: tip ?? '',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icono, size: 22, color: colors.textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cargando = _buscando || widget.cargandoUbicacion;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // + y − juntos, en una pastilla
      Material(
        color: colors.surface,
        elevation: 3,
        borderRadius: BorderRadius.circular(21),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _boton(Icons.add_rounded, () => _zoom(1), tip: 'Acercar'),
          Container(width: 26, height: 1, color: colors.divider),
          _boton(Icons.remove_rounded, () => _zoom(-1), tip: 'Alejar'),
        ]),
      ),
      const SizedBox(height: 10),
      // Mi ubicación
      Material(
        color: colors.surface,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: cargando ? null : _miUbicacion,
          child: SizedBox(
            width: 42,
            height: 42,
            child: cargando
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.primary))
                : Icon(Icons.my_location_rounded,
                    size: 20, color: colors.primary),
          ),
        ),
      ),
    ]);
  }
}
