import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/chat_privado_screen.dart';
import '../services/api_service.dart';
import '../services/privados_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

/// Acciones de una orden en "Mis compras" / "Mis ventas":
/// - cancelar dentro de la primera hora (con temporizador),
/// - ver el pago de una venta,
/// - compartir el comprobante por el chat de OkVenta o por WhatsApp.
class OrdenAcciones {
  OrdenAcciones._();

  static const minutosCancelacion = 60;

  // ── Fechas ────────────────────────────────────────────────────────────

  /// Las fechas del servidor vienen en UTC ("2026-10-16 21:05:00").
  static DateTime? fechaUtc(dynamic ts) {
    if (ts == null) return null;
    final s = ts.toString().trim();
    if (s.isEmpty) return null;
    final iso = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(iso.endsWith('Z') || iso.contains('+')
        ? iso
        : '${iso}Z');
  }

  static String fechaHora(dynamic ts) {
    final d = fechaUtc(ts)?.toLocal();
    if (d == null) return '—';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year} ${dos(d.hour)}:${dos(d.minute)}';
  }

  /// Tiempo que queda para cancelar (null si ya no se puede).
  static Duration? restanteCancelacion(Map orden) {
    final estado = (orden['estado'] ?? '').toString();
    if (estado != 'pendiente_pago' && estado != 'pago_confirmado') return null;
    final creada = fechaUtc(orden['created_at']);
    if (creada == null) return null;
    final fin = creada.add(const Duration(minutes: minutosCancelacion));
    final r = fin.difference(DateTime.now().toUtc());
    return r.isNegative ? null : r;
  }

  static String mmss(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Cancelar ──────────────────────────────────────────────────────────

  /// Pide confirmación y cancela. Devuelve true si se canceló.
  static Future<bool> cancelar(BuildContext context, Map orden) async {
    final esServicio = orden['tipo'] == 'servicio';
    final pagada = (orden['estado'] ?? '') == 'pago_confirmado';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(esServicio ? '¿Cancelar el servicio?' : '¿Cancelar la compra?',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: colors.textPrimary)),
        content: Text(
            '${pagada ? 'Te devolvemos el pago completo. ' : ''}'
            'Solo se puede cancelar dentro de la primera hora del pedido; '
            'después ya no es posible.',
            style: TextStyle(fontSize: 14, color: colors.textPrimary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(esServicio ? 'Cancelar servicio' : 'Cancelar compra'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return false;
    final uid = await SessionService.obtenerUser();
    if (uid == null) return false;
    try {
      final r = await http
          .post(
            Uri.parse(
                '${ApiService.baseUrl}/ordenes/${orden['id']}/cancelar_compra'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': uid}),
          )
          .timeout(const Duration(seconds: 30));
      final body = jsonDecode(utf8.decode(r.bodyBytes));
      if (!context.mounted) return false;
      if (r.statusCode == 200) {
        _aviso(
            context,
            body['reembolsado'] == true
                ? 'Cancelado. Te devolvimos el pago.'
                : 'Pedido cancelado.');
        return true;
      }
      _aviso(context, (body['detail'] ?? 'No se pudo cancelar').toString());
    } catch (_) {
      if (context.mounted) _aviso(context, 'No se pudo cancelar. Intenta de nuevo.');
    }
    return false;
  }

  static void _aviso(BuildContext context, String t) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(t),
        backgroundColor: colors.carbon,
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ── Ver pago ──────────────────────────────────────────────────────────

  static Future<void> verPago(BuildContext context, Map orden) async {
    final uid = await SessionService.obtenerUser();
    if (uid == null || !context.mounted) return;
    final prefs = await SharedPreferences.getInstance();
    String p(String k) => (prefs.getString(k) ?? '').trim();
    final banco = p('banco');
    final tipoCuenta = p('tipo_cuenta');
    final numero = p('numero_cuenta');
    final titular = [p('nombre'), p('apellido')]
        .where((x) => x.isNotEmpty)
        .join(' ');
    final rut = p('rut');
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _cargarPago(orden['id'], uid),
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()));
            }
            final d = snap.data;
            if (d == null) {
              return SizedBox(
                height: 160,
                child: Center(
                    child: Text('No se pudo cargar el pago',
                        style: TextStyle(color: colors.textPrimary))),
              );
            }
            Widget fila(IconData i, String a, String b, {bool fuerte = false}) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(i, size: 18, color: colors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(a,
                              style: TextStyle(
                                  fontSize: 13, color: colors.textSecondary)),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(b,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: fuerte ? 16 : 13.5,
                                  fontWeight:
                                      fuerte ? FontWeight.w900 : FontWeight.w700,
                                  color: fuerte
                                      ? colors.primary
                                      : colors.textPrimary)),
                        ),
                      ]),
                );
            final cuenta = numero.isEmpty
                ? 'Sin cuenta registrada'
                : '${tipoCuenta.isEmpty ? 'Cuenta' : tipoCuenta} '
                    '•••• ${numero.length > 4 ? numero.substring(numero.length - 4) : numero}';
            final abonado = d['abonado_en'];
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: colors.divider,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Icon(Icons.account_balance_wallet_rounded,
                        color: colors.primary),
                    const SizedBox(width: 8),
                    Text('Pago de la venta',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary)),
                  ]),
                  const SizedBox(height: 2),
                  Text('${d['titulo'] ?? ''} · Orden #${d['orden_id']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: colors.textSecondary)),
                  const SizedBox(height: 10),
                  // Estado del abono, destacado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (abonado != null ? Colors.green : colors.primary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(d['estado_abono']?.toString() ?? '',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: abonado != null
                                ? Colors.green.shade700
                                : colors.primary)),
                  ),
                  const SizedBox(height: 6),
                  fila(Icons.credit_card_rounded, 'Medio de pago',
                      (d['medio_pago'] ?? '—').toString()),
                  fila(Icons.event_available_rounded, 'Pagado por el comprador',
                      fechaHora(d['pagado_en'])),
                  fila(Icons.schedule_send_rounded, 'Fecha y hora del abono',
                      abonado == null ? 'Pendiente' : fechaHora(abonado)),
                  Divider(color: colors.divider),
                  fila(Icons.account_balance_rounded, 'Banco de destino',
                      banco.isEmpty ? 'Sin banco registrado' : banco),
                  fila(Icons.numbers_rounded, 'Cuenta de abono', cuenta),
                  if (titular.isNotEmpty)
                    fila(Icons.person_rounded, 'Titular',
                        rut.isEmpty ? titular : '$titular · $rut'),
                  Divider(color: colors.divider),
                  fila(Icons.receipt_rounded, 'Total pagado',
                      formatPrecio(d['monto'])),
                  fila(Icons.percent_rounded, 'Comisión OkVenta',
                      '− ${formatPrecio(d['comision'])}'),
                  fila(Icons.savings_rounded, 'Recibes', formatPrecio(d['neto']),
                      fuerte: true),
                  if ((d['operacion_mp'] ?? '').toString().isNotEmpty)
                    fila(Icons.tag_rounded, 'N.º de operación',
                        d['operacion_mp'].toString()),
                  if (numero.isEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                        'Registra tu banco y cuenta en Mi OkVenta → Mi cuenta '
                        'para recibir los abonos.',
                        style: TextStyle(
                            fontSize: 12.5, color: colors.textSecondary)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static Future<Map<String, dynamic>?> _cargarPago(dynamic id, int uid) async {
    try {
      final r = await http
          .get(Uri.parse('${ApiService.baseUrl}/ordenes/$id/pago?user_id=$uid'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {
      return null;
    }
  }

  // ── Compartir comprobante ─────────────────────────────────────────────

  static Map<String, dynamic> datosComprobante(Map orden,
      {required bool esCompra, required String estadoTexto}) {
    final esServicio = orden['tipo'] == 'servicio';
    return {
      'n': orden['id'],
      't': (orden['titulo'] ?? '').toString(),
      'm': orden['monto'],
      'e': estadoTexto,
      'f': fechaHora(orden['created_at']),
      'k': esCompra ? 'compra' : 'venta',
      's': esServicio ? 'servicio' : 'producto',
      'c': (esCompra
              ? orden['nombre_vendedor']
              : orden['nombre_comprador'])
          ?.toString(),
    };
  }

  static Future<void> compartir(BuildContext context, Map orden,
      {required bool esCompra, required String estadoTexto}) async {
    final datos =
        datosComprobante(orden, esCompra: esCompra, estadoTexto: estadoTexto);
    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Compartir comprobante',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary)),
            const SizedBox(height: 12),
            TarjetaComprobante(datos: datos),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _compartirEnChat(context, orden, datos, esCompra: esCompra);
                  },
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('Chat OkVenta'),
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
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final bytes = await pdfComprobante(datos);
                    await Printing.sharePdf(
                        bytes: bytes,
                        filename: 'Comprobante_OkVenta_${datos['n']}.pdf');
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  static const _marca = '[comprobante]';

  static String textoChat(Map<String, dynamic> datos) =>
      '$_marca${jsonEncode(datos)}';

  /// Si un mensaje del chat es un comprobante, sus datos.
  static Map<String, dynamic>? deTexto(String texto) {
    if (!texto.startsWith(_marca)) return null;
    try {
      return Map<String, dynamic>.from(
          jsonDecode(texto.substring(_marca.length)) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _compartirEnChat(
      BuildContext context, Map orden, Map<String, dynamic> datos,
      {required bool esCompra}) async {
    final yo = await SessionService.obtenerUser();
    if (yo == null || !context.mounted) return;
    final convs = await PrivadosService.conversaciones(yo);
    if (!context.mounted) return;
    // La otra parte de la orden va primero (lo más común: mandárselo a él).
    final otroId = (esCompra ? orden['vendedor_id'] : orden['comprador_id'])
        as int?;
    final otroNombre = (esCompra
            ? orden['nombre_vendedor']
            : orden['nombre_comprador'])
        ?.toString();
    final destinos = <Map<String, dynamic>>[
      if (otroId != null && otroId != yo)
        {'id': otroId, 'nombre': otroNombre ?? 'Usuario', 'foto': null},
      for (final c in convs)
        if (c['otro_id'] != otroId)
          {
            'id': c['otro_id'],
            'nombre': c['otro_nombre'] ?? 'Usuario',
            'foto': c['otro_foto'],
          },
    ];
    final elegido = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Text('¿A quién se lo mandas?',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary)),
            const SizedBox(height: 6),
            if (destinos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                    'Aún no tienes conversaciones. Abre una tocando a una '
                    'persona en Comunidad.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary)),
              ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final d in destinos)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colors.primary.withValues(alpha: 0.12),
                      child: Text(
                          (d['nombre'] as String).isEmpty
                              ? 'U'
                              : (d['nombre'] as String)[0].toUpperCase(),
                          style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w800)),
                    ),
                    title: Text(d['nombre'].toString(),
                        style: TextStyle(color: colors.textPrimary)),
                    subtitle: d['id'] == otroId
                        ? Text(esCompra ? 'Vendedor de esta compra' : 'Comprador',
                            style: TextStyle(
                                fontSize: 12, color: colors.textSecondary))
                        : null,
                    onTap: () => Navigator.pop(ctx, d),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (elegido == null || !context.mounted) return;
    final r = await PrivadosService.enviar(
        deId: yo, paraId: elegido['id'] as int, texto: textoChat(datos));
    if (!context.mounted) return;
    if (r == null) {
      _aviso(context, 'No se pudo enviar. Intenta de nuevo.');
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('Comprobante enviado a ${elegido['nombre']}'),
        backgroundColor: colors.carbon,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Abrir chat',
          textColor: Colors.white,
          onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                  builder: (_) => ChatPrivadoScreen(
                      otroId: elegido['id'] as int,
                      nombre: elegido['nombre'].toString()))),
        ),
      ));
  }

  /// Comprobante en PDF (tamaño A6): como la cotización de OkVenta pero
  /// resumido, con Okventín al pie.
  static Future<Uint8List> pdfComprobante(Map<String, dynamic> d) async {
    const rojo = PdfColor.fromInt(0xFFC0545C);
    const tinta = PdfColor.fromInt(0xFF22262E);
    const gris = PdfColor.fromInt(0xFF6E7480);
    const linea = PdfColor.fromInt(0xFFE2E4E9);
    pw.MemoryImage? okventin;
    try {
      final b = await rootBundle.load('assets/images/okventin_compra.png');
      okventin = pw.MemoryImage(b.buffer.asUint8List());
    } catch (_) {}
    final normal = pw.Font.helvetica();
    final negrita = pw.Font.helveticaBold();
    pw.TextStyle st(double t, {bool b = false, PdfColor c = tinta}) =>
        pw.TextStyle(font: b ? negrita : normal, fontSize: t, color: c);
    pw.Widget fila(String a, String b) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(children: [
            pw.Text(a, style: st(8, c: gris)),
            pw.Spacer(),
            pw.Text(b, style: st(8.5, b: true)),
          ]),
        );
    final esVenta = d['k'] == 'venta';
    final esServicio = d['s'] == 'servicio';
    final doc = pw.Document(title: 'Comprobante OkVenta #${d['n']}');
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a6,
      margin: const pw.EdgeInsets.fromLTRB(22, 20, 22, 18),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.RichText(
                text: pw.TextSpan(children: [
              pw.TextSpan(text: 'OK ', style: st(17, b: true, c: rojo)),
              pw.TextSpan(text: 'VENTA', style: st(17, b: true)),
            ])),
            pw.Spacer(),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('COMPROBANTE', style: st(10, b: true)),
              pw.Text('Orden N.º ${d['n']}', style: st(7.5, c: gris)),
            ]),
          ]),
          pw.SizedBox(height: 8),
          pw.Container(height: 0.8, color: linea),
          pw.SizedBox(height: 8),
          pw.Text(
              esServicio
                  ? (esVenta ? 'SERVICIO VENDIDO' : 'SERVICIO CONTRATADO')
                  : (esVenta ? 'PRODUCTO VENDIDO' : 'PRODUCTO COMPRADO'),
              style: st(7, b: true, c: gris)),
          pw.SizedBox(height: 3),
          pw.Text((d['t'] ?? '').toString(), style: st(11, b: true), maxLines: 3),
          pw.SizedBox(height: 8),
          fila('Fecha', (d['f'] ?? '').toString()),
          if ((d['c'] ?? '').toString().isNotEmpty)
            fila(esVenta ? 'Comprador' : 'Vendedor', d['c'].toString()),
          fila('Estado', (d['e'] ?? '').toString()),
          pw.SizedBox(height: 6),
          pw.Container(height: 0.8, color: linea),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Text('TOTAL', style: st(10, b: true)),
            pw.Spacer(),
            pw.Text(formatPrecio(d['m']), style: st(16, b: true, c: rojo)),
          ]),
          pw.Spacer(),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Expanded(
              child: pw.Text(
                  'Compra protegida por OkVenta: el pago queda resguardado '
                  'hasta que se confirma la entrega.',
                  style: st(6.5, c: gris)),
            ),
            if (okventin != null) ...[
              pw.SizedBox(width: 8),
              pw.Image(okventin, height: 46),
            ],
          ]),
        ],
      ),
    ));
    return doc.save();
  }
}

