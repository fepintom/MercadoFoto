import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Stickers animados de Okventín para Comunidad (como los GIF de WhatsApp,
/// pero dibujados en vivo: pesan nada y se ven nítidos a cualquier tamaño).
///
/// Viajan como texto "[okventin:saludo]" en el mensaje, así el servidor no
/// necesita nada nuevo y en cualquier versión de la app se ve algo
/// razonable.
enum TipoSticker { saludo, celebra, lentes, pensativo, llora, enojado }

class StickerOkventin extends StatefulWidget {
  final TipoSticker tipo;
  final double tam;
  final bool animar;

  const StickerOkventin({
    super.key,
    required this.tipo,
    this.tam = 110,
    this.animar = true,
  });

  static const etiquetas = {
    TipoSticker.saludo: 'Saludando',
    TipoSticker.celebra: 'Celebrando',
    TipoSticker.lentes: 'Con lentes',
    TipoSticker.pensativo: 'Pensativo',
    TipoSticker.llora: 'Llorando',
    TipoSticker.enojado: 'Enojado',
  };

  static final _re = RegExp(r'^\[okventin:(\w+)\]$');

  /// Texto del mensaje que representa el sticker.
  static String texto(TipoSticker t) => '[okventin:${t.name}]';

  /// Si el mensaje es un sticker, cuál; si no, null.
  static TipoSticker? deTexto(String texto) {
    final m = _re.firstMatch(texto.trim());
    if (m == null) return null;
    for (final t in TipoSticker.values) {
      if (t.name == m.group(1)) return t;
    }
    return null;
  }

  @override
  State<StickerOkventin> createState() => _StickerOkventinState();
}

class _StickerOkventinState extends State<StickerOkventin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.animar) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.tam,
      height: widget.tam,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _PintorSticker(widget.tipo, _c.value),
          ),
        ),
      ),
    );
  }
}

const _rojo = Color(0xFFE53935);
const _rojoOsc = Color(0xFFC62828);
const _tinta = Color(0xFF1C1C1E);

class _PintorSticker extends CustomPainter {
  final TipoSticker tipo;
  final double t; // 0..1, se repite

