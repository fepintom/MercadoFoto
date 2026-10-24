import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Dibuja los pins de Encontrar (producto: foto + precio; servicio: círculo
/// con la llave + título) como imágenes PNG para Apple Maps, que no acepta
/// widgets de Flutter sobre el mapa. Se guardan en memoria por clave.
class PinesApple {
  PinesApple._();

  static final Map<String, Uint8List> _hechos = {};
  static final Map<String, Future<ui.Image?>> _fotos = {};

  static Uint8List? listo(String clave) => _hechos[clave];

  static double get _dpr =>
      ui.PlatformDispatcher.instance.views.first.devicePixelRatio;

  static Future<ui.Image?> _foto(String url) => _fotos[url] ??= () async {
        try {
          final r = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 12));
          if (r.statusCode != 200) return null;
          final codec = await ui.instantiateImageCodec(r.bodyBytes,
              targetWidth: (40 * _dpr).round());
          return (await codec.getNextFrame()).image;
        } catch (_) {
          return null;
        }
      }();

  static TextPainter _texto(String t, double tam, Color color,
      {double? maxAncho, FontWeight peso = FontWeight.w700}) {
    final tp = TextPainter(
      text: TextSpan(
          text: t,
          style: TextStyle(
              fontSize: tam, fontWeight: peso, color: color, height: 1.15)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxAncho ?? double.infinity);
    return tp;
  }

  static Future<Uint8List> _aPng(
      double w, double h, void Function(Canvas c) dibujar) async {
    final dpr = _dpr;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.scale(dpr);
    dibujar(c);
    final img = await rec
        .endRecording()
        .toImage((w * dpr).ceil(), (h * dpr).ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  static void _punta(Canvas c, double cx, double y, Color color) {
    final p = Path()
      ..moveTo(cx - 5, y)
      ..lineTo(cx + 5, y)
      ..lineTo(cx, y + 6)
      ..close();
    c.drawPath(p, Paint()..color = color);
  }

  static void _sombra(Canvas c, RRect r) {
    c.drawRRect(
        r.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  /// Producto: foto cuadrada con borde + etiqueta de precio + punta.
  /// El ancla va abajo al centro (la punta).
  static Future<Uint8List> producto({
    required String clave,
    required String? fotoUrl,
    required String precio,
    required bool sel,
    required Color colorPrecio,
    required Color colorSel,
    required Color fondoFoto,
    required Color iconoVacio,
  }) async {
    final ya = _hechos[clave];
    if (ya != null) return ya;
    final foto = (fotoUrl == null || fotoUrl.isEmpty) ? null : await _foto(fotoUrl);
    final tp = _texto(precio, 10, Colors.white, maxAncho: 70);
    const lado = 36.0, pad = 4.0;
    final ancho = math.max(lado + 2 * pad, tp.width + 12 + 2 * pad);
    final etiquetaH = tp.height + 4;
    final alto = pad + lado + 3 + etiquetaH + 6 + pad;
    final color = sel ? colorSel : colorPrecio;
    final png = await _aPng(ancho, alto, (c) {
      final cx = ancho / 2;
      // Foto
      final marco = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, pad + lado / 2), width: lado, height: lado),
          const Radius.circular(8));
      _sombra(c, marco);
      c.drawRRect(marco, Paint()..color = sel ? colorSel : Colors.white);
      final dentro = marco.deflate(sel ? 2.5 : 2);
      c.save();
      c.clipRRect(dentro);
      c.drawRect(dentro.outerRect, Paint()..color = fondoFoto);
      if (foto != null) {
        final w = foto.width.toDouble(), h = foto.height.toDouble();
        final m = math.min(w, h);
        c.drawImageRect(
            foto,
            Rect.fromCenter(center: Offset(w / 2, h / 2), width: m, height: m),
            dentro.outerRect,
            Paint()..filterQuality = FilterQuality.high);
      } else {
        final ic = Icons.shopping_cart_outlined;
        final t = TextPainter(
          text: TextSpan(
              text: String.fromCharCode(ic.codePoint),
              style: TextStyle(
                  fontFamily: ic.fontFamily,
                  package: ic.fontPackage,
                  fontSize: 16,
                  color: iconoVacio)),
          textDirection: TextDirection.ltr,
        )..layout();
        t.paint(c, Offset(cx - t.width / 2, pad + lado / 2 - t.height / 2));
      }
      c.restore();
      // Precio
      final yE = pad + lado + 3;
      final et = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, yE + etiquetaH / 2),
              width: tp.width + 12,
              height: etiquetaH),
          const Radius.circular(5));
      _sombra(c, et);
      c.drawRRect(et, Paint()..color = color);
      tp.paint(c, Offset(cx - tp.width / 2, yE + 2));
      _punta(c, cx, yE + etiquetaH - 0.5, color);
    });
    _hechos[clave] = png;
    return png;
  }

  /// Servicio: título arriba + círculo con la llave + punta.
  static Future<Uint8List> servicio({
    required String clave,
    required String titulo,
    required bool sel,
    required Color colorBase,
    required Color colorSel,
  }) async {
    final ya = _hechos[clave];
    if (ya != null) return ya;
    final tp = _texto(titulo, 10, Colors.white, maxAncho: 100);
    const pad = 4.0;
    final circ = sel ? 40.0 : 36.0;
    final etiquetaH = tp.height + 4;
    final ancho = math.max(circ + 2 * pad, tp.width + 12 + 2 * pad);
    final alto = pad + etiquetaH + 3 + circ + 6 + pad;
    final color = sel ? colorSel : colorBase;
    final png = await _aPng(ancho, alto, (c) {
      final cx = ancho / 2;
      final et = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, pad + etiquetaH / 2),
              width: tp.width + 12,
              height: etiquetaH),
          const Radius.circular(6));
      _sombra(c, et);
      c.drawRRect(et, Paint()..color = color.withValues(alpha: 0.94));
      tp.paint(c, Offset(cx - tp.width / 2, pad + 2));
      final cy = pad + etiquetaH + 3 + circ / 2;
      final r = RRect.fromRectAndRadius(
          Rect.fromCircle(center: Offset(cx, cy), radius: circ / 2),
          Radius.circular(circ / 2));
      _sombra(c, r);
      c.drawCircle(Offset(cx, cy), circ / 2, Paint()..color = Colors.white);
      c.drawCircle(Offset(cx, cy), circ / 2 - 2, Paint()..color = color);
      const ic = Icons.handyman_rounded;
      final t = TextPainter(
        text: TextSpan(
            text: String.fromCharCode(ic.codePoint),
            style: TextStyle(
                fontFamily: ic.fontFamily,
                package: ic.fontPackage,
                fontSize: 18,
                color: Colors.white)),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(c, Offset(cx - t.width / 2, cy - t.height / 2));
      _punta(c, cx, cy + circ / 2 - 1.5, color);
    });
    _hechos[clave] = png;
    return png;
  }

  /// Círculo de color con un ícono blanco (repartidor, vendedor, casa).
  static Future<Uint8List> circulo({
    required String clave,
    required IconData icono,
    required Color color,
    double tam = 36,
  }) async {
    final ya = _hechos[clave];
    if (ya != null) return ya;
    const pad = 4.0;
    final lado = tam + 2 * pad;
    final png = await _aPng(lado, lado, (c) {
      final centro = Offset(lado / 2, lado / 2);
      c.drawCircle(
          centro + const Offset(0, 2),
          tam / 2,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      c.drawCircle(centro, tam / 2, Paint()..color = Colors.white);
      c.drawCircle(centro, tam / 2 - 3, Paint()..color = color);
      final t = TextPainter(
        text: TextSpan(
            text: String.fromCharCode(icono.codePoint),
            style: TextStyle(
                fontFamily: icono.fontFamily,
                package: icono.fontPackage,
                fontSize: tam * 0.52,
                color: Colors.white)),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(c, centro - Offset(t.width / 2, t.height / 2));
    });
    _hechos[clave] = png;
    return png;
  }

  /// Gota (pin clásico) de color con borde blanco y un ícono blanco: se usa
  /// para los lugares encontrados con el buscador de Apple (azul, tiendita).
  static Future<Uint8List> gota({
    required String clave,
    required Color color,
    required IconData icono,
  }) async {
    final ya = _hechos[clave];
    if (ya != null) return ya;
    const r = 15.0, pad = 5.0;
    const ancho = 2 * r + 2 * pad;
    const alto = 2 * r + 16 + 2 * pad;
    final png = await _aPng(ancho, alto, (c) {
      const cx = ancho / 2, cy = pad + r;
      Path forma(double rr, double punta) => Path()
        ..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: rr))
        ..moveTo(cx - rr * 0.75, cy + rr * 0.6)
        ..lineTo(cx + rr * 0.75, cy + rr * 0.6)
        ..lineTo(cx, cy + rr + punta)
        ..close();
      c.drawPath(
          forma(r + 2, 14).shift(const Offset(0, 2)),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      c.drawPath(forma(r + 2, 14), Paint()..color = Colors.white);
      c.drawPath(forma(r, 11.5), Paint()..color = color);
      final t = TextPainter(
        text: TextSpan(
            text: String.fromCharCode(icono.codePoint),
            style: TextStyle(
                fontFamily: icono.fontFamily,
                package: icono.fontPackage,
                fontSize: 17,
                color: Colors.white)),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(c, Offset(cx - t.width / 2, cy - t.height / 2));
    });
    _hechos[clave] = png;
    return png;
  }
}
