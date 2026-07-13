import 'package:flutter/material.dart';

import 'api_service.dart';
import 'session_service.dart';
import 'navigation_service.dart';
import '../screens/chat_screen.dart';
import '../screens/ayuda_chat_screen.dart';
import '../screens/seleccionar_entrega_screen.dart';
import '../screens/mis_compras_screen.dart';
import '../screens/mis_ventas_screen.dart';
import '../screens/okdelivery_pendientes_screen.dart';
import '../screens/okdelivery_activo_screen.dart';
import '../screens/producto_detalle_screen.dart';

/// Punto único que decide a qué pantalla navegar según el "tipo" de una
/// notificación — sin importar si viene de un push (FCM, tocada con la app
/// en background/cerrada) o de la campanita de notificaciones dentro de la
/// app. Un solo lugar donde agregar casos nuevos en vez de repetir el mapeo
/// tipo→pantalla en varios sitios.
class NotificationRouter {
  NotificationRouter._();

  /// [data] trae al menos 'tipo'. El resto de las claves varían según el
  /// tipo (orden_id, publicacion_id, ticket_id, titulo, monto,
  /// comprador_ubicacion...). Acepta valores tanto String (vienen así desde
  /// FCM) como int/num (vienen así desde la tabla de notificaciones).
  static Future<void> abrir(BuildContext? context, Map<String, dynamic> data) async {
    // Si el context recibido ya no está montado (p. ej. porque venía de un
    // bottom sheet que se acaba de cerrar), usamos el navigator raíz de la
    // app en vez de abortar en silencio.
    final ctx = (context != null && context.mounted) ? context : rootContext;
    if (ctx == null || !ctx.mounted) return;

    final tipo = (data['tipo'] ?? '').toString();
    if (tipo.isEmpty) return;

    try {
      switch (tipo) {
        // ── Chat / preguntas / ofertas: todo vive en el hilo de chat de la publicación ──
        case 'pregunta':
        case 'chat':
        case 'oferta':
        case 'oferta_respuesta':
        case 'interes_compra':
          await _irAChat(ctx, data);
          break;

        // ── Producto guardado que bajó de precio ─────────────────────────
        case 'precio':
          await _irAProductoDetalle(ctx, data);
          break;

        // ── Soporte ──────────────────────────────────────────────────────
        case 'ayuda_respuesta':
          await _irAAyuda(ctx, data);
          break;

        // ── Vendedor: recién le pagaron, debe elegir cómo entrega ────────
        case 'elegir_entrega':
          await _irAElegirEntrega(ctx, data);
          break;

        // ── Siempre comprador ────────────────────────────────────────────
        case 'en_camino':
        case 'okdelivery_en_camino':
          _push(ctx, const MisComprasScreen());
          break;

        // ── Siempre vendedor ─────────────────────────────────────────────
        case 'entrega_confirmada':
        case 'disputa':
        case 'fondos_liberados':
        case 'okdelivery_asignado':
        case 'okdelivery_observaciones':
          _push(ctx, const MisVentasScreen());
          break;

        // ── Siempre repartidor, aún sin entrega asignada en la orden ─────
        case 'okdelivery_disponible':
          await _irAPendientesRepartidor(ctx);
          break;

        // ── Siempre repartidor, ya con una entrega activa en la orden ────
        case 'okdelivery_confirmar_recepcion':
        case 'okdelivery_verificar_reparacion':
          await _irAEntregaActiva(ctx, data);
          break;

        // ── Ambiguos: el mismo tipo se manda a roles distintos ───────────
        case 'okdelivery_llego':
        case 'venta_cancelada':
          await _irSegunRolEnOrden(ctx, data);
          break;

        default:
          // Tipo desconocido: no navegamos a ciegas.
          break;
      }
    } catch (_) {
      // Nunca romper la app por una notificación mal formada o sin red.
    }
  }

  // ── Helpers de navegación ───────────────────────────────────────────────