/// Mini comprobante con el diseño de la app (para el chat y la vista
/// previa al compartir).
class TarjetaComprobante extends StatelessWidget {
  final Map<String, dynamic> datos;
  final double ancho;
  const TarjetaComprobante({super.key, required this.datos, this.ancho = 260});

  @override
  Widget build(BuildContext context) {
    final esVenta = datos['k'] == 'venta';
    final esServicio = datos['s'] == 'servicio';
    const tinta = Color(0xFF22262E);
    const gris = Color(0xFF6E7480);
    Widget fila(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(children: [
            Text(a, style: const TextStyle(fontSize: 10.5, color: gris)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(b,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: tinta)),
            ),
          ]),
        );
    return Container(
      width: ancho,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E4E9)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Text.rich(TextSpan(children: [
              TextSpan(
                  text: 'OK ',
                  style: TextStyle(
                      color: Color(0xFFC0545C),
                      fontWeight: FontWeight.w900,
                      fontSize: 14)),
              TextSpan(
                  text: 'VENTA',
                  style: TextStyle(
                      color: tinta, fontWeight: FontWeight.w900, fontSize: 14)),
            ])),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('COMPROBANTE',
                  style: TextStyle(
                      fontSize: 9.5, fontWeight: FontWeight.w900, color: tinta)),
              Text('Orden N.º ${datos['n']}',
                  style: const TextStyle(fontSize: 9, color: gris)),
            ]),
          ]),
          const Divider(height: 14, color: Color(0xFFE2E4E9)),
          Text(
              esServicio
                  ? (esVenta ? 'SERVICIO VENDIDO' : 'SERVICIO CONTRATADO')
                  : (esVenta ? 'PRODUCTO VENDIDO' : 'PRODUCTO COMPRADO'),
              style: const TextStyle(
                  fontSize: 8.5, fontWeight: FontWeight.w800, color: gris)),
          Text((datos['t'] ?? '').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: tinta)),
          const SizedBox(height: 4),
          fila('Fecha', (datos['f'] ?? '').toString()),
          if ((datos['c'] ?? '').toString().isNotEmpty)
            fila(esVenta ? 'Comprador' : 'Vendedor', datos['c'].toString()),
          fila('Estado', (datos['e'] ?? '').toString()),
          const Divider(height: 12, color: Color(0xFFE2E4E9)),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TOTAL',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900, color: tinta)),
              Text(formatPrecio(datos['m']),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFC0545C))),
            ]),
            const Spacer(),
            Image.asset('assets/images/okventin_compra.png',
                height: 40, errorBuilder: (_, __, ___) => const SizedBox()),
          ]),
        ],
      ),
    );
  }
}

