import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Pantalla del repartidor durante una entrega OkDelivery activa.
/// El contenido cambia según `entrega['estado']`:
///   asignado / en_camino_retiro -> mapa + "Llegué a retirar"
///   llegado_retiro              -> esperando que el vendedor entregue
///   esperando_confirmacion_calidad -> foto + estado del producto
///   observaciones_reportadas   -> esperando que el vendedor repare/cancele
///   reparacion_reportada       -> "Confirmar reparación"
///   en_camino_entrega           -> mapa + "Llegué a entregar"
///   llegado_entrega             -> foto de entrega
///   entregado_pendiente_confirmacion / cerrado_* -> resumen final
class OkdeliveryActivoScreen extends StatefulWidget {
  final int ordenId;
  final int deliveryId;

  const OkdeliveryActivoScreen({
    super.key,
    required this.ordenId,
    required this.deliveryId,
  });

  @override
  State<OkdeliveryActivoScreen> createState() =>
      _OkdeliveryActivoScreenState();
}

class _OkdeliveryActivoScreenState extends State<OkdeliveryActivoScreen> {
  Map<String, dynamic>? _entrega;
  bool _cargando = true;
  bool _enviando = false;
  Timer? _pollTimer;
  Timer? _locTimer;
  final _picker = ImagePicker();
  ll.LatLng? _miPos;

  // Estado local del formulario "confirmar recepción" (retiro)
  File? _fotoRetiro;
  String _estadoProductoRetiro = 'ok';
  final _observacionesCtrl = TextEditingController();

  static const _estadosCerrados = {
    'cerrado_ok',
    'cerrado_con_reclamo',
    'cancelado_sin_reparar',
  };

  @override
  void initState() {
    super.initState();
    _cargarEntrega();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _cargarEntrega(silencioso: true));
    _locTimer = Timer.periodic(
        const Duration(seconds: 12), (_) => _enviarUbicacion());
    _enviarUbicacion();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _locTimer?.cancel();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEntrega({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final data = await ApiService.obtenerEntregaOkdelivery(widget.ordenId);
      if (mounted) setState(() { _entrega = data; _cargando = false; });
    } catch (_) {
      if (mounted && !silencioso) setState(() => _cargando = false);
    }
  }

  Future<void> _enviarUbicacion() async {
    final estado = _entrega?['estado'] as String?;
    if (estado != null &&
        (_estadosCerrados.contains(estado) ||
            estado == 'entregado_pendiente_confirmacion')) {
      return;
    }
    try {
      final servicio = await Geolocator.isLocationServiceEnabled();
      if (!servicio) return;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      if (mounted) {
        setState(() => _miPos = ll.LatLng(pos.latitude, pos.longitude));
      }
      await ApiService.actualizarUbicacionOkdelivery(
          widget.ordenId, pos.latitude, pos.longitude);
    } catch (_) {}
  }