  static void _push(BuildContext ctx, Widget screen) {
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => screen));
  }

  static Future<void> _irAChat(BuildContext ctx, Map<String, dynamic> data) async {
    final pubId = _int(data['publicacion_id']);
    if (pubId == null) return;
    _push(
      ctx,
      ChatScreen(
        publicacionId: pubId,
        tituloProducto: '',
        imagenUrl: '',
        vendedorId: 0,
        nombreVendedor: '',
      ),
    );
  }

  static Future<void> _irAProductoDetalle(BuildContext ctx, Map<String, dynamic> data) async {
    final pubId = _int(data['publicacion_id']);
    if (pubId == null) return;
    final producto = await ApiService.obtenerPublicacion(pubId);
    if (producto == null || !ctx.mounted) return;
    _push(ctx, ProductoDetalleScreen(producto: producto));
  }

  static Future<void> _irAAyuda(BuildContext ctx, Map<String, dynamic> data) async {
    final ticketId = _int(data['ticket_id']);
    if (ticketId == null) return;
    _push(ctx, AyudaChatScreen(ticketId: ticketId, tipo: ''));
  }

  static Future<void> _irAElegirEntrega(BuildContext ctx, Map<String, dynamic> data) async {
    final ordenId = _int(data['orden_id']);
    if (ordenId == null) return;
    _push(
      ctx,
      SeleccionarEntregaScreen(
        ordenId: ordenId,
        titulo: (data['titulo'] ?? '').toString(),
        monto: data['monto'] ?? 0,
        compradorUbicacion: (data['comprador_ubicacion'] ?? '').toString(),
      ),
    );
  }

  /// Resuelve el perfil de delivery del usuario logueado (null si no es repartidor).
  static Future<int?> _deliveryIdDeUsuarioActual() async {
    final userId = await SessionService.obtenerUser();
    if (userId == null) return null;
    final perfil = await ApiService.obtenerDeliveryUsuario(userId);
    return perfil?['id'] as int?;
  }

  static Future<void> _irAPendientesRepartidor(BuildContext ctx) async {
    final deliveryId = await _deliveryIdDeUsuarioActual();
    if (deliveryId == null || !ctx.mounted) return;
    _push(ctx, OkdeliveryPendientesScreen(deliveryId: deliveryId));
  }

  static Future<void> _irAEntregaActiva(BuildContext ctx, Map<String, dynamic> data) async {
    final ordenId = _int(data['orden_id']);
    if (ordenId == null) return;
    // La entrega ya tiene repartidor asignado — usamos ese delivery_id directo.
    final entrega = await ApiService.obtenerEntregaOkdelivery(ordenId);
    int? deliveryId = entrega?['delivery_id'] as int?;
    deliveryId ??= await _deliveryIdDeUsuarioActual(); // respaldo
    if (deliveryId == null || !ctx.mounted) return;
    _push(ctx, OkdeliveryActivoScreen(ordenId: ordenId, deliveryId: deliveryId));
  }

  /// Para tipos que se mandan tanto al comprador como al vendedor o al
  /// repartidor de una misma orden (ej. 'venta_cancelada', 'okdelivery_llego').
  /// Compara el usuario logueado contra los roles de la orden para saber
  /// a qué pantalla corresponde.
  static Future<void> _irSegunRolEnOrden(BuildContext ctx, Map<String, dynamic> data) async {
    final ordenId = _int(data['orden_id']);
    if (ordenId == null) return;
    final userId = await SessionService.obtenerUser();
    final entrega = await ApiService.obtenerEntregaOkdelivery(ordenId);
    if (!ctx.mounted) return;

    if (entrega == null || userId == null) {
      // Sin más información, el destino más probable es el comprador.
      _push(ctx, const MisComprasScreen());
      return;
    }
    if (userId == entrega['comprador_id']) {
      _push(ctx, const MisComprasScreen());
    } else if (userId == entrega['vendedor_id']) {
      _push(ctx, const MisVentasScreen());
    } else {
      final deliveryId = entrega['delivery_id'] as int?;
      if (deliveryId != null) {
        _push(ctx, OkdeliveryPendientesScreen(deliveryId: deliveryId));
      }
    }
  }

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
