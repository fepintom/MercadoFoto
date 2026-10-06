import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/chat_servicio_screen.dart';
import '../screens/perfil_publico_screen.dart';
import '../screens/servicio_detalle_screen.dart';
import '../services/api_service.dart';
import '../services/contenido_oculto_service.dart';
import '../services/favoritos_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

/// Acciones sobre un servicio, con la misma forma que AccionesProducto:
/// contactar (cotizar por el chat), compartir y el menú de los tres puntos.
class AccionesServicio {
  AccionesServicio._();

  static String _titulo(Map s) => (s['titulo'] ?? 'Servicio').toString();
  static String nombreProveedor(Map s) => [s['nombre'], s['apellido']]
      .where((x) => x != null && '$x'.trim().isNotEmpty)
      .join(' ');

  static void _aviso(BuildContext context, String texto,
      {SnackBarAction? accion}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        backgroundColor: colors.carbon,
        behavior: SnackBarBehavior.floating,
        action: accion,
      ));
  }

  /// Contactar: abre el chat del servicio. Es el canal principal (y no la
  /// llamada): ahí el proveedor puede mandar una cotización formal, el pago
  /// queda protegido y ningún número de teléfono queda expuesto.
  static Future<void> contactar(
      BuildContext context, Map<String, dynamic> s) async {
    final uid = await SessionService.obtenerUser();
    if (!context.mounted) return;
    if (uid == null) {
      _aviso(context, 'Inicia sesión para contactar al proveedor');
      return;
    }
    final provId = (s['user_id'] as num?)?.toInt();
    final id = (s['id'] as num?)?.toInt();
    if (provId == null || id == null) return;
    if (provId == uid) {
      _aviso(context, 'Es tu propio servicio');
      return;
    }
    ApiService.registrarContactoServicio(id, uid, 'chat', '').catchError((_) {});
    final esBusco = s['tipo'] == 'busco';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatServicioScreen(
          servicioId: id,
          proveedorId: provId,
          clienteId: uid,
          tituloServicio: _titulo(s),
          nombreProveedor: nombreProveedor(s),
          mensajeInicial: esBusco
              ? 'Hola, vi lo que necesitas ("${_titulo(s)}") y puedo ayudarte.'
              : 'Hola, me interesa "${_titulo(s)}". ¿Me envías una cotización?',
        ),
      ),
    );
  }

  static Future<void> compartir(BuildContext context, Map s) async {
    final valor = s['valor'];
    final precio = (valor is num && valor > 0) ? ' desde ${formatPrecio(valor)}' : '';
    final texto = 'Mira este servicio en OkVenta: ${_titulo(s)}$precio. '
        'Búscalo en la app OkVenta.';
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
                  Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}'),
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

  static Future<void> mostrarMenu(
      BuildContext context, Map<String, dynamic> s) async {
    final uid = await SessionService.obtenerUser();
    if (!context.mounted) return;
    final provId = (s['user_id'] as num?)?.toInt();
    final id = (s['id'] as num?)?.toInt();
    final esMio = uid != null && provId == uid;
    final nombre = nombreProveedor(s).isEmpty ? 'el proveedor' : nombreProveedor(s);

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

        final guardado = FavoritosService.esServicio(id);
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
            opcion(Icons.info_outline_rounded, 'Ver el servicio',
                () => ir(ServicioDetalleScreen(servicio: s))),
            if (provId != null)
              opcion(Icons.person_outline_rounded, 'Ver perfil de $nombre',
                  () => ir(PerfilPublicoScreen(userId: provId, nombre: nombre))),
            if (!esMio && id != null)
              opcion(
                  guardado
                      ? Icons.bookmark_remove_outlined
                      : Icons.bookmark_add_outlined,
                  guardado ? 'Quitar de guardados' : 'Guardar servicio',
                  () async {
                Navigator.pop(ctx);
                if (uid == null) {
                  _aviso(context, 'Inicia sesión para guardar servicios');
                  return;
                }
                final ahora = await FavoritosService.alternarServicio(uid, id);
                if (context.mounted) {
                  _aviso(context, ahora ? 'Servicio guardado' : 'Quitado de guardados');
                }
              }),
            opcion(Icons.ios_share_rounded, 'Compartir', () {
              Navigator.pop(ctx);
              compartir(context, s);
            }),
            if (!esMio)
              opcion(Icons.request_quote_outlined, 'Contactar y cotizar', () {
                Navigator.pop(ctx);
                contactar(context, s);
              }),
            if (!esMio && id != null)
              opcion(Icons.visibility_off_outlined, 'No me interesa', () {
                Navigator.pop(ctx);
                ContenidoOcultoService.ocultarServicio(id);
                _aviso(context, 'No volverás a ver este servicio',
                    accion: SnackBarAction(
                      label: 'Deshacer',
                      textColor: Colors.white,
                      onPressed: () => ContenidoOcultoService.mostrarServicio(id),
                    ));
              }),
            if (!esMio && id != null)
              opcion(Icons.flag_outlined, 'Reportar servicio', () {
                Navigator.pop(ctx);
                _reportar(context, s, uid);
              }, rojo: true),
            if (!esMio && provId != null)
              opcion(Icons.block_rounded, 'Bloquear a $nombre', () async {
                Navigator.pop(ctx);
                await ContenidoOcultoService.bloquearVendedor(provId);
                if (!context.mounted) return;
                _aviso(context, 'Bloqueaste a $nombre',
                    accion: SnackBarAction(
                      label: 'Deshacer',
                      textColor: Colors.white,
                      onPressed: () =>
                          ContenidoOcultoService.desbloquearVendedor(provId),
                    ));
              }, rojo: true),
            const SizedBox(height: 6),
          ]),
        );
      },
    );
  }

  static Future<void> _reportar(BuildContext context, Map s, int? uid) async {
    if (uid == null) {
      _aviso(context, 'Inicia sesión para reportar');
      return;
    }
    const motivos = [
      'Parece una estafa',
      'Servicio prohibido o ilegal',
      'Información o precio engañoso',
      'Fotos o texto ofensivo',
      'Otro motivo',
    ];
    final motivo = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text('¿Por qué lo reportas?',
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
        numeroReferencia: 'Servicio #${s['id']}',
        detalle: 'Reporte de servicio "${_titulo(s)}": $motivo',
      );
      if (context.mounted) {
        _aviso(context, 'Gracias. El equipo de OkVenta lo va a revisar.');
      }
    } catch (_) {
      if (context.mounted) _aviso(context, 'No se pudo enviar el reporte.');
    }
  }
}