/// Botón "Cancelar · 42:10" que cuenta hacia atrás y desaparece al cumplirse
/// la primera hora del pedido.
class BotonCancelarOrden extends StatefulWidget {
  final Map orden;
  final VoidCallback onCancelada;
  const BotonCancelarOrden(
      {super.key, required this.orden, required this.onCancelada});

  @override
  State<BotonCancelarOrden> createState() => _BotonCancelarOrdenState();
}

class _BotonCancelarOrdenState extends State<BotonCancelarOrden> {
  Timer? _t;
  bool _cancelando = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (OrdenAcciones.restanteCancelacion(widget.orden) == null) {
        _t?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = OrdenAcciones.restanteCancelacion(widget.orden);
    if (r == null) return const SizedBox.shrink();
    final esServicio = widget.orden['tipo'] == 'servicio';
    return GestureDetector(
      onTap: _cancelando
          ? null
          : () async {
              setState(() => _cancelando = true);
              final ok = await OrdenAcciones.cancelar(context, widget.orden);
              if (!mounted) return;
              setState(() => _cancelando = false);
              if (ok) widget.onCancelada();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.timer_outlined, size: 14, color: Colors.red),
          const SizedBox(width: 4),
          Text(
              '${esServicio ? 'Cancelar servicio' : 'Cancelar compra'} · '
              '${OrdenAcciones.mmss(r)}',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.red,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }
}

/// Botoncito redondo de acción para las tarjetas de órdenes.
class AccionMini extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final Color? color;
  const AccionMini(
      {super.key,
      required this.icono,
      required this.texto,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? colors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.divider),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 14, color: c),
          const SizedBox(width: 4),
          Text(texto,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
        ]),
      ),
    );
  }
}
