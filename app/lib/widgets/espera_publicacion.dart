import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;

import 'package:flutter/services.dart';

import '../services/borradores_service.dart';
import '../theme/app_theme.dart';
import 'juegos/okventa_invaders.dart';
import 'juegos/okventa_memorice.dart';

/// Pantalla de espera mientras se analiza o se publica un producto.
///
/// No todos quieren jugar, así que se ofrece elegir:
///
///   ┌───────────────┬───────────────┐
///   │   🎮 Jugar    │  ⏱ Esperar   │   ← tiempo estimado (aprende de las
///   │ Invaders /    │    0:09       │     veces anteriores en el teléfono)
///   │  Memorice     │               │
///   └───────────────┴───────────────┘
///          ↑ Desliza para seguir mirando OkMarket
///
/// Deslizar hacia arriba llama a [onSeguirMirando]: la pantalla se cierra y
/// el trabajo sigue en segundo plano (lo que no se alcance a publicar queda
/// en Borradores).
class EsperaPublicacion extends StatefulWidget {
  /// 'analizar' | 'publicar' (para estimar el tiempo).
  final String etapa;
  final String titulo;
  final String textoDeslizar;
  final VoidCallback? onSeguirMirando;

  const EsperaPublicacion({
    super.key,
    required this.etapa,
    required this.titulo,
    this.textoDeslizar = 'Tu publicación te esperará en Borradores',
    this.onSeguirMirando,
  });

  @override
  State<EsperaPublicacion> createState() => _EsperaPublicacionState();
}

enum _Modo { inicio, elegir, invaders, memorice }

