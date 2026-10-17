import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Fila horizontal que avisa hacia dónde se puede deslizar:
/// - una flechita ‹ › en el borde que tiene más contenido (se toca para
///   avanzar),
/// - el borde se desvanece solo de ese lado,
/// - una barrita abajo muestra en qué parte de la fila estás,
/// - la primera vez da un pequeño "empujoncito" para que se note que se
///   mueve.
class FilaConGuia extends StatefulWidget {
  final List<Widget> children;
  final EdgeInsets padding;

  /// Distancia desde arriba al centro de las flechas (para alinearlas con
  /// los círculos y no con el texto de abajo).
  final double centroFlechas;

  /// Color del fondo, para el degradado de los bordes.
  final Color? fondo;

  /// Si los botones caben, ¿se centran? (false = pegados a la izquierda).
  final bool centrar;

  /// Cuando sube (p. ej. se agregó un filtro), la fila se desliza hasta el
  /// final para mostrar lo nuevo.
  final int version;

  const FilaConGuia({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(10, 8, 14, 4),
    this.centroFlechas = 32,
    this.fondo,
    this.centrar = true,
    this.version = 0,
  });

  @override
  State<FilaConGuia> createState() => _FilaConGuiaState();
}

class _FilaConGuiaState extends State<FilaConGuia> {
  final _ctrl = ScrollController();
  bool _izq = false;
  bool _der = false;
  double _frac = 0; // 0..1 posición
  double _vista = 1; // fracción visible
  static bool _yaEmpujo = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_revisar);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revisar();
      _empujoncito();
    });
  }

  @override
  void didUpdateWidget(covariant FilaConGuia old) {
    super.didUpdateWidget(old);
    if (widget.version > old.version) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_ctrl.hasClients) return;
        _ctrl.animateTo(_ctrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _empujoncito() async {
    if (_yaEmpujo || !mounted || !_ctrl.hasClients) return;
    if (_ctrl.position.maxScrollExtent < 30) return;
    _yaEmpujo = true;
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted || !_ctrl.hasClients || _ctrl.offset > 0) return;
    await _ctrl.animateTo(46,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic);
    if (!mounted || !_ctrl.hasClients) return;
    await _ctrl.animateTo(0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic);
  }

  void _revisar() {
    if (!mounted || !_ctrl.hasClients) return;
    final p = _ctrl.position;
    final izq = p.pixels > 6;
    final der = p.maxScrollExtent - p.pixels > 6;
    final total = p.maxScrollExtent + p.viewportDimension;
    final vista = total <= 0 ? 1.0 : (p.viewportDimension / total);
    final frac = p.maxScrollExtent <= 0
        ? 0.0
        : (p.pixels / p.maxScrollExtent).clamp(0.0, 1.0).toDouble();
    if (izq != _izq || der != _der || (frac - _frac).abs() > 0.01 ||
        (vista - _vista).abs() > 0.01) {
      setState(() {
        _izq = izq;
        _der = der;
        _frac = frac;
        _vista = vista;
      });
    }
  }

  void _avanzar(int dir) {
    if (!_ctrl.hasClients) return;
    HapticFeedback.selectionClick();
    final p = _ctrl.position;
    final destino = (p.pixels + dir * p.viewportDimension * 0.7)
        .clamp(0.0, p.maxScrollExtent)
        .toDouble();
    _ctrl.animateTo(destino,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic);
  }

  Widget _flecha(int dir, bool visible) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: GestureDetector(
          onTap: () => _avanzar(dir),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: colors.divider),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 1)),
              ],
            ),
            child: Icon(
                dir < 0
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 20,
                color: colors.primary),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hayMas = _izq || _der;
    return Stack(children: [
      Positioned.fill(
        child: ShaderMask(
          shaderCallback: (r) => LinearGradient(
            colors: [
              _izq ? Colors.transparent : Colors.white,
              Colors.white,
              Colors.white,
              _der ? Colors.transparent : Colors.white,
            ],
            stops: const [0, 0.07, 0.93, 1],
          ).createShader(r),
          blendMode: BlendMode.dstIn,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _revisar());
              return false;
            },
            // Si los botones caben, quedan centrados; si son más, se
            // llenan hacia los lados y la fila se desliza.
            child: LayoutBuilder(
              builder: (_, c) => SingleChildScrollView(
                controller: _ctrl,
                scrollDirection: Axis.horizontal,
                padding: widget.padding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minWidth: (c.maxWidth - widget.padding.horizontal)
                          .clamp(0.0, double.infinity)
                          .toDouble()),
                  child: Row(
                    mainAxisAlignment: widget.centrar
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    crossAxisAlignment: widget.centrar
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: widget.children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: 2,
        top: widget.centroFlechas - 12,
        child: _flecha(-1, _izq),
      ),
      Positioned(
        right: 2,
        top: widget.centroFlechas - 12,
        child: _flecha(1, _der),
      ),
      // Barrita de posición: dice "hay más" y dónde estás.
      if (hayMas)
        Positioned(
          left: 0,
          right: 0,
          bottom: 1,
          child: Center(
            child: SizedBox(
              width: 46,
              height: 3,
              child: LayoutBuilder(builder: (_, c) {
                final w = (c.maxWidth * _vista).clamp(10.0, c.maxWidth);
                return Stack(children: [
                  Container(
                    decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Positioned(
                    left: (c.maxWidth - w) * _frac,
                    width: w,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ]);
              }),
            ),
          ),
        ),
    ]);
  }
}
