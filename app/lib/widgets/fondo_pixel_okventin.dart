import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fondo animado en pixel art para el chat de Comunidad: Okventín camina
/// sin fin por la ciudad. Es una pequeña historia en loop de 18 s:
///
///   camina → se detiene y mira hacia arriba (le aparece una estrellita) →
///   camina → salta (con un ✓ de "venta") → camina → llega a una casa y
///   entrega un paquete (sale un corazón) → sigue caminando… y vuelve a
///   empezar.
///
/// Se dibuja a "baja resolución" (cada píxel lógico = [escala] píxeles
/// reales) para que se vea pixel art, y anima a 12 cuadros por segundo, lo
/// justo para que se vea como un gif sin gastar batería. Con [activo] en
/// false se pausa.
class FondoPixelOkventin extends StatefulWidget {
  final bool activo;
  final double escala;
  final double opacidad;

  const FondoPixelOkventin({
    super.key,
    this.activo = true,
    this.escala = 3,
    this.opacidad = 0.55,
  });

  @override
  State<FondoPixelOkventin> createState() => _FondoPixelOkventinState();
}

class _FondoPixelOkventinState extends State<FondoPixelOkventin> {
  final _t = ValueNotifier<double>(0);
  Timer? _reloj;
  final _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    _sincronizar();
  }

  @override
  void didUpdateWidget(covariant FondoPixelOkventin old) {
    super.didUpdateWidget(old);
    if (old.activo != widget.activo) _sincronizar();
  }

  void _sincronizar() {
    _reloj?.cancel();
    if (!widget.activo) return;
    _reloj = Timer.periodic(const Duration(milliseconds: 83), (_) {
      _t.value = DateTime.now().difference(_inicio).inMilliseconds / 1000.0;
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Opacity(
        opacity: widget.opacidad,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _PintorPixel(_t, widget.escala, oscuro),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

// ── La historia ─────────────────────────────────────────────────────────────

const double _kCiclo = 18; // segundos
const double _kVel = 14; // píxeles lógicos por segundo al caminar

enum _Accion { caminar, mirar, saltar, entregar }

class _Tramo {
  final double desde, hasta;
  final _Accion accion;
  const _Tramo(this.desde, this.hasta, this.accion);
  bool get quieto => accion == _Accion.mirar || accion == _Accion.entregar;
}

const _tramos = [
  _Tramo(0, 3.5, _Accion.caminar),
  _Tramo(3.5, 5.5, _Accion.mirar),
  _Tramo(5.5, 8.5, _Accion.caminar),
  _Tramo(8.5, 9.6, _Accion.saltar),
  _Tramo(9.6, 12.5, _Accion.caminar),
  _Tramo(12.5, 15.5, _Accion.entregar),
  _Tramo(15.5, 18, _Accion.caminar),
];

_Tramo _tramoEn(double t) =>
    _tramos.firstWhere((r) => t >= r.desde && t < r.hasta,
        orElse: () => _tramos.last);

/// Cuánto ha avanzado el mundo hasta el segundo [t] del ciclo.
double _avance(double t) {
  var x = 0.0;
  for (final r in _tramos) {
    if (t <= r.desde) break;
    final fin = math.min(t, r.hasta);
    if (!r.quieto) x += (fin - r.desde) * _kVel;
  }
  return x;
}

final double _avanceCiclo = _avance(_kCiclo);

// ── Paleta ─────────────────────────────────────────────────────────────────

const _blanco = Color(0xFFFFFFFF);
const _rojo = Color(0xFFE53935);
const _rojoOsc = Color(0xFFB71C1C);
const _negro = Color(0xFF1C1C1E);
const _gris = Color(0xFFBDBDC4);
const _cafe = Color(0xFFC08A4E);
const _cafeOsc = Color(0xFF8A5A2B);
const _verde = Color(0xFF34C759);
const _amarillo = Color(0xFFFFC93C);

class _PintorPixel extends CustomPainter {
  final ValueNotifier<double> reloj;
  final double s;
  final bool oscuro;
  _PintorPixel(this.reloj, this.s, this.oscuro) : super(repaint: reloj);

  late Canvas _c;
  final _p = Paint()..isAntiAlias = false;

  /// Un "píxel" (o bloque) en coordenadas lógicas.
  void _px(double x, double y, double w, double h, Color color) {
    _p.color = color;
    _c.drawRect(
        Rect.fromLTWH((x.floorToDouble()) * s, (y.floorToDouble()) * s,
            w * s, h * s),
        _p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _c = canvas;
    final w = size.width / s;
    final h = size.height / s;
    final vuelta = (reloj.value / _kCiclo).floor();
    final t = reloj.value % _kCiclo;
    // Avance total (el mundo nunca "salta" al reiniciar el ciclo).
    final mundo = vuelta * _avanceCiclo + _avance(t);
    final suelo = h - 8;

    _cielo(w, suelo);
    _nubes(w, mundo * 0.15);
    _edificios(w, suelo, mundo * 0.4);
    _vereda(w, h, suelo, mundo);

    // La casa de la entrega llega justo cuando empieza "entregar".
    final xOk = (w * 0.3).floorToDouble();
    final casaMundo = vuelta * _avanceCiclo + _avance(12.5) + 24;
    final xCasa = xOk + (casaMundo - mundo);
    if (xCasa > -40 && xCasa < w + 40) _casa(xCasa, suelo);

    final tramo = _tramoEn(t);
    final local = t - tramo.desde;
    var y = suelo - 24;
    if (tramo.accion == _Accion.saltar) {
      final d = tramo.hasta - tramo.desde;
      y -= 4 * 10 * (local / d) * (1 - local / d); // parábola, 10 px de alto
    }
    final paso = ((reloj.value * 6).floor() % 2) == 0;
    _okventin(xOk, y, tramo.accion, paso, local);

    // Detalles de la historia
    if (tramo.accion == _Accion.mirar) {
      final brillo = ((local * 4).floor() % 2) == 0;
      _estrella(xOk + 8, y - 10 - local * 2, brillo);
    }
    if (tramo.accion == _Accion.saltar) {
      _check(xOk + 18, y - 4);
    }
    if (tramo.accion == _Accion.entregar && local > 1.3) {
      _corazon(xOk + 22, y - 4 - (local - 1.3) * 3);
    }
  }

  // ── Escenario ──────────────────────────────────────────────────────────

  void _cielo(double w, double suelo) {
    final arriba = oscuro ? const Color(0xFF15161C) : const Color(0xFFF4F5F9);
    final abajo = oscuro ? const Color(0xFF22242E) : const Color(0xFFE9EBF2);
    // Franjas (degradado "en escalones", estilo pixel)
    const n = 6;
    for (var i = 0; i < n; i++) {
      final y0 = suelo * i / n;
      _px(0, y0, w + 1, suelo / n + 1, Color.lerp(arriba, abajo, i / (n - 1))!);
    }
  }

  void _nubes(double w, double desplaz) {
    final c = oscuro ? const Color(0xFF2E3140) : _blanco;
    const sep = 70.0;
    for (var i = -1; i < w / sep + 2; i++) {
      final x = i * sep - (desplaz % sep);
      final y = 8 + (i.isEven ? 0 : 7);
      _px(x + 2, y.toDouble(), 10, 2, c);
      _px(x, y + 2.0, 16, 3, c);
      _px(x + 5, y - 2.0, 5, 2, c);
    }
  }

  void _edificios(double w, double suelo, double desplaz) {
    final base = oscuro ? const Color(0xFF2B2E3A) : const Color(0xFFDCDFE8);
    final ventana = oscuro ? const Color(0xFF4A4F63) : const Color(0xFFF7F8FB);
    const sep = 34.0;
    const altos = [26.0, 38.0, 20.0, 32.0, 44.0];
    for (var i = -1; i < w / sep + 2; i++) {
      final idx = ((i + (desplaz / sep).floor()) % altos.length).abs();
      final alto = altos[idx];
      final x = i * sep - (desplaz % sep);
      _px(x, suelo - alto, 26, alto, base);
      for (var vy = suelo - alto + 4; vy < suelo - 4; vy += 6) {
        for (var vx = x + 4; vx < x + 22; vx += 7) {
          _px(vx, vy, 3, 3, ventana);
        }
      }
    }
  }

  void _vereda(double w, double h, double suelo, double desplaz) {
    _px(0, suelo, w + 1, h - suelo + 1,
        oscuro ? const Color(0xFF3A3D4A) : const Color(0xFFCFD2DA));
    _px(0, suelo, w + 1, 1, oscuro ? const Color(0xFF555A6B) : _gris);
    // Juntas de la vereda que pasan (dan la sensación de caminar)
    const sep = 12.0;
    final c = oscuro ? const Color(0xFF2E313C) : const Color(0xFFB9BCC6);
    for (var i = -1; i < w / sep + 2; i++) {
      final x = i * sep - (desplaz % sep);
      _px(x, suelo + 3, 1, h - suelo - 3, c);
    }
  }

  void _casa(double x, double suelo) {
    final pared = oscuro ? const Color(0xFF8E8E93) : const Color(0xFFF2E3C9);
    _px(x, suelo - 18, 22, 18, pared);
    // techo
    for (var i = 0; i < 7; i++) {
      _px(x - 2 + i, suelo - 19 - i, 26 - i * 2, 1, _rojoOsc);
    }
    _px(x + 13, suelo - 11, 6, 11, _cafeOsc); // puerta
    _px(x + 17, suelo - 6, 1, 1, _amarillo); // manilla
    _px(x + 3, suelo - 13, 6, 5, const Color(0xFF9AD0F5)); // ventana
  }

  // ── Okventín ───────────────────────────────────────────────────────────

  void _okventin(double x, double y, _Accion a, bool paso, double local) {
    // Manillas
    _px(x + 4, y, 6, 1, _rojo);
    _px(x + 3, y + 1, 1, 3, _rojo);
    _px(x + 10, y + 1, 1, 3, _rojo);
    // Cuerpo (bolsa) con el costado rojo
    _px(x, y + 4, 14, 14, _blanco);
    _px(x, y + 4, 2, 14, _rojo);
    _px(x, y + 18, 14, 1, _gris);
    _px(x + 14, y + 4, 1, 14, _gris);

    // Cara
    final arriba = a == _Accion.mirar;
    final ojoY = y + (arriba ? 5 : 6);
    _px(x + 5, ojoY, 1, 2, _negro);
    _px(x + 9, ojoY, 1, 2, _negro);
    if (!arriba) {
      _px(x + 6, y + 11, 3, 1, _negro); // sonrisa
      _px(x + 5, y + 10, 1, 1, _negro);
      _px(x + 9, y + 10, 1, 1, _negro);
    } else {
      _px(x + 7, y + 10, 1, 1, _negro); // "o" de sorpresa
    }
    // "OK" chiquito
    _px(x + 4, y + 14, 3, 1, _rojo);
    _px(x + 4, y + 15, 1, 1, _rojo);
    _px(x + 6, y + 15, 1, 1, _rojo);
    _px(x + 4, y + 16, 3, 1, _rojo);
    _px(x + 8, y + 14, 1, 3, _rojo);
    _px(x + 9, y + 15, 1, 1, _rojo);
    _px(x + 10, y + 14, 1, 1, _rojo);
    _px(x + 10, y + 16, 1, 1, _rojo);

    // Brazos
    switch (a) {
      case _Accion.saltar:
        _px(x - 1, y + 5, 1, 5, _negro);
        _px(x + 15, y + 5, 1, 5, _negro);
        _px(x - 2, y + 4, 2, 2, _blanco);
        _px(x + 15, y + 4, 2, 2, _blanco);
        break;
      case _Accion.entregar:
        // Ambos brazos adelante con el paquete; después de entregar, saluda.
        if (local < 1.3) {
          _px(x + 15, y + 11, 3, 1, _negro);
          _caja(x + 17 + local * 3, y + 8);
        } else {
          _caja(x + 21, y + 8 + math.min(6.0, (local - 1.3) * 12));
          final saludo = ((local * 5).floor() % 2) == 0;
          _px(x + 15, y + (saludo ? 6 : 7), 1, 4, _negro);
          _px(x + 15, y + (saludo ? 5 : 6), 2, 2, _blanco);
        }
        _px(x - 1, y + 10, 1, 4, _negro);
        break;
      default:
        final dy = a == _Accion.caminar && paso ? 1.0 : 0.0;
        _px(x - 1, y + 10 + dy, 1, 4, _negro);
        _px(x + 15, y + 11 - dy, 1, 4, _negro);
        _px(x - 2, y + 14 + dy, 2, 1, _blanco);
        _px(x + 15, y + 15 - dy, 2, 1, _blanco);
    }

    // Piernas y zapatillas rojas
    if (a == _Accion.saltar) {
      _px(x + 4, y + 19, 1, 2, _negro);
      _px(x + 9, y + 19, 1, 2, _negro);
      _zapatilla(x + 3, y + 21);
      _zapatilla(x + 8, y + 21);
    } else {
      final mover = a == _Accion.caminar;
      final ai = mover && paso ? -1.0 : 0.0;
      final ad = mover && !paso ? 1.0 : 0.0;
      _px(x + 4 + ai, y + 19, 1, 3, _negro);
      _px(x + 9 + ad, y + 19, 1, 3, _negro);
      _zapatilla(x + 3 + ai, y + 22);
      _zapatilla(x + 8 + ad, y + 22);
    }
  }

  void _zapatilla(double x, double y) {
    _px(x, y, 4, 2, _rojo);
    _px(x, y + 1, 4, 1, _blanco);
  }

  void _caja(double x, double y) {
    _px(x, y, 6, 5, _cafe);
    _px(x, y, 6, 1, _cafeOsc);
    _px(x + 2, y, 2, 5, const Color(0xFFE8D2A8)); // cinta
  }

  void _estrella(double x, double y, bool brillo) {
    final c = brillo ? _amarillo : const Color(0xFFFFE08A);
    _px(x + 2, y, 1, 5, c);
    _px(x, y + 2, 5, 1, c);
    if (brillo) {
      _px(x + 1, y + 1, 1, 1, c);
      _px(x + 3, y + 3, 1, 1, c);
      _px(x + 3, y + 1, 1, 1, c);
      _px(x + 1, y + 3, 1, 1, c);
    }
  }

  void _check(double x, double y) {
    _px(x, y + 3, 1, 1, _verde);
    _px(x + 1, y + 4, 1, 1, _verde);
    _px(x + 2, y + 3, 1, 1, _verde);
    _px(x + 3, y + 2, 1, 1, _verde);
    _px(x + 4, y + 1, 1, 1, _verde);
    _px(x + 5, y, 1, 1, _verde);
  }

  void _corazon(double x, double y) {
    _px(x + 1, y, 2, 1, _rojo);
    _px(x + 4, y, 2, 1, _rojo);
    _px(x, y + 1, 7, 2, _rojo);
    _px(x + 1, y + 3, 5, 1, _rojo);
    _px(x + 2, y + 4, 3, 1, _rojo);
    _px(x + 3, y + 5, 1, 1, _rojo);
  }

  @override
  bool shouldRepaint(covariant _PintorPixel old) =>
      old.s != s || old.oscuro != oscuro;
}
