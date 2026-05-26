import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
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
        return AppColors.primary;
      case 'entregado':
        return Colors.green;
      case 'en_disputa':
        return Colors.red;
      case 'reembolsado':
        return AppColors.grayMid;
      case 'cancelado':
        return AppColors.grayMid;
      default:
        return AppColors.grayMid;
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
      backgroundColor: AppColors.surface,
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
            const Text(
              '¿Confirmar que recibiste el producto/servicio?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Al confirmar, el vendedor recibirá el pago. Esta acción no se puede deshacer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grayMid, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(color: AppColors.textSecondary)),
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
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.primary),
      );
    }
  }

  // ── Abrir disputa ──────────────────────────────────────────────────────────

  Future<void> _abrirDisputa(int ordenId) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
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
            const Text(
              '¿Tuviste un problema?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Abriremos una disputa. Nuestro equipo revisará el caso y se pondrá en contacto contigo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grayMid, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar',
                        style: TextStyle(color: AppColors.textSecondary)),
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
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.primary),
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

    final puedeConfirmar = esCompra &&
        (estado == 'pago_confirmado' || estado == 'en_camino');
    final puedeDisputar = esCompra &&
        (estado == 'pago_confirmado' || estado == 'en_camino');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
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
                        ? AppColors.carbon.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tipo == 'producto' ? 'Producto' : 'Servicio',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tipo == 'producto'
                            ? AppColors.carbon
                            : AppColors.primary),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatFecha(fecha),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.grayMid),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Título
            Text(
              titulo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),

            const SizedBox(height: 4),

            // Contraparte
            Row(
              children: [
                Icon(
                  esCompra ? Icons.store_outlined : Icons.person_outline,
                  size: 13,
                  color: AppColors.grayMid,
                ),
                const SizedBox(width: 4),
                Text(
                  contraparte,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.grayMid),
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
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
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
                        onPressed: () => _abrirDisputa(id),
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
                size: 56, color: AppColors.grayMid.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.grayMid,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mis órdenes',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.carbon),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tab,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.grayMid,
            indicatorColor: AppColors.primary,
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
                      color: AppColors.primary,
                      child: _compras.isEmpty
                          ? _listaVacia('Aún no has realizado compras')
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _compras.length,
                              itemBuilder: (_, i) =>
                                  _tarjetaOrden(_compras[i], esCompra: true),
                            ),
                    ),

                    // Ventas
                    RefreshIndicator(
                      onRefresh: _cargar,
                      color: AppColors.primary,
                      child: _ventas.isEmpty
                          ? _listaVacia('Aún no tienes ventas')
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _ventas.length,
                              itemBuilder: (_, i) =>
                                  _tarjetaOrden(_ventas[i], esCompra: false),
                            ),
                    ),
                  ],
                ),
    );
  }
}
