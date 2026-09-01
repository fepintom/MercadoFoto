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
import '../screens/chat_servicio_screen.dart';

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
        // ── Servicios: mensaje, cotización o pago → al chat del servicio,
        // que es donde se coordina todo. Necesita el par servicio+cliente.
        case 'chat_servicio':
        case 'cotizacion':
        case 'servicio_pagado':
          await _irAChatServicio(ctx, data);
          return;

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
        // El vendedor reportó la entrega con foto: el comprador debe
        // confirmar recepción o reportar un problema desde Mis Compras.
        case 'entrega_reportada':
        // Recordatorio a las 24h de no haber confirmado la recepción.
        case 'recordatorio_confirmacion':
          _push(ctx, const MisComprasScreen());
          break;

        // ── Siempre vendedor ─────────────────────────────────────────────
        case 'entrega_confirmada':
        case 'disputa':
        case 'fondos_liberados':
        case 'okdelivery_asignado':
        case 'okdelivery_observaciones':
        // El comprador canceló la orden antes del despacho (vía agente de soporte).
        case 'orden_cancelada':
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

  /// Abre el chat de un servicio. Trae el servicio del backend para saber
  /// quién es el proveedor y cómo se llama; si falta el par servicio+cliente
  /// no hay hilo que abrir y no se hace nada.
  static Future<void> _irAChatServicio(
      BuildContext ctx, Map<String, dynamic> data) async {
    final servicioId = _int(data['servicio_id']);
    final clienteId = _int(data['cliente_id']);
    if (servicioId == null || clienteId == null) return;

    final srv = await ApiService.obtenerServicioPorId(servicioId);
    if (srv == null || !ctx.mounted) return;

    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => ChatServicioScreen(
          servicioId: servicioId,
          proveedorId: (srv['user_id'] as num).toInt(),
          clienteId: clienteId,
          tituloServicio: (srv['titulo'] ?? 'Servicio').toString(),
          nombreProveedor: (srv['nombre'] ?? '').toString(),
        ),
      ),
    );
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
