import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/carrito_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/chat_servicio_screen.dart';
import '../screens/evaluaciones_vendedor_screen.dart';
import '../screens/perfil_publico_screen.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/contenido_oculto_service.dart';
import '../services/favoritos_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'invitacion_servicio_instalacion.dart' show categoriaServicioParaProducto;

/// Acciones sobre una publicación, compartidas por la tarjeta de OkMarket y
/// el detalle del producto: carro (con la pregunta de instalación), aviso
/// de instalación, cotizar en el chat, compartir y el menú de los tres
/// puntos.
class AccionesProducto {
  AccionesProducto._();

  static bool ofreceInstalacion(Map p) =>
      p['instalacion_vendedor'] == true || p['instalacion_vendedor'] == 1;

  static String _titulo(Map p) => (p['titulo'] ?? 'Producto').toString();
  static String _vendedor(Map p) =>
      (p['nombre_vendedor'] ?? 'Vendedor').toString();

  static void _aviso(BuildContext context, String texto,
      {SnackBarAction? accion}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        backgroundColor: colors.carbon,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: accion,
      ));
  }

  // ── Carro ──────────────────────────────────────────────────────────────

  /// Agrega al carro. Si el vendedor ofrece instalación, pregunta antes:
  /// cotizar con instalación (va al chat) o comprar sin ella (al carro).
  static Future<void> agregarAlCarro(
      BuildContext context, Map<String, dynamic> p) async {
    if (ofreceInstalacion(p)) {
      final opcion = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.handyman_rounded,
                      size: 22, color: colors.textPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Este producto ofrece instalación',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                    'El vendedor de este producto ofrece la instalación. '
                    '¿Cómo quieres seguir?',
                    style: TextStyle(
                        fontSize: 14, height: 1.35, color: colors.textPrimary)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'con'),
                    icon: const Icon(Icons.request_quote_outlined, size: 18),
                    label: const Text('Cotizar con instalación'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'sin'),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: const Text('Sin instalación, agregar al carro'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.textPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (!context.mounted || opcion == null) return;
      if (opcion == 'con') {
        await cotizarInstalacion(context, p);
        return;
      }
    }
    meterAlCarro(context, p);
  }

  static void meterAlCarro(BuildContext context, Map<String, dynamic> p) {
    final agregado = CartService.addProducto(Map<String, dynamic>.from(p));
    _aviso(
      context,
      agregado ? 'Agregado al carro' : 'Ya estaba en tu carro',
      accion: SnackBarAction(
        label: 'Ver carro',
        textColor: Colors.white,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CarritoScreen())),
      ),
    );
  }

  // ── Instalación ────────────────────────────────────────────────────────

  /// Abre la conversación con el vendedor para cotizar la instalación.
  ///
  /// Si el vendedor publicó su servicio de instalación (lo que le ofrece la
  /// invitación al publicar), va al chat de ESE servicio: ahí puede enviar
  /// una cotización formal, el comprador la acepta y sigue el flujo de
  /// siempre (pago, Seguro Garantía). Si no lo publicó, va al chat del
  /// producto. En los dos casos el mensaje queda escrito.
  static Future<void> cotizarInstalacion(
      BuildContext context, Map<String, dynamic> p) async {
    final uid = await SessionService.obtenerUser();
    if (!context.mounted) return;
    if (uid == null) {
      _aviso(context, 'Inicia sesión para cotizar la instalación');
      return;
    }
    final vendedorId = (p['user_id'] as num?)?.toInt();
    if (vendedorId == null) return;
    if (vendedorId == uid) {
      _aviso(context, 'Es tu propia publicación');
      return;
    }
    final mensaje =
        'Hola, quiero cotizar la instalación de "${_titulo(p)}". ¿Me envías una cotización?';

    Map<String, dynamic>? servicio;
    try {
      final suyos = (await ApiService.obtenerServicios(tipo: 'ofrezco'))
          .where((s) => s['user_id'] == vendedorId)
          .toList();
      if (suyos.isNotEmpty) {
        final cat = categoriaServicioParaProducto(
            (p['categoria'] ?? '').toString(),
            (p['subcategoria'] ?? '').toString());
        servicio = suyos.firstWhere(
          (s) =>
              (s['titulo'] ?? '').toString().toLowerCase().contains('instala'),
          orElse: () => suyos.firstWhere((s) => s['categoria'] == cat,
              orElse: () => suyos.first),
        );
      }
    } catch (_) {}
    if (!context.mounted) return;

    final srv = servicio;
    if (srv != null) {
      final srvId = (srv['id'] as num).toInt();
      ApiService.registrarContactoServicio(srvId, uid, 'chat', '')
          .catchError((_) {});
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatServicioScreen(
            servicioId: srvId,
            proveedorId: vendedorId,
            clienteId: uid,
            tituloServicio: (srv['titulo'] ?? 'Instalación').toString(),
            nombreProveedor: _vendedor(p),
            mensajeInicial: mensaje,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            publicacionId: (p['id'] as num).toInt(),
            tituloProducto: _titulo(p),
            imagenUrl: (p['imagen_url'] ?? '').toString(),
            vendedorId: vendedorId,
            nombreVendedor: _vendedor(p),
            mensajeInicial: mensaje,
          ),
        ),
      );
    }
  }

  /// Aviso flotante que nace desde el enlace "Ofrece instalación"
  /// ([origen] es el contexto del enlace).
  static Future<void> mostrarAvisoInstalacion(
      BuildContext origen, Map<String, dynamic> p) {
    final box = origen.findRenderObject() as RenderBox?;
    final pantalla = MediaQuery.of(origen).size;
    final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final tam = box?.size ?? Size.zero;
    const ancho = 270.0;
    final centro = pos + Offset(tam.width / 2, tam.height / 2);
    // Máximo primero: en pantallas muy angostas el límite derecho podría
    // quedar bajo el izquierdo y clamp() lanzaría un error.
    final maxIzq = (pantalla.width - ancho - 12) < 12
        ? 12.0
        : pantalla.width - ancho - 12;
    final izquierda = pos.dx.clamp(12.0, maxIzq).toDouble();
    // Arriba del enlace si hay espacio; si no, abajo.
    final arriba = pos.dy > 240;
    final alineacion = Alignment(
      (centro.dx / pantalla.width) * 2 - 1,
      (centro.dy / pantalla.height) * 2 - 1,
    );

    return showGeneralDialog(
      context: origen,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) {
        Widget enlace(String texto, VoidCallback onTap) => GestureDetector(
              onTap: onTap,
              child: Text(texto,
                  style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                      color: colors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: colors.primary)),
            );
        final estilo =
            TextStyle(fontSize: 13.5, height: 1.35, color: colors.textPrimary);
        final tarjeta = Material(
          color: colors.surface,
          elevation: 10,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.handyman_rounded,
                      size: 18, color: colors.textPrimary),
                  const SizedBox(width: 6),
                  Text('Instalación disponible',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary)),
                ]),
                const SizedBox(height: 8),
                Text('El vendedor de este producto ofrece la instalación.',
                    style: estilo),
                const SizedBox(height: 8),
                Text.rich(TextSpan(style: estilo, children: [
                  const TextSpan(text: 'Si quieres cotizar el servicio, '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: enlace('pincha aquí', () {
                      Navigator.pop(ctx);
                      cotizarInstalacion(origen, p);
                    }),
                  ),
                  const TextSpan(text: '.'),
                ])),
                const SizedBox(height: 6),
                Text.rich(TextSpan(style: estilo, children: [
                  const TextSpan(text: 'Para comprar sin instalación, '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: enlace('pincha aquí', () {
                      Navigator.pop(ctx);
                      meterAlCarro(origen, p);
                    }),
                  ),
                  const TextSpan(text: '.'),
                ])),
              ],
            ),
          ),
        );
        return Stack(children: [
          Positioned(
            left: izquierda,
            width: ancho,
            top: arriba ? null : pos.dy + tam.height + 6,
            bottom: arriba ? pantalla.height - pos.dy + 6 : null,
            child: tarjeta,
          ),
        ]);
      },
      // Crece desde el enlace: la escala tiene su origen en el botón.
      transitionBuilder: (_, anim, __, child) {
        final c = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
              scale: c, alignment: alineacion, child: child),
        );
      },
    );
  }

  // ── Compartir ──────────────────────────────────────────────────────────

  static String _textoCompartir(Map p) =>
      'Mira esto en OkVenta: ${_titulo(p)} a ${formatPrecio(p['precio'])}. '
      'Búscalo en la app OkVenta.';

  static Future<void> compartir(BuildContext context, Map p) async {
    final texto = _textoCompartir(p);
    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Text('Compartir',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary)),
          ListTile(
            leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
            title: Text('WhatsApp', style: TextStyle(color: colors.textPrimary)),
            onTap: () async {
              Navigator.pop(ctx);
              await launchUrl(
                  Uri.parse(
                      'https://wa.me/?text=${Uri.encodeComponent(texto)}'),
                  mode: LaunchMode.externalApplication);
            },
          ),
          ListTile(
            leading: Icon(Icons.copy_rounded, color: colors.textPrimary),
            title:
                Text('Copiar texto', style: TextStyle(color: colors.textPrimary)),
            onTap: () async {
              Navigator.pop(ctx);
              await Clipboard.setData(ClipboardData(text: texto));
              if (context.mounted) _aviso(context, 'Texto copiado');
            },
          ),
        ]),
      ),
    );
  }

  // ── Menú de los tres puntos ────────────────────────────────────────────

  static Future<void> mostrarMenu(
      BuildContext context, Map<String, dynamic> p) async {
    final uid = await SessionService.obtenerUser();
    if (!context.mounted) return;
    final vendedorId = (p['user_id'] as num?)?.toInt();
    final pubId = (p['id'] as num?)?.toInt();
    final esMio = uid != null && vendedorId == uid;
    final nombre = _vendedor(p);

    Widget opcion(IconData i, String t, VoidCallback f, {bool rojo = false}) =>
        ListTile(
          dense: true,
          leading: Icon(i, color: rojo ? colors.primary : colors.textPrimary),
          title: Text(t,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: rojo ? colors.primary : colors.textPrimary)),
          onTap: f,
        );

    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        void ir(Widget pantalla) {
          Navigator.pop(ctx);
          Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
        }

        final guardada = FavoritosService.es(pubId);
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 6),
            if (vendedorId != null) ...[
              opcion(Icons.person_outline_rounded, 'Ver perfil de $nombre',
                  () => ir(PerfilPublicoScreen(userId: vendedorId, nombre: nombre))),
              opcion(Icons.star_outline_rounded, 'Ver valoraciones del vendedor',
                  () => ir(EvaluacionesVendedorScreen(
                      vendedorId: vendedorId, nombreVendedor: nombre))),
            ],
            if (!esMio && pubId != null)
              opcion(
                  guardada
                      ? Icons.bookmark_remove_outlined
                      : Icons.bookmark_add_outlined,
                  guardada ? 'Quitar de guardados' : 'Guardar publicación',
                  () async {
                Navigator.pop(ctx);
                if (uid == null) {
                  _aviso(context, 'Inicia sesión para guardar publicaciones');
                  return;
                }
                final ahora = await FavoritosService.alternar(uid, pubId);
                if (context.mounted) {
                  _aviso(context,
                      ahora ? 'Guardada en favoritos' : 'Quitada de favoritos');
                }
              }),
            opcion(Icons.ios_share_rounded, 'Compartir', () {
              Navigator.pop(ctx);
              compartir(context, p);
            }),
            if (!esMio && vendedorId != null && pubId != null)
              opcion(Icons.chat_bubble_outline_rounded, 'Preguntar al vendedor',
                  () {
                if (uid == null) {
                  Navigator.pop(ctx);
                  _aviso(context, 'Inicia sesión para escribir al vendedor');
                  return;
                }
                ir(ChatScreen(
                  publicacionId: pubId,
                  tituloProducto: _titulo(p),
                  imagenUrl: (p['imagen_url'] ?? '').toString(),
                  vendedorId: vendedorId,
                  nombreVendedor: nombre,
                ));
              }),
            if (!esMio && pubId != null)
              opcion(Icons.visibility_off_outlined, 'No me interesa', () {
                Navigator.pop(ctx);
                ContenidoOcultoService.ocultarPublicacion(pubId);
                _aviso(context, 'No volverás a ver esta publicación',
                    accion: SnackBarAction(
                      label: 'Deshacer',
                      textColor: Colors.white,
                      onPressed: () =>
                          ContenidoOcultoService.mostrarPublicacion(pubId),
                    ));
              }),
            if (!esMio && pubId != null)
              opcion(Icons.flag_outlined, 'Reportar publicación', () {
                Navigator.pop(ctx);
                _reportar(context, p, uid);
              }, rojo: true),
            if (!esMio && vendedorId != null)
              opcion(Icons.block_rounded, 'Bloquear a $nombre', () {
                Navigator.pop(ctx);
                _bloquear(context, vendedorId, nombre);
              }, rojo: true),
            const SizedBox(height: 6),
          ]),
        );
      },
    );
  }

  static Future<void> _reportar(BuildContext context, Map p, int? uid) async {
    if (uid == null) {
      _aviso(context, 'Inicia sesión para reportar');
      return;
    }
    const motivos = [
      'Producto prohibido o ilegal',
      'Parece una estafa',
      'Precio o información engañosa',
      'Fotos o texto ofensivo',
      'Otro motivo',
    ];
    final motivo = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text('¿Por qué la reportas?',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary)),
          for (final m in motivos)
            ListTile(
              title: Text(m, style: TextStyle(color: colors.textPrimary)),
              onTap: () => Navigator.pop(ctx, m),
            ),
        ]),
      ),
    );
    if (motivo == null || !context.mounted) return;
    try {
      await ApiService.crearTicketAyuda(
        userId: uid,
        tipo: 'reporte',
        numeroReferencia: 'Publicación #${p['id']}',
        detalle: 'Reporte de publicación "${_titulo(p)}": $motivo',
      );
      if (context.mounted) {
        _aviso(context, 'Gracias. El equipo de OkVenta lo va a revisar.');
      }
    } catch (_) {
      if (context.mounted) {
        _aviso(context, 'No se pudo enviar el reporte. Intenta de nuevo.');
      }
    }
  }

  static Future<void> _bloquear(
      BuildContext context, int vendedorId, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Bloquear a $nombre?'),
        content: const Text(
            'No verás más sus publicaciones en OkMarket. Puedes deshacerlo '
            'justo después.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Bloquear', style: TextStyle(color: colors.primary))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ContenidoOcultoService.bloquearVendedor(vendedorId);
    if (!context.mounted) return;
    _aviso(context, 'Bloqueaste a $nombre',
        accion: SnackBarAction(
          label: 'Deshacer',
          textColor: Colors.white,
          onPressed: () => ContenidoOcultoService.desbloquearVendedor(vendedorId),
        ));
  }
}
