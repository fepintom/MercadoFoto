import 'package:flutter/material.dart';

/// Rejilla de encuadre para grabar el paquete en la verificación antifraude
/// (embalaje del vendedor y unboxing del comprador). Es puramente visual —
/// una guía para que el vendedor y el comprador graben el paquete desde el
/// mismo ángulo, en posición horizontal y centrado, así la IA puede comparar
/// dimensiones y posición de etiquetas entre ambos videos.
///
/// No se usa para medir nada por software: es una referencia para el
/// usuario, como la rejilla de una cámara de fotos normal.
class RejillaEmpaqueOverlay extends StatelessWidget {
  const RejillaEmpaqueOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _RejillaPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _RejillaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.28)
      ..strokeWidth = 1;

    // Rejilla clásica de 3x3 (tercios), como la de una cámara de fotos.
    for (int i = 1; i < 3; i++) {
      final dx = size.width / 3 * i;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
      final dy = size.height / 3 * i;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    // Guía horizontal para el paquete: un rectángulo centrado, más ancho
    // que alto, con esquinas marcadas — el paquete debe quedar "derecho"
    // (horizontal) dentro de este marco.
    final boxWidth = size.width * 0.82;
    final boxHeight = size.height * 0.34;
    final left = (size.width - boxWidth) / 2;
    final top = (size.height - boxHeight) / 2;
    final rect = Rect.fromLTWH(left, top, boxWidth, boxHeight);

    final boxPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRect(rect, boxPaint);

    // Esquinas destacadas en rojo marca OkVenta.
    final cornerPaint = Paint()
      ..color = const Color(0xFFD62B2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final cornerLen = boxWidth * 0.08;

    void esquina(Offset origen, Offset dirX, Offset dirY) {
      canvas.drawLine(origen, origen + dirX * cornerLen, cornerPaint);
      canvas.drawLine(origen, origen + dirY * cornerLen, cornerPaint);
    }

    esquina(rect.topLeft, const Offset(1, 0), const Offset(0, 1));
    esquina(rect.topRight, const Offset(-1, 0), const Offset(0, 1));
    esquina(rect.bottomLeft, const Offset(1, 0), const Offset(0, -1));
    esquina(rect.bottomRight, const Offset(-1, 0), const Offset(0, -1));

    // Línea central para nivelar el paquete horizontalmente.
    final centerPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
