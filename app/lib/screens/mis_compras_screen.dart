import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'analizar_paquete_screen.dart';
import 'calificar_vendedor_screen.dart';
import 'grabar_verificacion_paquete_screen.dart';
import 'seguimiento_entrega_screen.dart';
import 'soporte_chat_screen.dart';

class MisComprasScreen extends StatefulWidget {
  const MisComprasScreen({super.key});

  @override
  State<MisComprasScreen> createState() => _MisComprasScreenState();
}

class _MisComprasScreenState extends State<MisComprasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  int? _userId;
  List<Map<String, dynamic>> _compras = [];
  List<Map<String, dynamic>> _ventas = [];
  bool _cargando = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _cargar();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _cargar(silencioso: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    _userId = await SessionService.obtenerUser();
    if (_userId != null) {
      final compras = await ApiService.obtenerMisCompras(_userId!);
      final ventas = await ApiService.obtenerMisVentas(_userId!);
      if (mounted) {
        setState(() {
          _compras = compras;
          _ventas = ventas;
          _cargando = false;
        });
      }
    } else {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── Estado ─────────────────────────────────────────────────────────────────

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'pendiente_pago':
        return 'Pago pendiente';
      case 'pago_confirmado':
        return 'Pago confirmado';
      case 'en_camino':
        return 'En camino';
      case 'entrega_reportada':
        return 'Confirma recepción';
      case 'entregado':
        return 'Entregado';
      case 'en_disputa':
        return 'En disputa';
      case 'reembolsado':
        return 'Reembolsado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado;
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'pendiente_pago':
        return Colors.orange;
      case 'pago_confirmado':
      case 'en_camino':
        return colors.primary;
      case 'entrega_reportada':
        return Colors.deepOrange;
      case 'entregado':
        return Colors.green;
      case 'en_disputa':
        return Colors.red;
      case 'reembolsado':
        return colors.grayMid;
      case 'cancelado':
        return colors.grayMid;
      default:
        return colors.grayMid;
    }
  }

  IconData _estadoIcon(String estado) {
    switch (estado) {
      case 'pendiente_pago':
        return Icons.schedule_rounded;
      case 'pago_confirmado':
        return Icons.check_circle_outline_rounded;
      case 'en_camino':
        return Icons.local_shipping_outlined;
      case 'entrega_reportada':
        return Icons.photo_camera_outlined;
      case 'entregado':
        return Icons.verified_rounded;
      case 'en_disputa':
        return Icons.report_outlined;
      case 'reembolsado':
        return Icons.undo_rounded;
      case 'cancelado':
        return Icons.cancel_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  // ── Confirmar entrega ──────────────────────────────────────────────────────

  Future<void> _confirmarEntrega(int ordenId) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  size: 32, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Confirmar que recibiste el producto/servicio?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Al confirmar, el vendedor recibirá el pago. Esta acción no se puede deshacer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.grayMid, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancelar',
                        style: TextStyle(color: colors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Recibí conforme',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    try {
      await ApiService.confirmarOrden(ordenId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Entrega confirmada. El vendedor recibirá su pago.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: colors.primary),
      );
    }
  }

  // ── Abrir disputa ──────────────────────────────────────────────────────────

  Future<void> _abrirDisputa(int ordenId) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.report_outlined, size: 32, color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Tuviste un problema?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Abriremos una disputa. Nuestro equipo revisará el caso y se pondrá en contacto contigo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.grayMid, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancelar',
                        style: TextStyle(color: colors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Reportar problema',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    try {
      await ApiService.disputarOrden(ordenId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Disputa abierta. Te contactaremos pronto.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: colors.primary),
      );
    }
  }

  // ── Confirmación de recepción con foto (entrega 'yo') ─────────────────────

  Future<void> _confirmarRecepcionConFoto(int ordenId) async {
    if (_userId == null) return;
    // Solo cámara: la evidencia pierde valor con fotos recicladas de galería.
    final xfile = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 82);
    if (xfile == null || !mounted) return;
    try {
      await ApiService.confirmarRecepcionConFoto(
        ordenId: ordenId,
        userId: _userId!,
        foto: File(xfile.path),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Recepción confirmada. ¡Gracias por comprar en OkVenta!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: colors.primary),
      );
    }
  }

  Future<void> _reportarProblema(int ordenId) async {
    if (_userId == null) return;
    String motivo = 'no_llego';
    final descripcionCtrl = TextEditingController();
    File? fotoReclamo;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reportar un problema',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const SizedBox(height: 14),
              ...[
                ('no_llego', 'El pedido nunca llegó'),
                ('dañado', 'Llegó dañado'),
                ('distinto', 'No es lo que compré'),
                ('otro', 'Otro problema'),
              ].map((m) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.$2, style: const TextStyle(fontSize: 14)),
                    value: m.$1,
                    groupValue: motivo,
                    activeColor: colors.primary,
                    onChanged: (v) => setSheet(() => motivo = v!),
                  )),
              TextField(
                controller: descripcionCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe el problema (opcional)',
                  hintStyle: TextStyle(
                      fontSize: 13, color: colors.grayMid),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final x = await ImagePicker().pickImage(
                      source: ImageSource.camera, imageQuality: 82);
                  if (x != null) setSheet(() => fotoReclamo = File(x.path));
                },
                icon: Icon(
                    fotoReclamo == null
                        ? Icons.photo_camera_outlined
                        : Icons.check_circle_rounded,
                    size: 16),
                label: Text(fotoReclamo == null
                    ? 'Agregar foto (opcional)'
                    : 'Foto agregada'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: fotoReclamo == null
                      ? colors.grayMid
                      : Colors.green,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Enviar reporte'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true || !mounted) return;
    try {
      await ApiService.reportarProblemaOrden(
        ordenId: ordenId,
        userId: _userId!,
        motivo: motivo,
        descripcion: descripcionCtrl.text.trim(),
        fotoReclamo: fotoReclamo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Problema reportado. OkVenta mediará el caso.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: colors.primary),
      );
    }
  }

  // ── Tarjeta de orden ───────────────────────────────────────────────────────

  Widget _tarjetaOrden(Map<String, dynamic> orden, {bool esCompra = true}) {
    final id = orden['id'] as int? ?? 0;
    final titulo = orden['titulo'] as String? ?? 'Orden #$id';
    final monto = (orden['monto'] as num?)?.toDouble() ?? 0;
    final estado = orden['estado'] as String? ?? 'pendiente_pago';
    final tipo = orden['tipo'] as String? ?? 'producto';
    final fecha = orden['created_at'] as String? ?? '';
    final contraparte = esCompra
        ? (orden['nombre_vendedor'] as String? ?? 'Vendedor')
        : (orden['nombre_comprador'] as String? ?? 'Comprador');

    final deliveryMethod = orden['delivery_method'] as String?;
    final esOkdelivery = deliveryMethod == 'okventa';
    final esEntregaVendedor = deliveryMethod == 'yo';

    // La entrega del vendedor ('yo') usa el flujo nuevo con foto:
    // el comprador confirma solo cuando el vendedor reportó la entrega.
    final puedeConfirmar = esCompra && !esOkdelivery && !esEntregaVendedor &&
        (estado == 'pago_confirmado' || estado == 'en_camino');
    final puedeDisputar = esCompra && !esOkdelivery && !esEntregaVendedor &&
        (estado == 'pago_confirmado' || estado == 'en_camino');
    final debeConfirmarRecepcion = esCompra && estado == 'entrega_reportada';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: tipo badge + fecha
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tipo == 'producto'
                        ? colors.carbon.withOpacity(0.1)
                        : colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tipo == 'producto' ? 'Producto' : 'Servicio',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tipo == 'producto'
                            ? colors.textPrimary
                            : colors.primary),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatFecha(fecha),
                  style: TextStyle(
                      fontSize: 11, color: colors.grayMid),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Título
            Text(
              titulo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary),
            ),

            const SizedBox(height: 4),

            // Contraparte
            Row(
              children: [
                Icon(
                  esCompra ? Icons.store_outlined : Icons.person_outline,
                  size: 13,
                  color: colors.grayMid,
                ),
                const SizedBox(width: 4),
                Text(
                  contraparte,
                  style: TextStyle(
                      fontSize: 12, color: colors.grayMid),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 12),

            // Monto + estado
            Row(
              children: [
                Text(
                  '\$${monto.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _estadoColor(estado).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_estadoIcon(estado),
                          size: 14, color: _estadoColor(estado)),
                      const SizedBox(width: 5),
                      Text(
                        _estadoLabel(estado),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _estadoColor(estado)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Botones de acción (solo comprador, solo si corresponde)
            if (puedeConfirmar) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmarEntrega(id),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Recibí conforme'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (puedeDisputar) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        // El backend acepta el flujo completo (motivo+foto)
                        // desde 'en_camino'; el diálogo simple solo aplica a
                        // 'pago_confirmado', donde aún no hay nada que
                        // fotografiar porque el vendedor ni siquiera despachó.
                        onPressed: () => estado == 'en_camino'
                            ? _reportarProblema(id)
                            : _abrirDisputa(id),
                        icon: const Icon(Icons.report_outlined, size: 16),
                        label: const Text('Tuve un problema'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(
                              color: Colors.red, width: 1),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // Doble confirmación: el vendedor reportó la entrega con foto,
            // ahora el comprador confirma (o reporta un problema).
            if (debeConfirmarRecepcion) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmarRecepcionConFoto(id),
                      icon: const Icon(Icons.photo_camera_rounded, size: 16),
                      label: const Text('Recibí el paquete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reportarProblema(id),
                      icon: const Icon(Icons.report_outlined, size: 16),
                      label: const Text('Tuve un problema'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (esCompra && esOkdelivery &&
                (estado == 'pago_confirmado' || estado == 'en_camino')) ...[
              _OkdeliveryCompradorPanel(ordenId: id),
            ],

            // El vendedor entrega en persona: ver dónde viene en el mapa.
            if (esCompra && deliveryMethod == 'yo' &&
                estado == 'en_camino') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SeguimientoEntregaScreen(
                          ordenId: id,
                          titulo: orden['titulo'] as String? ?? '',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_rounded, size: 17),
                  label: const Text('Ver dónde viene el vendedor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => _reportarProblema(id),
                  child: const Text('¿El pedido nunca llegó? Reportar problema',
                      style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ),
            ],

            // Compra ya entregada y aún sin calificar: invitamos a calificar
            // al vendedor. La calificación queda amarrada a esta orden.
            if (esCompra && estado == 'entregado' &&
                (orden['ya_calificado'] as int? ?? 0) == 0) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final vendedorId = orden['vendedor_id'] as int?;
                    if (vendedorId == null) return;
                    final ok = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CalificarVendedorScreen(
                          ordenId: id,
                          vendedorId: vendedorId,
                          compradorId: orden['comprador_id'] as int? ?? 0,
                          nombreVendedor: contraparte,
                          tituloProducto: titulo,
                        ),
                      ),
                    );
                    if (ok == true) _cargar();
                  },
                  icon: Icon(Icons.star_outline_rounded,
                      size: 17, color: colors.primary),
                  label: const Text('Calificar vendedor',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Banner fijo de entregas activas ────────────────────────────────────────
  // Visible arriba de la lista para cualquier orden en en_camino o
  // entrega_reportada: el usuario no debe buscar la tarjeta para actuar.

  Widget _bannerActivas(List<Map<String, dynamic>> ordenes,
      {required bool esCompra}) {
    final activas = ordenes.where((o) {
      final e = o['estado'] as String? ?? '';
      return e == 'en_camino' || e == 'entrega_reportada';
    }).toList();
    if (activas.isEmpty) return const SizedBox.shrink();

    final o = activas.first;
    final id = o['id'] as int? ?? 0;
    final titulo = o['titulo'] as String? ?? '';
    final estado = o['estado'] as String? ?? '';
    final delivery = o['delivery_method'] as String?;
    final reportada = estado == 'entrega_reportada';

    final String texto;
    if (esCompra) {
      texto = reportada
          ? 'Confirma la recepción de "$titulo"'
          : 'Tu pedido "$titulo" viene en camino';
    } else {
      texto = reportada
          ? 'Esperando confirmación del comprador por "$titulo"'
          : 'Tienes una entrega en curso: "$titulo"';
    }

    return GestureDetector(
      onTap: () {
        if (esCompra && reportada) {
          _confirmarRecepcionConFoto(id);
        } else if (esCompra && estado == 'en_camino' && delivery == 'yo') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SeguimientoEntregaScreen(ordenId: id, titulo: titulo),
            ),
          );
        }
        // Vendedor: la tarjeta con acciones está justo debajo.
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: reportada
              ? Colors.deepOrange.withOpacity(0.08)
              : colors.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: reportada
                ? Colors.deepOrange.withOpacity(0.45)
                : colors.primary.withOpacity(0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              reportada
                  ? Icons.photo_camera_rounded
                  : Icons.local_shipping_rounded,
              size: 20,
              color: reportada ? Colors.deepOrange : colors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: reportada
                          ? Colors.deepOrange.shade700
                          : colors.primary,
                    ),
                  ),
                  if (activas.length > 1)
                    Text(
                      '+${activas.length - 1} entrega(s) más activa(s)',
                      style: TextStyle(
                          fontSize: 11, color: colors.grayMid),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: colors.grayMid),
          ],
        ),
      ),
    );
  }

  String _formatFecha(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso.substring(0, iso.length > 10 ? 10 : iso.length);
    }
  }

  Widget _listaVacia(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56, color: colors.grayMid.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  color: colors.grayMid,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Mis órdenes',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded,
                color: colors.textPrimary),
            tooltip: 'Ayuda',
            onPressed: () {
              // Con contexto: si hay una compra activa, pasar su orden al agente
              final activa = _compras.firstWhere(
                (o) => ['pago_confirmado', 'en_camino', 'entrega_reportada']
                    .contains(o['estado']),
                orElse: () => <String, dynamic>{},
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SoporteChatScreen(ordenId: activa['id'] as int?),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tab,
            labelColor: colors.primary,
            unselectedLabelColor: colors.grayMid,
            indicatorColor: colors.primary,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14),
            tabs: const [
              Tab(text: 'Mis compras'),
              Tab(text: 'Mis ventas'),
            ],
          ),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _userId == null
              ? _listaVacia('Debes iniciar sesión para ver tus órdenes')
              : TabBarView(
                  controller: _tab,
                  children: [
                    // Compras
                    RefreshIndicator(
                      onRefresh: _cargar,
                      color: colors.primary,
                      child: _compras.isEmpty
                          ? _listaVacia('Aún no has realizado compras')
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _compras.length + 1,
                              itemBuilder: (_, i) => i == 0
                                  ? _bannerActivas(_compras, esCompra: true)
                                  : _tarjetaOrden(_compras[i - 1],
                                      esCompra: true),
                            ),
                    ),

                    // Ventas
                    RefreshIndicator(
                      onRefresh: _cargar,
                      color: colors.primary,
                      child: _ventas.isEmpty
                          ? _listaVacia('Aún no tienes ventas')
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _ventas.length + 1,
                              itemBuilder: (_, i) => i == 0
                                  ? _bannerActivas(_ventas, esCompra: false)
                                  : _tarjetaOrden(_ventas[i - 1],
                                      esCompra: false),
                            ),
                    ),
                  ],
                ),
    );
  }
}

