import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'producto_detalle_screen.dart';
import 'seleccionar_entrega_screen.dart';

class MisVentasScreen extends StatefulWidget {
  const MisVentasScreen({super.key});

  @override
  State<MisVentasScreen> createState() => _MisVentasScreenState();
}

class _MisVentasScreenState extends State<MisVentasScreen> {
  List<Map<String, dynamic>> _ventas = [];
  bool _cargando = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _userId = await SessionService.obtenerUser();
    if (_userId == null) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final data = await ApiService.obtenerMisVentas(_userId!);
      if (mounted) setState(() { _ventas = data; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── Estado y color ──────────────────────────────────────────────────────────
  static const _estadoLabel = {
    'pendiente_pago':  'Pendiente de pago',
    'pago_confirmado': 'Pago confirmado',
    'en_camino':       'En camino',
    'entregado':       'Entregado',
    'en_disputa':      'En disputa',
    'reembolsado':     'Reembolsado',
    'cancelado':       'Cancelado',
  };

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'pendiente_pago':  return AppColors.grayMid;
      case 'pago_confirmado': return Colors.blue;
      case 'en_camino':       return Colors.orange;
      case 'entregado':       return Colors.green;
      case 'en_disputa':      return Colors.red;
      case 'reembolsado':     return Colors.purple;
      default:                return AppColors.grayMid;
    }
  }

  IconData _estadoIcono(String estado) {
    switch (estado) {
      case 'pendiente_pago':  return Icons.hourglass_empty_rounded;
      case 'pago_confirmado': return Icons.payments_outlined;
      case 'en_camino':       return Icons.local_shipping_outlined;
      case 'entregado':       return Icons.check_circle_outline_rounded;
      case 'en_disputa':      return Icons.warning_amber_rounded;
      case 'reembolsado':     return Icons.undo_rounded;
      default:                return Icons.circle_outlined;
    }
  }

  String _deliveryLabel(String? method) {
    switch (method) {
      case 'yo':          return 'Lo entrego yo';
      case 'okventa':     return 'OkVenta Delivery';
      case 'blueexpress': return 'Blue Express';
      default:            return 'Sin definir';
    }
  }

  String _formatFecha(String? f) {
    if (f == null) return '';
    try {
      final dt = DateTime.parse(f).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                    bottom: BorderSide(color: AppColors.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: AppColors.carbon),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mis ventas',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        Text('Historial de lo que has vendido',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.grayMid)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _cargar,
                    child: const Icon(Icons.refresh_rounded,
                        color: AppColors.grayMid, size: 22),
                  ),
                ],
              ),
            ),

            // ── Lista ─────────────────────────────────────────────────────
            Expanded(
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary))
                  : _ventas.isEmpty
                      ? _buildVacio()
                      : RefreshIndicator(
                          onRefresh: _cargar,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _ventas.length,
                            itemBuilder: (_, i) => _TarjetaVenta(
                              venta: _ventas[i],
                              estadoColor:  _estadoColor,
                              estadoIcono:  _estadoIcono,
                              estadoLabel:  _estadoLabel,
                              deliveryLabel: _deliveryLabel,
                              formatFecha:  _formatFecha,
                              userId:       _userId,
                              onEntregaElegida: _cargar,
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacio() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storefront_outlined,
                  size: 64, color: AppColors.grayMid.withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text('Sin ventas aún',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Cuando alguien compre uno de tus\nproductos aparecerá aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.grayMid),
              ),
            ],
          ),
        ),
      );
}

// ── Tarjeta individual ─────────────────────────────────────────────────────────

class _TarjetaVenta extends StatefulWidget {
  final Map<String, dynamic> venta;
  final Color Function(String) estadoColor;
  final IconData Function(String) estadoIcono;
  final Map<String, String> estadoLabel;
  final String Function(String?) deliveryLabel;
  final String Function(String?) formatFecha;
  final int? userId;
  final VoidCallback onEntregaElegida;