class _EsperaPublicacionState extends State<EsperaPublicacion>
    with SingleTickerProviderStateMixin {
  final _inicio = DateTime.now();
  Duration _estimado = const Duration(seconds: 12);
  Timer? _reloj;
  _Modo _modo = _Modo.inicio;
  late final AnimationController _flecha = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    BorradoresService.estimado(widget.etapa).then((d) {
      if (mounted) setState(() => _estimado = d);
    });
    _reloj = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _flecha.dispose();
    super.dispose();
  }

  Duration get _pasado => DateTime.now().difference(_inicio);
  Duration get _queda {
    final q = _estimado - _pasado;
    return q.isNegative ? Duration.zero : q;
  }

  double get _avance => (_pasado.inMilliseconds /
          math.max(1, _estimado.inMilliseconds))
      .clamp(0.0, 0.97);

  String _mmss(Duration d) {
    final s = (d.inMilliseconds / 1000).ceil();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _cabecera(),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (_modo) {
              _Modo.inicio => _dosOpciones(),
              _Modo.elegir => _elegirJuego(),
              _Modo.invaders => _conJuego(const OkVentaInvaders()),
              _Modo.memorice => _conJuego(const OkVentaMemorice()),
            },
          ),
        ),
        if (widget.onSeguirMirando != null) _deslizar(),
      ],
    );
  }

  // ── Arriba: qué pasa + barra de avance ───────────────────────────────────
  Widget _cabecera() {
    final listoYa = _queda == Duration.zero;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: colors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.titulo,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
            ),
            Text(listoYa ? 'Casi listo…' : 'Faltan ~${_mmss(_queda)}',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: colors.primary)),
          ]),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _avance,
              minHeight: 5,
              color: colors.primary,
              backgroundColor: colors.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Las dos mitades: Jugar | Esperar ─────────────────────────────────────
  Widget _dosOpciones() {
    return Padding(
      key: const ValueKey('inicio'),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _tarjetaJugar()),
          const SizedBox(width: 12),
          Expanded(child: _tarjetaEsperar()),
        ],
      ),
    );
  }

  Widget _tarjetaJugar() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _modo = _Modo.elegir);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF3B3B), Color(0xFFB30F1F)],
          ),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFE53935).withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 6)),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Align(
              alignment: Alignment.topLeft,
              child: Icon(Icons.sports_esports_rounded,
                  color: Colors.white, size: 28),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Image.asset('assets/images/okventin_compra.png',
                    fit: BoxFit.contain),
              ),
            ),
            const Text('Jugar',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text('OkVenta Invaders\nMemorice OkVenta',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaEsperar() {
    final listoYa = _queda == Duration.zero;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.divider, width: 0.8),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Icon(Icons.hourglass_bottom_rounded,
                color: colors.textPrimary, size: 26),
          ),
          Expanded(
            child: Center(
              child: LayoutBuilder(builder: (_, c) {
                final lado = math.min(c.maxWidth, c.maxHeight) * 0.9;
                return SizedBox(
                  width: lado,
                  height: lado,
                  child: Stack(fit: StackFit.expand, children: [
                    CircularProgressIndicator(
                      value: listoYa ? null : 1 - _avance,
                      strokeWidth: 7,
                      color: colors.primary,
                      backgroundColor:
                          colors.primary.withValues(alpha: 0.12),
                    ),
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(listoYa ? '¡Ya!' : _mmss(_queda),
                              style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                  color: colors.textPrimary)),
                        ),
                      ),
                    ),
                  ]),
                );
              }),
            ),
          ),
          Text('Esperar',
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(
              listoYa
                  ? 'Está tardando un poco más,\nya casi'
                  : 'Tiempo estimado\nde publicación',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 11.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Elegir juego ─────────────────────────────────────────────────────────
  Widget _elegirJuego() {
    Widget opcion(String titulo, String detalle, IconData icono, String img,
            _Modo modo) =>
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _modo = modo);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.divider, width: 0.8),
            ),
            child: Row(children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset(img, fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(icono, size: 18, color: colors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(titulo,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary)),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Text(detalle,
                        style: TextStyle(
                            fontSize: 12, color: colors.textPrimary)),
                  ],
                ),
              ),
              Icon(Icons.play_arrow_rounded,
                  size: 30, color: colors.primary),
            ]),
          ),
        );

    return ListView(
      key: const ValueKey('elegir'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      children: [
        Row(children: [
          GestureDetector(
            onTap: () => setState(() => _modo = _Modo.inicio),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: colors.textPrimary),
          ),
          const SizedBox(width: 10),
          Text('¿A qué jugamos?',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary)),
        ]),
        const SizedBox(height: 12),
        opcion(
            'OkVenta Invaders',
            'Okventín defiende el mercado de las ofertas falsas. '
                'Muévete y dispara.',
            Icons.rocket_launch_rounded,
            'assets/images/okventin.png',
            _Modo.invaders),
        const SizedBox(height: 10),
        opcion(
            'Memorice OkVenta',
            'Da vuelta las cartas y encuentra las parejas de Okventín.',
            Icons.grid_view_rounded,
            'assets/images/okventin_servicios.png',
            _Modo.memorice),
      ],
    );
  }

  Widget _conJuego(Widget juego) {
    return Column(
      key: ValueKey(_modo),
      children: [
        Container(
          color: colors.surface,
          padding: const EdgeInsets.fromLTRB(6, 2, 14, 2),
          child: Row(children: [
            TextButton.icon(
              onPressed: () => setState(() => _modo = _Modo.elegir),
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 14, color: colors.textPrimary),
              label: Text('Juegos',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
            ),
            const Spacer(),
            Icon(Icons.timer_outlined, size: 16, color: colors.primary),
            const SizedBox(width: 4),
            Text(_queda == Duration.zero ? 'Casi listo' : _mmss(_queda),
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: colors.primary)),
          ]),
        ),
        Expanded(child: juego),
      ],
    );
  }

  // ── Abajo: deslizar para seguir mirando ──────────────────────────────────
  Widget _deslizar() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onSeguirMirando,
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -200) widget.onSeguirMirando?.call();
      },
      child: Container(
        width: double.infinity,
        color: colors.surface,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBuilder(
              animation: _flecha,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -5 * Curves.easeInOut.transform(_flecha.value)),
                child: child,
              ),
              child: Icon(Icons.keyboard_double_arrow_up_rounded,
                  color: colors.primary, size: 26),
            ),
            Text('Desliza hacia arriba para seguir mirando',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary)),
            const SizedBox(height: 2),
            Text(widget.textoDeslizar,
                style: TextStyle(fontSize: 11.5, color: colors.textPrimary)),
          ]),
        ),
      ),
    );
  }
}