  void _mostrarError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.primary),
    );
  }

  Future<void> _accion(Future<void> Function() fn) async {
    if (_enviando) return;
    setState(() => _enviando = true);
    try {
      await fn();
      await _cargarEntrega();
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<File?> _tomarFoto() async {
    final xfile =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 82);
    if (xfile == null) return null;
    return File(xfile.path);
  }

  // ── Acciones por estado ────────────────────────────────────────────────

  Future<void> _llegueRetiro() =>
      _accion(() => ApiService.llegueRetiroOkdelivery(widget.ordenId));

  Future<void> _elegirFotoRetiro() async {
    final f = await _tomarFoto();
    if (f != null && mounted) setState(() => _fotoRetiro = f);
  }

  Future<void> _confirmarRecepcion() async {
    if (_fotoRetiro == null) {
      _mostrarError('Primero toma una foto del producto');
      return;
    }
    if (_estadoProductoRetiro == 'con_observaciones' &&
        _observacionesCtrl.text.trim().isEmpty) {
      _mostrarError('Describe la observación');
      return;
    }
    await _accion(() => ApiService.confirmarRecepcionRepartidor(
          ordenId: widget.ordenId,
          estadoProducto: _estadoProductoRetiro,
          observaciones: _estadoProductoRetiro == 'con_observaciones'
              ? _observacionesCtrl.text.trim()
              : null,
          foto: _fotoRetiro!,
        ));
    if (mounted) {
      setState(() {
        _fotoRetiro = null;
        _estadoProductoRetiro = 'ok';
        _observacionesCtrl.clear();
      });
    }
  }

  Future<void> _confirmarReparacion() =>
      _accion(() => ApiService.confirmarReparacionOkdelivery(widget.ordenId));

  Future<void> _llegueEntrega() =>
      _accion(() => ApiService.llegueEntregaOkdelivery(widget.ordenId));

  Future<void> _confirmarEntregaConFoto() async {
    final f = await _tomarFoto();
    if (f == null) return;
    await _accion(() => ApiService.confirmarEntregaRepartidor(widget.ordenId, f));
  }

  // ── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: _cargando
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : _entrega == null
                      ? const Center(child: Text('Entrega no encontrada'))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _cuerpoPorEstado(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final titulo = _entrega?['titulo'] as String? ?? 'Entrega OkDelivery';
    final monto = (_entrega?['monto'] as num?)?.toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border:
            Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.delivery_dining_rounded,
              color: Colors.green, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                if (monto != null)
                  Text('\$${monto.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grayMid)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cuerpoPorEstado() {
    final estado = _entrega!['estado'] as String? ?? '';

    switch (estado) {
      case 'asignado':
      case 'en_camino_retiro':
        return _pasoConMapa(
          titulo: 'Ve a retirar el producto',
          subtitulo: 'Tu ubicación se comparte con el vendedor en tiempo real.',
          destinoLat: (_entrega!['pickup_lat'] as num?)?.toDouble(),
          destinoLng: (_entrega!['pickup_lng'] as num?)?.toDouble(),
          botonLabel: 'Llegué a retirar',
          onBoton: _llegueRetiro,
        );

      case 'llegado_retiro':
        return _esperando(
          icon: Icons.hourglass_top_rounded,
          titulo: 'Esperando al vendedor',
          subtitulo:
              'Avisamos al vendedor que llegaste. Espera a que te entregue el producto en la app.',
        );

      case 'esperando_confirmacion_calidad':
        return _formularioRecepcion();

      case 'observaciones_reportadas':
        return _esperando(
          icon: Icons.build_circle_outlined,
          titulo: 'Esperando al vendedor',
          subtitulo:
              'Reportaste una observación. El vendedor debe repararlo o se cancelará la venta.',
        );

      case 'reparacion_reportada':
        return _accionSimple(
          icon: Icons.handyman_rounded,
          titulo: 'El vendedor dice que reparó el producto',
          subtitulo: 'Verifícalo en persona antes de confirmar.',
          botonLabel: 'Confirmar reparación',
          onBoton: _confirmarReparacion,
        );

      case 'cancelado_sin_reparar':
        return _esperando(
          icon: Icons.cancel_rounded,
          titulo: 'Venta cancelada',
          subtitulo:
              'El vendedor no pudo reparar el producto. Puedes devolverlo. Esta entrega quedó cerrada.',
          color: Colors.red,
        );

      case 'en_camino_entrega':
        return _pasoConMapa(
          titulo: 'Ve a entregar el producto',
          subtitulo: 'El comprador puede ver tu ubicación en tiempo real.',
          destinoLat: (_entrega!['destino_lat'] as num?)?.toDouble(),
          destinoLng: (_entrega!['destino_lng'] as num?)?.toDouble(),
          botonLabel: 'Llegué a entregar',
          onBoton: _llegueEntrega,
        );

      case 'llegado_entrega':
        return _accionSimple(
          icon: Icons.camera_alt_rounded,
          titulo: 'Confirma la entrega',
          subtitulo: 'Toma una foto del producto entregado al comprador.',
          botonLabel: 'Tomar foto y confirmar',
          onBoton: _confirmarEntregaConFoto,
        );

      case 'entregado_pendiente_confirmacion':
        return _esperando(
          icon: Icons.check_circle_outline_rounded,
          titulo: 'Entrega completada',
          subtitulo:
              'El comprador tiene 1 hora para confirmar recepción. Tu trabajo aquí terminó.',
          color: Colors.green,
        );

      case 'cerrado_ok':
        return _esperando(
          icon: Icons.verified_rounded,
          titulo: 'Venta cerrada correctamente',
          subtitulo: '¡Buen trabajo! El comprador confirmó recepción.',
          color: Colors.green,
        );

      case 'cerrado_con_reclamo':
        return _esperando(
          icon: Icons.report_rounded,
          titulo: 'El comprador reportó un problema',
          subtitulo: 'OkVenta está revisando el caso.',
          color: Colors.orange,
        );

      default:
        return Text('Estado: $estado');
    }
  }

  Widget _pasoConMapa({
    required String titulo,
    required String subtitulo,
    double? destinoLat,
    double? destinoLng,
    required String botonLabel,
    required Future<void> Function() onBoton,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitulo,
            style: const TextStyle(fontSize: 13, color: AppColors.grayMid)),
        const SizedBox(height: 14),
        if (destinoLat != null && destinoLng != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 240,
              child: FlutterMap(
                options: MapOptions(
                  center: _miPos ?? ll.LatLng(destinoLat, destinoLng),
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
                    Marker(
                      point: ll.LatLng(destinoLat, destinoLng),
                      width: 40,
                      height: 40,
                      builder: (_) => const Icon(Icons.location_on_rounded,
                          color: AppColors.primary, size: 36),
                    ),
                    if (_miPos != null)
                      Marker(
                        point: _miPos!,
                        width: 36,
                        height: 36,
                        builder: (_) => const Icon(Icons.two_wheeler_rounded,
                            color: Colors.green, size: 30),
                      ),
                  ]),
                ],
              ),
            ),
          )
        else
          Container(
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Text('Sin ubicación de referencia',
                style: TextStyle(color: AppColors.grayMid, fontSize: 12)),
          ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _enviando ? null : () => onBoton(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _enviando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(botonLabel,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _accionSimple({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required String botonLabel,
    required Future<void> Function() onBoton,
  }) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Icon(icon, size: 56, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(subtitulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.grayMid)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _enviando ? null : () => onBoton(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _enviando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(botonLabel,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _esperando({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    Color color = AppColors.primary,
  }) {
    return Column(
      children: [
        const SizedBox(height: 30),
        Icon(icon, size: 64, color: color),
        const SizedBox(height: 18),
        Text(titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 8),
        Text(subtitulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppColors.grayMid, height: 1.4)),
        if (color != AppColors.primary) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Volver a entregas disponibles'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _formularioRecepcion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Confirma que recibiste el producto',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('Saca una foto y marca el estado del producto.',
            style: TextStyle(fontSize: 13, color: AppColors.grayMid)),
        const SizedBox(height: 16),

        GestureDetector(
          onTap: _elegirFotoRetiro,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: _fotoRetiro == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            size: 36, color: AppColors.grayMid),
                        SizedBox(height: 8),
                        Text('Tomar foto del producto',
                            style: TextStyle(color: AppColors.grayMid)),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(_fotoRetiro!, fit: BoxFit.cover),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _chipEstado(
                label: 'Producto OK',
                seleccionado: _estadoProductoRetiro == 'ok',
                color: Colors.green,
                onTap: () => setState(() => _estadoProductoRetiro = 'ok'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _chipEstado(
                label: 'Con observaciones',
                seleccionado: _estadoProductoRetiro == 'con_observaciones',
                color: Colors.orange,
                onTap: () => setState(
                    () => _estadoProductoRetiro = 'con_observaciones'),
              ),
            ),
          ],
        ),

        if (_estadoProductoRetiro == 'con_observaciones') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _observacionesCtrl,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe el problema encontrado…',
            ),
          ),
        ],

        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _enviando ? null : _confirmarRecepcion,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _enviando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Confirmar',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _chipEstado({
    required String label,
    required bool seleccionado,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: seleccionado ? color.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: seleccionado ? color : AppColors.divider,
              width: seleccionado ? 1.5 : 0.8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: seleccionado ? color : AppColors.textSecondary)),
      ),
    );
  }
}
