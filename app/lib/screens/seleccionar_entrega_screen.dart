import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/blue_express_sheet.dart';
import 'entrega_vendedor_screen.dart';

class SeleccionarEntregaScreen extends StatefulWidget {
  final int ordenId;
  final String titulo;
  final dynamic monto;
  final String compradorUbicacion;

  const SeleccionarEntregaScreen({
    super.key,
    required this.ordenId,
    required this.titulo,
    required this.monto,
    required this.compradorUbicacion,
  });

  @override
  State<SeleccionarEntregaScreen> createState() =>
      _SeleccionarEntregaScreenState();
}

class _SeleccionarEntregaScreenState extends State<SeleccionarEntregaScreen> {
  String _metodo = 'yo';
  int? _deliveryId;
  Map<String, dynamic>? _blueExpressPunto;
  List<Map<String, dynamic>> _workers = [];
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargarWorkers();
  }

  Future<void> _cargarWorkers() async {
    try {
      final w = await ApiService.obtenerDelivery(soloActivos: true);
      if (mounted) setState(() => _workers = w);
    } catch (_) {}
  }

  Future<void> _confirmar() async {
    setState(() => _enviando = true);
    try {
      await ApiService.elegirEntrega(
        ordenId: widget.ordenId,
        method: _metodo,
        deliveryId: _deliveryId,
        blueExpressPunto: _blueExpressPunto?['nombre'] as String?,
      );
      if (!mounted) return;
      if (_metodo == 'yo') {
        // Ir directo a la pantalla de entrega: ahí se pide el permiso de
        // ubicación y se empieza a compartir la posición con el comprador.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EntregaVendedorScreen(
              ordenId: widget.ordenId,
              titulo: widget.titulo,
            ),
          ),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _enviando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al confirmar. Intenta de nuevo.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────
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
                        Text('Elegir entrega',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        Text('¿Cómo entregarás este producto?',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.grayMid)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Resumen de venta ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.titulo,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.sell_outlined,
                                size: 13, color: AppColors.grayMid),
                            const SizedBox(width: 4),
                            Text(
                              formatPrecio(widget.monto),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            ),
                          ],
                        ),
                        if (widget.compradorUbicacion.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 14, color: Colors.blue),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Comprador en: ${widget.compradorUbicacion}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Método de entrega',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),

                  // ── Opción: Yo entrego ────────────────────────────
                  _opcion(
                    activo: _metodo == 'yo',
                    icon: Icons.person_outline_rounded,
                    color: AppColors.primary,
                    titulo: 'Lo entrego yo',
                    subtitulo: 'Me encargo personalmente del despacho',
                    onTap: () => setState(() {
                      _metodo = 'yo';
                      _deliveryId = null;
                      _blueExpressPunto = null;
                    }),
                  ),

                  const SizedBox(height: 10),

                  // ── Opción: OkVenta Delivery ──────────────────────
                  _opcion(
                    activo: _metodo == 'okventa',
                    icon: Icons.delivery_dining_rounded,
                    color: Colors.green,
                    titulo: _metodo == 'okventa' && _deliveryId != null
                        ? (_workers
                                    .where((w) => w['id'] == _deliveryId)
                                    .firstOrNull?['nombre'] as String? ??
                                'OkVenta Delivery')
                        : 'OkVenta Delivery',
                    subtitulo: _metodo == 'okventa' && _deliveryId != null
                        ? 'Delivery seleccionado'
                        : 'Usar la red de repartidores OkVenta',
                    trailing: const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.grayMid),
                    onTap: () async {
                      setState(() => _metodo = 'okventa');
                      if (_workers.isNotEmpty) {
                        final elegido =
                            await showModalBottomSheet<Map<String, dynamic>>(
                          context: context,
                          backgroundColor: AppColors.surface,
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20))),
                          builder: (_) =>
                              _WorkerPickerSheet(workers: _workers),
                        );
                        if (elegido != null && mounted) {
                          setState(() => _deliveryId = elegido['id'] as int?);
                        }
                      }
                    },
                  ),

                  const SizedBox(height: 10),

                  // ── Opción: Blue Express ──────────────────────────
                  _opcion(
                    activo: _metodo == 'blueexpress',
                    icon: Icons.local_shipping_rounded,
                    color: const Color(0xFF0057B8),
                    titulo: _metodo == 'blueexpress' &&
                            _blueExpressPunto != null
                        ? _blueExpressPunto!['nombre'] as String? ??
                            'Blue Express'
                        : 'Blue Express',
                    subtitulo:
                        _metodo == 'blueexpress' && _blueExpressPunto != null
                            ? _blueExpressPunto!['direccion'] as String? ?? ''
                            : 'Despacho a todo Chile',
                    trailing: const Icon(Icons.chevron_right_rounded,
                        size: 16, color: AppColors.grayMid),
                    onTap: () async {
                      setState(() => _metodo = 'blueexpress');
                      final punto =
                          await showModalBottomSheet<Map<String, dynamic>>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const BlueExpressSheet(),
                      );
                      if (punto != null && mounted) {
                        setState(() => _blueExpressPunto = punto);
                      }
                    },
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _enviando ? null : _confirmar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      child: _enviando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Confirmar entrega'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _opcion({
    required bool activo,
    required IconData icon,
    required Color color,
    required String titulo,
    required String subtitulo,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: activo ? color.withOpacity(0.07) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activo ? color.withOpacity(0.5) : AppColors.divider,
            width: activo ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: activo ? color : AppColors.grayMid, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              activo ? color : AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grayMid)),
                ],
              ),
            ),
            if (activo && trailing == null)
              Icon(Icons.check_circle_rounded, color: color, size: 20)
            else if (trailing != null)
              trailing,
          ],
        ),
      ),
    );
  }
}

// ── Worker picker sheet ───────────────────────────────────────────────────────

class _WorkerPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> workers;
  const _WorkerPickerSheet({required this.workers});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Seleccionar Delivery OkVenta',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: workers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = workers[i];
              final nombre = d['nombre'] as String? ?? 'Delivery';
              final vehiculo = d['tipo_vehiculo'] as String? ?? 'bicicleta';
              final radio =
                  (d['radio_km'] as num?)?.toStringAsFixed(0) ?? '5';
              final fotoUrl = d['foto_perfil'] as String? ?? '';
              final iconos = {
                'bicicleta': Icons.directions_bike_rounded,
                'moto': Icons.two_wheeler_rounded,
                'auto': Icons.directions_car_rounded,
              };

              return GestureDetector(
                onTap: () => Navigator.pop(context, d),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        backgroundImage: fotoUrl.isNotEmpty
                            ? NetworkImage(
                                '${ApiService.baseUrl}$fotoUrl')
                            : null,
                        child: fotoUrl.isEmpty
                            ? Text(nombre[0].toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            Row(
                              children: [
                                Icon(
                                    iconos[vehiculo] ??
                                        Icons.delivery_dining_outlined,
                                    size: 13,
                                    color: AppColors.grayMid),
                                const SizedBox(width: 4),
                                Text('$vehiculo  •  radio $radio km',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.grayMid)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.grayMid, size: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
