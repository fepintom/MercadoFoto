import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Pantalla del vendedor cuando eligió "Lo entrego yo".
///
/// Pide permiso de ubicación y transmite su posición al backend cada
/// pocos segundos mientras esté abierta, para que el comprador pueda
/// verlo acercarse en el mapa en tiempo real (estilo Uber).
class EntregaVendedorScreen extends StatefulWidget {
  final int ordenId;
  final String titulo;

  const EntregaVendedorScreen({
    super.key,
    required this.ordenId,
    required this.titulo,
  });

  @override
  State<EntregaVendedorScreen> createState() => _EntregaVendedorScreenState();
}

class _EntregaVendedorScreenState extends State<EntregaVendedorScreen> {
  Timer? _locTimer;
  Timer? _pollTimer;
  ll.LatLng? _miPos;
  ll.LatLng? _destino;
  String _destinoDireccion = '';
  String _estadoOrden = '';
  bool _permisoDenegado = false;
  bool _compartiendo = false;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _cargarTracking();
    _iniciarUbicacion();
    _locTimer = Timer.periodic(
        const Duration(seconds: 10), (_) => _enviarUbicacion());
    _pollTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _cargarTracking());
  }

  @override
  void dispose() {
    _locTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarTracking() async {
    try {
      final t = await ApiService.obtenerTrackingVendedor(widget.ordenId);
      if (t == null || !mounted) return;
      setState(() {
        _estadoOrden = t['estado'] as String? ?? '';
        _destinoDireccion = t['destino_direccion'] as String? ?? '';
        final dLat = (t['destino_lat'] as num?)?.toDouble();
        final dLng = (t['destino_lng'] as num?)?.toDouble();
        if (dLat != null && dLng != null) {
          _destino = ll.LatLng(dLat, dLng);
        }
      });
    } catch (_) {}
  }

  Future<void> _iniciarUbicacion() async {
    final ok = await _pedirPermiso();
    if (!ok) return;
    await _enviarUbicacion();
    // Centrar el mapa en mi posición la primera vez
    if (_miPos != null && mounted) {
      _mapController.move(_miPos!, 15);
    }
  }

  Future<bool> _pedirPermiso() async {
    try {
      final servicio = await Geolocator.isLocationServiceEnabled();
      if (!servicio) {
        if (mounted) setState(() => _permisoDenegado = true);
        return false;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _permisoDenegado = true);
        return false;
      }
      if (mounted) setState(() => _permisoDenegado = false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _enviarUbicacion() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      if (mounted) {
        setState(() {
          _miPos = ll.LatLng(pos.latitude, pos.longitude);
          _compartiendo = true;
        });
      }
      await ApiService.enviarTrackingVendedor(
          widget.ordenId, pos.latitude, pos.longitude);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final entregado = _estadoOrden == 'entregado';
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
                        const Text('Entrega en curso',
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

            // ── Estado de compartir ubicación ────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: entregado
                    ? Colors.green.withOpacity(0.08)
                    : _permisoDenegado
                        ? Colors.orange.withOpacity(0.08)
                        : AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: entregado
                      ? Colors.green.withOpacity(0.4)
                      : _permisoDenegado
                          ? Colors.orange.withOpacity(0.4)
                          : AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    entregado
                        ? Icons.check_circle_rounded
                        : _permisoDenegado
                            ? Icons.location_off_rounded
                            : _compartiendo
                                ? Icons.my_location_rounded
                                : Icons.location_searching_rounded,
                    size: 18,
                    color: entregado
                        ? Colors.green
                        : _permisoDenegado
                            ? Colors.orange
                            : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entregado
                          ? 'Entrega confirmada por el comprador'
                          : _permisoDenegado
                              ? 'Activa la ubicación para que el comprador te vea llegar'
                              : _compartiendo
                                  ? 'Compartiendo tu ubicación con el comprador'
                                  : 'Obteniendo tu ubicación…',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: entregado
                            ? Colors.green
                            : _permisoDenegado
                                ? Colors.orange.shade800
                                : AppColors.primary,
                      ),
                    ),
                  ),
                  if (_permisoDenegado)
                    TextButton(
                      onPressed: () async {
                        await Geolocator.openAppSettings();
                      },
                      child: const Text('Activar',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),

            if (_destinoDireccion.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider, width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Entregar en: $_destinoDireccion',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),

            // ── Mapa ─────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: _miPos ??
                          _destino ??
                          ll.LatLng(-33.45, -70.66), // Santiago fallback
                      zoom: 14,
                      interactiveFlags:
                          InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      MarkerLayer(markers: [
                        if (_destino != null)
                          Marker(
                            point: _destino!,
                            width: 40,
                            height: 40,
                            builder: (_) => const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.primary,
                                size: 36),
                          ),
                        if (_miPos != null)
                          Marker(
                            point: _miPos!,
                            width: 36,
                            height: 36,
                            builder: (_) => Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 6)
                                ],
                              ),
                              child: const Icon(Icons.navigation_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),

            // ── Nota inferior ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                entregado
                    ? 'La entrega fue confirmada. Ya puedes cerrar esta pantalla.'
                    : 'Mantén esta pantalla abierta mientras vas en camino para que el comprador vea tu ubicación.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.grayMid),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