  const _TarjetaVenta({
    required this.venta,
    required this.estadoColor,
    required this.estadoIcono,
    required this.estadoLabel,
    required this.deliveryLabel,
    required this.formatFecha,
    required this.userId,
    required this.onEntregaElegida,
  });

  @override
  State<_TarjetaVenta> createState() => _TarjetaVentaState();
}

class _TarjetaVentaState extends State<_TarjetaVenta> {
  bool _abriendo = false;

  Future<void> _irAPublicacion() async {
    final pubId = widget.venta['publicacion_id'];
    if (pubId == null) return;
    if (_abriendo) return;
    setState(() => _abriendo = true);
    try {
      final producto = await ApiService.obtenerPublicacion(pubId as int);
      if (!mounted) return;
      if (producto != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductoDetalleScreen(producto: producto),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venta = widget.venta;
    final estado    = venta['estado'] as String? ?? '';
    final titulo    = venta['titulo'] as String? ?? '';
    final monto     = venta['monto'];
    final delivery  = venta['delivery_method'] as String?;
    final comprador = venta['nombre_comprador'] as String? ?? 'Comprador';
    final fecha     = widget.formatFecha(venta['created_at'] as String?);
    final color     = widget.estadoColor(estado);
    final fotoUrl   = venta['foto_producto'] as String?;
    final necesitaEntrega =
        estado == 'pago_confirmado' && (delivery == null || delivery.isEmpty);

    final fotoWidget = fotoUrl != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              fotoUrl.startsWith('http')
                  ? fotoUrl
                  : '${ApiService.baseUrl}$fotoUrl',
              width: 62,
              height: 62,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _iconoFallback(),
            ),
          )
        : _iconoFallback();

    return GestureDetector(
      onTap: venta['publicacion_id'] != null ? _irAPublicacion : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: necesitaEntrega
                ? AppColors.primary.withOpacity(0.5)
                : AppColors.divider,
            width: necesitaEntrega ? 1.5 : 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Fila superior: foto + titulo + estado ────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      fotoWidget,
                      if (_abriendo)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              color: Colors.black26,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(titulo,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(widget.estadoIcono(estado),
                                      size: 11, color: color),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.estadoLabel[estado] ?? estado,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: color),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // ── Info ─────────────────────────────────────
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded,
                                size: 13, color: AppColors.grayMid),
                            const SizedBox(width: 4),
                            Text(comprador,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.grayMid)),
                            const SizedBox(width: 10),
                            const Icon(Icons.calendar_today_outlined,
                                size: 12, color: AppColors.grayMid),
                            const SizedBox(width: 4),
                            Text(fecha,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.grayMid)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatPrecio(monto),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Entrega ──────────────────────────────────────────────
              if (estado != 'pendiente_pago') ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: necesitaEntrega
                        ? AppColors.primary.withOpacity(0.05)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: necesitaEntrega
                        ? Border.all(
                            color: AppColors.primary.withOpacity(0.3))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        necesitaEntrega
                            ? Icons.local_shipping_outlined
                            : Icons.check_circle_outline_rounded,
                        size: 14,
                        color: necesitaEntrega
                            ? AppColors.primary
                            : AppColors.grayMid,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          necesitaEntrega
                              ? 'Debes elegir cómo entregar este producto'
                              : 'Entrega: ${widget.deliveryLabel(delivery)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: necesitaEntrega
                                ? AppColors.primary
                                : AppColors.grayMid,
                            fontWeight: necesitaEntrega
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (necesitaEntrega)
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SeleccionarEntregaScreen(
                                  ordenId: venta['id'] as int,
                                  titulo:  titulo,
                                  monto:   monto,
                                  compradorUbicacion:
                                      venta['comprador_ubicacion']
                                          as String? ?? '',
                                ),
                              ),
                            );
                            widget.onEntregaElegida();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Elegir',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconoFallback() => Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_outlined,
            size: 28, color: AppColors.grayMid),
      );
}