// ── Panel OkDelivery para el comprador ─────────────────────────────────────
//
// Se muestra en la tarjeta de "Mis compras" cuando la entrega es OkDelivery.
// Mientras el repartidor está en camino, muestra su ubicación en vivo.
// Cuando ya fue entregado, permite confirmar recepción (con video de
// unboxing) o reportar un problema (texto + video adjunto).

class _OkdeliveryCompradorPanel extends StatefulWidget {
  final int ordenId;
  const _OkdeliveryCompradorPanel({required this.ordenId});

  @override
  State<_OkdeliveryCompradorPanel> createState() =>
      _OkdeliveryCompradorPanelState();
}

class _OkdeliveryCompradorPanelState
    extends State<_OkdeliveryCompradorPanel> {
  Map<String, dynamic>? _entrega;
  Map<String, dynamic>? _tracking;
  Timer? _pollTimer;
  bool _enviando = false;
  final _picker = ImagePicker();

  static const _estadosCerrados = {
    'cerrado_ok',
    'cerrado_con_reclamo',
    'cancelado_sin_reparar',
  };

  static const _estadoLabel = {
    'buscando_repartidor': 'Buscando un repartidor OkDelivery…',
    'asignado': 'Repartidor asignado, en camino a retirar tu producto',
    'en_camino_retiro': 'El repartidor va en camino a retirar tu producto',
    'llegado_retiro': 'El repartidor llegó donde el vendedor',
    'esperando_confirmacion_calidad': 'El repartidor está revisando el producto',
    'observaciones_reportadas': 'El repartidor reportó una observación al vendedor',
    'reparacion_reportada': 'El vendedor está reparando el producto',
    'en_camino_entrega': 'Tu producto viene en camino',
    'llegado_entrega': 'El repartidor llegó con tu producto',
    'cancelado_sin_reparar': 'La venta fue cancelada y reembolsada',
    'cerrado_ok': 'Recepción confirmada',
    'cerrado_con_reclamo': 'Reportaste un problema — en revisión',
  };

  @override
  void initState() {
    super.initState();
    _cargar();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 8), (_) => _cargar());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final entrega =
          await ApiService.obtenerEntregaOkdelivery(widget.ordenId);
      Map<String, dynamic>? tracking;
      if (entrega != null &&
          !_estadosCerrados.contains(entrega['estado']) &&
          entrega['estado'] != 'entregado_pendiente_confirmacion') {
        tracking = await ApiService.trackingOkdelivery(widget.ordenId);
      }
      if (mounted) setState(() { _entrega = entrega; _tracking = tracking; });
      if (entrega != null && _estadosCerrados.contains(entrega['estado'])) {
        _pollTimer?.cancel();
      }
    } catch (_) {}
  }

  void _mostrarError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: colors.primary),
    );
  }

  Future<void> _confirmarRecepcion() async {
    // Verificación antifraude: primero se graba el unboxing con la rejilla
    // (mismo encuadre que usó el vendedor al embalar) y se ofrece analizarlo
    // con IA antes de confirmar la recepción y liberar los fondos.
    final tituloOrden = 'Orden #${widget.ordenId}';
    final grabado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GrabarVerificacionPaqueteScreen(
          ordenId: widget.ordenId,
          tituloProducto: tituloOrden,
          esUnboxing: true,
        ),
      ),
    );
    if (grabado == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnalizarPaqueteScreen(
            ordenId: widget.ordenId,
            tituloProducto: tituloOrden,
          ),
        ),
      );
    }

    if (_enviando) return;
    setState(() => _enviando = true);
    try {
      await ApiService.confirmarRecepcionComprador(widget.ordenId);
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Recepción confirmada. Los fondos fueron liberados.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _reportarProblema() async {
    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReclamoSheet(picker: _picker),
    );
    if (resultado == null) return;

    setState(() => _enviando = true);
    try {
      await ApiService.reclamoComprador(
        ordenId: widget.ordenId,
        texto: resultado['texto'] as String,
        video: resultado['video'] as File,
      );
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Reclamo enviado. Nuestro equipo lo revisará.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entrega = _entrega;
    if (entrega == null) return const SizedBox.shrink();
    final estado = entrega['estado'] as String? ?? '';
    final esperandoComprador = estado == 'entregado_pendiente_confirmacion';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.delivery_dining_rounded,
                  size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  esperandoComprador
                      ? 'Tu producto fue entregado'
                      : (_estadoLabel[estado] ?? estado),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green),
                ),
              ),
            ],
          ),

          if (_tracking != null &&
              _tracking!['delivery_lat'] != null &&
              _tracking!['delivery_lng'] != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 140,
                child: FlutterMap(
                  options: MapOptions(
                    center: ll.LatLng(
                      (_tracking!['delivery_lat'] as num).toDouble(),
                      (_tracking!['delivery_lng'] as num).toDouble(),
                    ),
                    zoom: 14,
                    interactiveFlags: InteractiveFlag.none,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.okventa.app',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: ll.LatLng(
                          (_tracking!['delivery_lat'] as num).toDouble(),
                          (_tracking!['delivery_lng'] as num).toDouble(),
                        ),
                        width: 34,
                        height: 34,
                        builder: (_) => const Icon(Icons.two_wheeler_rounded,
                            color: Colors.green, size: 28),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],

          if (esperandoComprador) ...[
            const SizedBox(height: 10),
            Text(
              'Graba un video de unboxing sin cortes al confirmar. Tienes 1 hora, si no respondes se dará por recibido automáticamente.',
              style: TextStyle(fontSize: 11, color: colors.grayMid, height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _enviando ? null : _confirmarRecepcion,
                    icon: const Icon(Icons.videocam_rounded, size: 16),
                    label: const Text('Confirmar recepción'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _enviando ? null : _reportarProblema,
                    icon: const Icon(Icons.report_outlined, size: 16),
                    label: const Text('Tengo un problema'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Hoja de reclamo: texto (máx 500) + video ────────────────────────────────

class _ReclamoSheet extends StatefulWidget {
  final ImagePicker picker;
  const _ReclamoSheet({required this.picker});

  @override
  State<_ReclamoSheet> createState() => _ReclamoSheetState();
}

class _ReclamoSheetState extends State<_ReclamoSheet> {
  final _textoCtrl = TextEditingController();
  File? _video;
  bool _grabando = false;

  @override
  void dispose() {
    _textoCtrl.dispose();
    super.dispose();
  }

  Future<void> _grabarVideo() async {
    setState(() => _grabando = true);
    try {
      final xfile = await widget.picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 3),
      );
      if (xfile != null && mounted) setState(() => _video = File(xfile.path));
    } finally {
      if (mounted) setState(() => _grabando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Reportar un problema',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Cuéntanos qué pasó. Tu video de unboxing se adjuntará automáticamente.',
            style: TextStyle(fontSize: 12, color: colors.grayMid),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textoCtrl,
            maxLength: 500,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Describe el problema (máx. 500 caracteres)…',
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _grabando ? null : _grabarVideo,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _video != null ? Colors.green : colors.divider,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _video != null
                        ? Icons.check_circle_rounded
                        : Icons.videocam_outlined,
                    size: 18,
                    color: _video != null ? Colors.green : colors.grayMid,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _grabando
                        ? 'Grabando…'
                        : (_video != null
                            ? 'Video grabado — toca para regrabar'
                            : 'Grabar video del unboxing'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _video != null
                          ? Colors.green
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_textoCtrl.text.trim().isNotEmpty && _video != null)
                  ? () => Navigator.pop(context, {
                        'texto': _textoCtrl.text.trim(),
                        'video': _video,
                      })
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Enviar reclamo',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
