import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../screens/confirmar_entrega_qr_screen.dart';
import '../screens/seguimiento_entrega_screen.dart';
import 'navigation_service.dart';

/// Maneja los deep links okventa:// (QR de la etiqueta de envío).
///
///   okventa://orden/{id}/mapa
///       → mapa de tracking en vivo (comprador ve al vendedor venir)
///   okventa://orden/{id}/confirmar-entrega?token={token}
///       → pantalla "¿Recibiste tu pedido?" (valida token en backend)
class DeepLinkService {
  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;

  /// Llamar una vez al iniciar la app (después de runApp).
  static Future<void> init() async {
    // Link que abrió la app desde cero (cold start)
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        // Esperar a que el navigator exista
        WidgetsBinding.instance.addPostFrameCallback((_) => _abrir(initial));
      }
    } catch (_) {}
    // Links recibidos con la app ya abierta
    _sub ??= _appLinks.uriLinkStream.listen(_abrir, onError: (_) {});
  }

  static void _abrir(Uri uri) {
    if (uri.scheme != 'okventa') return;
    // okventa://orden/{id}/... → host = 'orden', segments = [id, accion]
    final seg = [uri.host, ...uri.pathSegments]
        .where((s) => s.isNotEmpty)
        .toList();
    if (seg.length < 3 || seg[0] != 'orden') return;
    final ordenId = int.tryParse(seg[1]);
    if (ordenId == null) return;
    final accion = seg[2];

    final ctx = rootContext;
    if (ctx == null) return;

    if (accion == 'mapa') {
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) =>
              SeguimientoEntregaScreen(ordenId: ordenId, titulo: ''),
        ),
      );
    } else if (accion == 'confirmar-entrega') {
      final token = uri.queryParameters['token'] ?? '';
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) =>
              ConfirmarEntregaQrScreen(ordenId: ordenId, token: token),
        ),
      );
    }
  }
}
