import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ilustración tipo "sello de tinta" antiguo para la sección de OkDelivery
/// mientras está en pausa: un timbre rojo distorsionado con un ciclista
/// veloz cargando un bolso con las siglas "OK", rodeado de texto curvo.
/// Dibujado 100% con CustomPainter/widgets — sin assets externos.
class OkDeliveryStamp extends StatelessWidget {
  final double size;

  const OkDeliveryStamp({super.key, this.size = 220});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.06, // leve inclinación, como un sello estampado a mano
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Anillos de tinta desgastados
            CustomPaint(
              size: Size(size, size),
              painter: _StampRingPainter(),
            ),
            // Texto curvo superior: OK DELIVERY
            CustomPaint(
              size: Size(size, size),
              painter: _CurvedTextPainter(
                text: 'OKVENTA  •  DELIVERY  •',
                radius: size * 0.40,
                startAngle: -math.pi * 0.92,
                clockwise: true,
              ),
            ),
            // Texto curvo inferior: PRÓXIMAMENTE
            CustomPaint(
              size: Size(size, size),
              painter: _CurvedTextPainter(
                text: '★  PRÓXIMAMENTE  ★',
                radius: size * 0.40,
                startAngle: math.pi * 0.08,
                clockwise: true,
              ),
            ),
            // Ciclista veloz + bolso "OK" al centro
            _Ciclista(size: size * 0.46),
          ],
        ),
      ),
    );
  }
}

// ── Anillos de sello desgastado ─────────────────────────────────────────────
class _StampRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = colors.primary.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Anillo exterior grueso, con "roturas" (efecto tinta gastada)
    paint.strokeWidth = size.width * 0.028;
    _dashedCircle(canvas, center, size.width * 0.48, paint,
        gaps: 14, gapFraction: 0.10, seed: 1);

    // Anillo interior delgado
    paint.strokeWidth = size.width * 0.012;
    _dashedCircle(canvas, center, size.width * 0.335, paint,
        gaps: 20, gapFraction: 0.06, seed: 2);
  }

  void _dashedCircle(Canvas canvas, Offset center, double radius,
      Paint paint, {required int gaps, required double gapFraction, required int seed}) {
    final rnd = math.Random(seed);
    final step = (2 * math.pi) / gaps;
    for (int i = 0; i < gaps; i++) {
      // Salta algunos segmentos al azar para el look "desgastado"
      if (rnd.nextDouble() < 0.12) continue;
      final start = i * step + gapFraction * step / 2;
      final sweep = step * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Texto curvo a lo largo del círculo ──────────────────────────────────────
class _CurvedTextPainter extends CustomPainter {
  final String text;
  final double radius;
  final double startAngle;
  final bool clockwise;

  _CurvedTextPainter({
    required this.text,
    required this.radius,
    required this.startAngle,
    required this.clockwise,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final style = TextStyle(
      color: colors.primary.withOpacity(0.85),
      fontSize: size.width * 0.052,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    );

    double angle = startAngle;
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final tp = TextPainter(
        text: TextSpan(text: char, style: style),
        textDirection: TextDirection.ltr,
      )..layout();

      final charAngle = tp.width / radius;
      canvas.save();
      canvas.translate(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.rotate(angle + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();

      angle += clockwise ? charAngle : -charAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Ciclista veloz con bolso "OK" ────────────────────────────────────────────
class _Ciclista extends StatelessWidget {
  final double size;
  const _Ciclista({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Líneas de velocidad detrás
          CustomPaint(
            size: Size(size, size * 0.7),
            painter: _SpeedLinesPainter(),
          ),
          // Bicicleta inclinada hacia adelante = sensación de velocidad
          Transform.rotate(
            angle: -0.18,
            child: Icon(
              Icons.pedal_bike_rounded,
              size: size * 0.72,
              color: colors.primary.withOpacity(0.9),
            ),
          ),
          // Bolso "OK" tipo tag de courier, arriba a la derecha del ciclista
          Positioned(
            top: size * 0.06,
            right: size * 0.02,
            child: Transform.rotate(
              angle: 0.15,
              child: Container(
                width: size * 0.30,
                height: size * 0.24,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(size * 0.05),
                  border: Border.all(
                      color: colors.primary.withOpacity(0.9), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colors.primary.withOpacity(0.5)
      ..strokeWidth = size.width * 0.016
      ..strokeCap = StrokeCap.round;

    final lengths = [0.30, 0.22, 0.16];
    for (int i = 0; i < lengths.length; i++) {
      final y = size.height * (0.30 + i * 0.16);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width * lengths[i], y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
