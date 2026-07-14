import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Mapa en tiempo real para el comprador: muestra dónde viene el vendedor
/// cuando eligió "Lo entrego yo" (estilo Uber, con polling cada 5s).
class SeguimientoEntregaScreen extends StatefulWidget {
  final int ordenId;
  final String titulo;

  const SeguimientoEntregaScreen({
    super.key,
    required this.ordenId,
    required this.titulo,
  });

  @override
  State<SeguimientoEntregaScreen> createState() =>
      _SeguimientoEntregaScreenState();
}

class _SeguimientoEntregaScreenState extends State<SeguimientoEntregaScreen> {
  Timer? _pollTimer;
  ll.LatLng? _vendedorPos;
  ll.LatLng? _destino;
  String _estadoOrden = '';
  String _actualizadoAt = '';
  bool _cargando = true;
  bool _centradoInicial = false;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _cargar();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _cargar());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final t = await ApiService.obtenerTrackingVendedor(widget.ordenId);
      if (t == null || !mounted) return;
      final vLat = (t['vendedor_lat'] as num?)?.toDouble();
      final vLng = (t['vendedor_lng'] as num?)?.toDouble();
      final dLat = (t['destino_lat'] as num?)?.toDouble();
      final dLng = (t['destino_lng'] as num?)?.toDouble();
      setState(() {
        _estadoOrden = t['estado'] as String? ?? '';
        _actualizadoAt = t['actualizado_at'] as String? ?? '';
        if (vLat != null && vLng != null) {
          _vendedorPos = ll.LatLng(vLat, vLng);
        }
        if (dLat != null && dLng != null) {
          _destino = ll.LatLng(dLat, dLng);
        }
        _cargando = false;
      });
      // Centrar en el vendedor la primera vez que aparece
      if (!_centradoInicial && _vendedorPos != null) {
        _centradoInicial = true;
        _mapController.move(_vendedorPos!, 14);
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _haceCuanto() {
    if (_actualizadoAt.isEmpty) return '';
    try {
      final dt = DateTime.parse('${_actualizadoAt}Z').toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'hace ${diff.inSeconds}s';
      if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
      return 'hace ${diff.inHours}h';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final entregado = _estadoOrden == 'entregado';
    final sinSenal = _vendedorPos == null;
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tu pedido viene en camino',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        Text(widget.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.grayMid)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Banner de estado ─────────────────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: entregado
                    ? Colors.green.withOpacity(0.08)
                    : sinSenal
                        ? Colors.orange.withOpacity(0.08)
                        : AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: entregado
                      ? Colors.green.withOpacity(0.4)
                      : sinSenal
                          ? Colors.orange.withOpacity(0.4)
                          : AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    entregado
                        ? Icons.check_circle_rounded
                        : sinSenal
                            ? Icons.location_searching_rounded
                            : Icons.local_shipping_rounded,
                    size: 18,
                    color: entregado
                        ? Colors.green
                        : sinSenal
                            ? Colors.orange
                            : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entregado
                          ? 'Pedido entregado'
                          : sinSenal
                              ? 'Esperando la ubicación del vendedor…'
                              : 'El vendedor viene en camino'
                                  '${_haceCuanto().isNotEmpty ? '  •  actualizado ${_haceCuanto()}' : ''}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: entregado
                            ? Colors.green
                            : sinSenal
                                ? Colors.orange.shade800
                                : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Mapa ─────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _cargando
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            center: _vendedorPos ??
                                _destino ??
                                ll.LatLng(-33.45, -70.66),
                            zoom: 14,
                            interactiveFlags: InteractiveFlag.pinchZoom |
                                InteractiveFlag.drag,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            ),
                            MarkerLayer(markers: [
                              // Mi casa (destino)
                              if (_destino != null)
                                Marker(
                                  point: _destino!,
                                  width: 40,
                                  height: 40,
                                  builder: (_) => const Icon(
                                      Icons.home_rounded,
                                      color: AppColors.primary,
                                      size: 34),
                                ),
                              // El vendedor en movimiento
                              if (_vendedorPos != null)
                                Marker(
                                  point: _vendedorPos!,
                                  width: 40,
                                  height: 40,
                                  builder: (_) => Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black
                                                .withOpacity(0.25),
                                            blurRadius: 6)
                                      ],
                                    ),
                                    child: const Icon(
                                        Icons.directions_car_rounded,
                                        color: Colors.white,
                                        size: 20),
                                  ),
                                ),
                            ]),
                          ],
                        ),
                      ),
              ),
            ),

            // ── Leyenda ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.directions_car_rounded,
                      size: 15, color: Colors.green),
                  SizedBox(width: 4),
                  Text('Vendedor',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.grayMid)),
                  SizedBox(width: 16),
                  Icon(Icons.home_rounded, size: 15, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('Tu dirección',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.grayMid)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
