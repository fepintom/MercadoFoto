import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "Desliza hacia abajo para actualizar", igual en toda la app.
///
/// Al tirar hacia abajo aparece arriba una pastilla con un círculo rojo y
/// la flecha de actualizar (mismo estilo de íconos redondeados de la app):
///   · tirando          → "Desliza para actualizar" (la flecha gira)
///   · listo para soltar → "Suelta para actualizar"
///   · actualizando      → la flecha gira sola + "Actualizando…"
class RefrescoOk extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  /// Distancia desde arriba donde aparece la pastilla.
  final double arriba;

  // Compatibilidad con RefreshIndicator (se ignoran: el estilo es único).
  final Color? color;
  final Color? backgroundColor;

  const RefrescoOk({
    super.key,
    required this.onRefresh,
    required this.child,
    this.arriba = 10,
    this.color,
    this.backgroundColor,
  });

  @override
  State<RefrescoOk> createState() => _RefrescoOkState();
}

class _RefrescoOkState extends State<RefrescoOk>
    with SingleTickerProviderStateMixin {
  RefreshIndicatorStatus? _estado;
  double _tiron = 0; // 0..1 cuánto se ha tirado
  late final AnimationController _giro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  Future<void> _actualizar() async {
    _giro.repeat();
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _giro.stop();
        _giro.reset();
      }
    }
  }

  bool _alScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    // En iPhone el tirón se ve como scroll negativo (rebote).
    final sobre = n.metrics.minScrollExtent - n.metrics.pixels;
    final t = (sobre / 90).clamp(0.0, 1.0);
    if ((t - _tiron).abs() > 0.02) setState(() => _tiron = t);
    if (n is OverscrollNotification && n.overscroll < 0) {
      // Android (sin rebote): sumar el tirón.
      setState(() => _tiron = (_tiron + (-n.overscroll / 90)).clamp(0.0, 1.0));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final e = _estado;
    final actualizando =
        e == RefreshIndicatorStatus.refresh || e == RefreshIndicatorStatus.snap;
    final visible = e == RefreshIndicatorStatus.drag ||
        e == RefreshIndicatorStatus.armed ||
        actualizando;
    final texto = actualizando
        ? 'Actualizando…'
        : e == RefreshIndicatorStatus.armed
            ? 'Suelta para actualizar'
            : 'Desliza para actualizar';
    final escala = actualizando ? 1.0 : (0.6 + 0.4 * _tiron);

    return Stack(children: [
      NotificationListener<ScrollNotification>(
        onNotification: _alScroll,
        child: RefreshIndicator.noSpinner(
          onRefresh: _actualizar,
          onStatusChange: (s) {
            if (!mounted) return;
            setState(() {
              _estado = s;
              if (s == null ||
                  s == RefreshIndicatorStatus.done ||
                  s == RefreshIndicatorStatus.canceled) {
                _tiron = 0;
              }
            });
          },
          child: widget.child,
        ),
      ),
      Positioned(
        top: widget.arriba,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: AnimatedScale(
                scale: visible ? escala : 0.6,
                duration: const Duration(milliseconds: 120),
                child: Material(
                  color: colors.surface,
                  elevation: 4,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedBuilder(
                          animation: _giro,
                          builder: (_, child) => Transform.rotate(
                            angle: actualizando
                                ? _giro.value * 2 * math.pi
                                : _tiron * 1.5 * math.pi,
                            child: child,
                          ),
                          child: const Icon(Icons.refresh_rounded,
                              size: 20, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(texto,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