  _PintorSticker(this.tipo, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Todo se dibuja en una caja lógica de 100 × 100.
    final k = size.width / 100;
    canvas.save();
    canvas.scale(k, k);
    final w = t * 2 * math.pi;

    // Movimiento de todo el cuerpo según el ánimo.
    double dx = 0, dy = 0, giro = 0;
    switch (tipo) {
      case TipoSticker.celebra:
        dy = -8 * math.sin(w * 2).abs();
        break;
      case TipoSticker.enojado:
        dx = 1.6 * math.sin(w * 12);
        break;
      case TipoSticker.lentes:
        dy = 1.5 * math.sin(w * 2);
        giro = 0.04 * math.sin(w);
        break;
      case TipoSticker.saludo:
        giro = 0.03 * math.sin(w * 2);
        break;
      case TipoSticker.llora:
        dy = 0.8 * math.sin(w * 6);
        break;
      case TipoSticker.pensativo:
        giro = -0.05;
        break;
    }

    // Sombra en el piso (se achica cuando salta).
    final sombra = 1 - (dy.abs() / 14);
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(50, 93), width: 40 * sombra, height: 5),
        Paint()..color = Colors.black.withValues(alpha: 0.12));

    canvas.translate(50 + dx, 60 + dy);
    canvas.rotate(giro);
    canvas.translate(-50, -60);

    _piernas(canvas, w);
    _brazos(canvas, w, atras: true);
    _cuerpo(canvas);
    _cara(canvas, w);
    _brazos(canvas, w, atras: false);
    _extras(canvas, w);
    canvas.restore();
  }

  Paint get _linea => Paint()
    ..color = _tinta
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _guante(Canvas c, Offset p) {
    c.drawCircle(p, 4.2, Paint()..color = Colors.white);
    c.drawCircle(
        p,
        4.2,
        Paint()
          ..color = const Color(0xFFBDBDC2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  void _piernas(Canvas c, double w) {
    final paso = tipo == TipoSticker.celebra ? 2 * math.sin(w * 2) : 0.0;
    c.drawLine(const Offset(42, 80), Offset(41 - paso, 88), _linea);
    c.drawLine(const Offset(58, 80), Offset(59 + paso, 88), _linea);
    for (final x in [35.0 - paso, 53.0 + paso]) {
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 86, 12, 6.5), const Radius.circular(3.2));
      c.drawRRect(r, Paint()..color = _rojo);
      c.drawLine(Offset(x + 1.5, 91.2), Offset(x + 10.5, 91.2),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.4);
    }
  }

  void _cuerpo(Canvas c) {
    // Manillas
    c.drawArc(
        const Rect.fromLTWH(38, 20, 24, 24),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = _rojo
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    final cuerpo = RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 31, 44, 50), const Radius.circular(7));
    // Tinte rojo cuando está enojado
    final enojado = tipo == TipoSticker.enojado;
    c.drawRRect(cuerpo,
        Paint()..color = enojado ? const Color(0xFFFFE3E1) : Colors.white);
    c.drawRRect(
        RRect.fromRectAndCorners(const Rect.fromLTWH(28, 31, 8, 50),
            topLeft: const Radius.circular(7),
            bottomLeft: const Radius.circular(7)),
        Paint()..color = _rojoOsc);
    c.drawRRect(
        cuerpo,
        Paint()
          ..color = const Color(0xFFBDBDC2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    // "OK" en la panza
    final tp = TextPainter(
      text: const TextSpan(
          text: 'OK',
          style: TextStyle(
              color: _rojo,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(54 - tp.width / 2, 66));
  }

  void _cara(Canvas c, double w) {
    final tinta = Paint()..color = _tinta;
    final trazo = Paint()
      ..color = _tinta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    // Parpadeo cada tanto
    final parpadea = (t > 0.92 && t < 0.97);
    switch (tipo) {
      case TipoSticker.lentes:
        // Lentes de sol con un brillo que pasa
        final lente = Paint()..color = _tinta;
        c.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(38, 41, 13, 8.5), const Radius.circular(3)),
            lente);
        c.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(55, 41, 13, 8.5), const Radius.circular(3)),
            lente);
        c.drawLine(const Offset(51, 44), const Offset(55, 44), trazo);
        final bx = 38 + 30 * t;
        c.save();
        c.clipRect(const Rect.fromLTWH(38, 41, 30, 8.5));
        c.drawLine(Offset(bx, 49), Offset(bx + 4, 41),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.7)
              ..strokeWidth = 2);
        c.restore();
        // sonrisa de lado
        final p = Path()
          ..moveTo(46, 56)
          ..quadraticBezierTo(55, 61, 62, 54);
        c.drawPath(p, trazo);
        break;
      case TipoSticker.llora:
        // ojos cerrados tristes ∩, boca hacia abajo, lágrimas que caen
        c.drawArc(const Rect.fromLTWH(41, 43, 9, 7), math.pi, math.pi, false,
            trazo);
        c.drawArc(const Rect.fromLTWH(56, 43, 9, 7), math.pi, math.pi, false,
            trazo);
        final b = Path()
          ..moveTo(46, 60)
          ..quadraticBezierTo(53, 53, 60, 60);
        c.drawPath(b, trazo);
        final gota = Paint()..color = const Color(0xFF4FC3F7);
        for (final f in [0.0, 0.5]) {
          final tt = (t * 2 + f) % 1;
          for (final x in [44.0, 61.0]) {
            final y = 50 + tt * 28;
            c.drawOval(
                Rect.fromCenter(
                    center: Offset(x, y), width: 3.6, height: 5),
                gota..color = const Color(0xFF4FC3F7)
                    .withValues(alpha: 1 - tt * 0.6));
          }
        }
        break;
      case TipoSticker.enojado:
        // cejas en V, ojos y boca apretada
        c.drawLine(const Offset(40, 39), const Offset(50, 43), trazo);
        c.drawLine(const Offset(66, 39), const Offset(56, 43), trazo);
        c.drawCircle(const Offset(46, 47), 2.2, tinta);
        c.drawCircle(const Offset(60, 47), 2.2, tinta);
        final b = Path()
          ..moveTo(46, 59)
          ..quadraticBezierTo(53, 55, 60, 59);
        c.drawPath(b, trazo);
        break;
      case TipoSticker.pensativo:
        // mira hacia arriba a la derecha, boca de lado
        c.drawOval(const Rect.fromLTWH(45, 42, 4.5, 6), tinta);
        c.drawOval(const Rect.fromLTWH(59, 42, 4.5, 6), tinta);
        c.drawLine(const Offset(48, 58), const Offset(58, 56), trazo);
        break;
      case TipoSticker.celebra:
        // ojos felices ^ ^ y boca abierta
        c.drawArc(const Rect.fromLTWH(41, 43, 9, 8), math.pi, math.pi, false,
            trazo);
        c.drawArc(const Rect.fromLTWH(56, 43, 9, 8), math.pi, math.pi, false,
            trazo);
        final boca = Path()
          ..moveTo(45, 54)
          ..quadraticBezierTo(53, 66, 61, 54)
          ..close();
        c.drawPath(boca, tinta);
        c.drawCircle(const Offset(53, 59.5), 2.2,
            Paint()..color = const Color(0xFFFF8A80));
        break;
      case TipoSticker.saludo:
        if (parpadea) {
          c.drawLine(const Offset(43, 46), const Offset(48, 46), trazo);
          c.drawLine(const Offset(58, 46), const Offset(63, 46), trazo);
        } else {
          c.drawOval(const Rect.fromLTWH(43, 42, 4.5, 6.5), tinta);
          c.drawOval(const Rect.fromLTWH(58, 42, 4.5, 6.5), tinta);
        }
        final b = Path()
          ..moveTo(45, 54)
          ..quadraticBezierTo(53, 61, 61, 54);
        c.drawPath(b, trazo);
        break;
    }
    // mejillas
    if (tipo != TipoSticker.lentes && tipo != TipoSticker.enojado) {
      final mejilla = Paint()
        ..color = const Color(0xFFFF8A80).withValues(alpha: 0.45);
      c.drawCircle(const Offset(40, 54), 3, mejilla);
      c.drawCircle(const Offset(66, 54), 3, mejilla);
    }
  }

  void _brazos(Canvas c, double w, {required bool atras}) {
    if (atras) return; // los brazos van delante del cuerpo en todos
    switch (tipo) {
      case TipoSticker.saludo:
        // izquierdo abajo; derecho arriba saludando (va y viene)
        c.drawLine(const Offset(29, 52), const Offset(20, 66), _linea);
        _guante(c, const Offset(19, 68));
        final ang = -1.25 + 0.45 * math.sin(w * 4);
        final hombro = const Offset(71, 50);
        final mano = hombro + Offset(math.cos(ang) * 18, math.sin(ang) * 18);
        c.drawLine(hombro, mano, _linea);
        _guante(c, mano);
        break;
      case TipoSticker.celebra:
        final a = 2.5 * math.sin(w * 2);
        c.drawLine(const Offset(29, 48), Offset(16, 30 + a), _linea);
        c.drawLine(const Offset(71, 48), Offset(84, 30 + a), _linea);
        _guante(c, Offset(15, 28 + a));
        _guante(c, Offset(85, 28 + a));
        break;
      case TipoSticker.lentes:
        // brazos cruzados... relajado: uno en la cintura
        c.drawLine(const Offset(29, 52), const Offset(21, 62), _linea);
        c.drawLine(const Offset(21, 62), const Offset(29, 68), _linea);
        _guante(c, const Offset(29, 68));
        c.drawLine(const Offset(71, 52), const Offset(80, 66), _linea);
        _guante(c, const Offset(81, 68));
        break;
      case TipoSticker.pensativo:
        // mano en el mentón
        c.drawLine(const Offset(71, 54), const Offset(78, 66), _linea);
        c.drawLine(const Offset(78, 66), const Offset(60, 63), _linea);
        _guante(c, const Offset(58, 62));
        c.drawLine(const Offset(29, 52), const Offset(20, 66), _linea);
        _guante(c, const Offset(19, 68));
        break;
      case TipoSticker.llora:
        // se seca las lágrimas con una mano
        final s = 1.5 * math.sin(w * 4);
        c.drawLine(const Offset(29, 50), Offset(36, 44 + s), _linea);
        _guante(c, Offset(39, 45 + s));
        c.drawLine(const Offset(71, 52), const Offset(80, 66), _linea);
        _guante(c, const Offset(81, 68));
        break;
      case TipoSticker.enojado:
        // puños en la cintura
        c.drawLine(const Offset(29, 50), const Offset(19, 60), _linea);
        c.drawLine(const Offset(19, 60), const Offset(28, 66), _linea);
        _guante(c, const Offset(28, 66));
        c.drawLine(const Offset(71, 50), const Offset(81, 60), _linea);
        c.drawLine(const Offset(81, 60), const Offset(72, 66), _linea);
        _guante(c, const Offset(72, 66));
        break;
    }
  }

  void _extras(Canvas c, double w) {
    switch (tipo) {
      case TipoSticker.celebra:
        // papel picado que cae
        const colores = [
          Color(0xFFFFC107), Color(0xFF42A5F5), _rojo, Color(0xFF66BB6A),
          Color(0xFFAB47BC),
        ];
        for (var i = 0; i < 10; i++) {
          final x = 8.0 + (i * 9.7) % 84;
          final y = ((t + i * 0.13) % 1) * 70 - 5;
          c.save();
          c.translate(x, y);
          c.rotate(w * 2 + i);
          c.drawRect(const Rect.fromLTWH(-1.8, -1, 3.6, 2),
              Paint()..color = colores[i % colores.length]);
          c.restore();
        }
        break;
      case TipoSticker.pensativo:
        // burbujitas de pensamiento que aparecen de a una
        final n = (t * 4).floor(); // 0..3
        final b = Paint()..color = const Color(0xFFE0E0E5);
        final borde = Paint()
          ..color = const Color(0xFFBDBDC2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        if (n >= 1) {
          c.drawCircle(const Offset(74, 30), 2.5, b);
          c.drawCircle(const Offset(74, 30), 2.5, borde);
        }
        if (n >= 2) {
          c.drawCircle(const Offset(80, 22), 4, b);
          c.drawCircle(const Offset(80, 22), 4, borde);
        }
        if (n >= 3) {
          final r = RRect.fromRectAndRadius(
              const Rect.fromLTWH(78, 3, 20, 14), const Radius.circular(7));
          c.drawRRect(r, b);
          c.drawRRect(r, borde);
          final tp = TextPainter(
            text: const TextSpan(
                text: '?',
                style: TextStyle(
                    color: _rojo, fontSize: 11, fontWeight: FontWeight.w900)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(c, Offset(88 - tp.width / 2, 3.5));
        }
        break;
      case TipoSticker.enojado:
        // vapor que sale de las manillas
        for (var i = 0; i < 2; i++) {
          final tt = (t * 2 + i * 0.5) % 1;
          final x = i == 0 ? 34.0 : 66.0;
          final p = Paint()
            ..color = const Color(0xFF9E9EA6).withValues(alpha: 1 - tt)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round;
          final y = 24 - tt * 16;
          final path = Path()
            ..moveTo(x, y + 6)
            ..quadraticBezierTo(x + (i == 0 ? -4 : 4), y + 3, x, y)
            ..quadraticBezierTo(x + (i == 0 ? 4 : -4), y - 3, x, y - 6);
          c.drawPath(path, p);
        }
        break;
      case TipoSticker.saludo:
        // "¡Hola!" pequeño que late
        final e = 1 + 0.06 * math.sin(w * 4);
        c.save();
        c.translate(84, 14);
        c.scale(e, e);
        final tp = TextPainter(
          text: const TextSpan(
              text: '¡Hola!',
              style: TextStyle(
                  color: _rojo, fontSize: 10, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
        c.restore();
        break;
      case TipoSticker.lentes:
      case TipoSticker.llora:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PintorSticker old) =>
      old.t != t || old.tipo != tipo;
}
