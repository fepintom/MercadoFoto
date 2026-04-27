import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'producto_detalle_screen.dart';

class EncontrarScreen extends StatefulWidget {
  const EncontrarScreen({super.key});

  @override
  State<EncontrarScreen> createState() => _EncontrarScreenState();
}

class _EncontrarScreenState extends State<EncontrarScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _productosCercanos = [];
  bool _loading = true;
  bool _errorPermisos = false;
  double _radioKm = 5.0;
  double? _miLat;
  double? _miLng;

  Map<String, dynamic>? _seleccionado;
  late MapController _mapCtrl;

  // ── Animación pulso ───────────────────────────────────────────────────────
  late AnimationController _pulsoCtrl;
  late Animation<double>    _pulsoAnim;

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();

    // Pulso: oscila entre opacidad baja y alta, cada 1.4 s, ida y vuelta
    _pulsoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulsoAnim = CurvedAnimation(
      parent: _pulsoCtrl,
      curve: Curves.easeInOut,
    );

    _obtenerUbicacionYProductos();
  }

  @override
  void dispose() {
    _pulsoCtrl.dispose();
    super.dispose();
  }

  // ── GPS + carga de productos ───────────────────────────────────────────────
  Future<void> _obtenerUbicacionYProductos() async {
    setState(() {
      _loading = true;
      _errorPermisos = false;
      _seleccionado = null;
    });

    try {
      bool habilitado = await Geolocator.isLocationServiceEnabled();
      if (!habilitado) {
        if (!mounted) return;
        setState(() { _loading = false; _errorPermisos = true; });
        return;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.deniedForever ||
          permiso == LocationPermission.denied) {
        if (!mounted) return;
        setState(() { _loading = false; _errorPermisos = true; });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final lat = pos.latitude;
      final lng = pos.longitude;

      // Sincronizar con el backend si está autenticado
      final sesion = await SessionService.obtenerSesion();
      final userId = sesion["user_id"];
      if (userId != null) {
        await ApiService.actualizarUbicacion(userId: userId, lat: lat, lng: lng);
      }

      final productos = await ApiService.obtenerPublicacionesCercanas(
        lat: lat,
        lng: lng,
        radioKm: _radioKm,
      );

      if (!mounted) return;
      if (!mounted) return;
      setState(() {
        _miLat = lat;
        _miLng = lng;
        _productosCercanos = productos;
        _loading = false;
      });

      // Centrar mapa en posición del usuario
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _miLat != null && _miLng != null) {
          _mapCtrl.move(LatLng(_miLat!, _miLng!), 13.5);
        }
      });
    } catch (e) {
      debugPrint("ERROR ubicación: $e");
      if (!mounted) return;
      setState(() { _loading = false; _errorPermisos = true; });
    }
  }

  // ── Abrir en Apple Maps / Google Maps ─────────────────────────────────────
  Future<void> _abrirEnMapa(Map<String, dynamic> p) async {
    final lat = p['lat'] as double?;
    final lng = p['lng'] as double?;
    if (lat == null || lng == null) return;

    final rng = math.Random();
    final latAprox = lat + (rng.nextDouble() - 0.5) * 0.002;
    final lngAprox = lng + (rng.nextDouble() - 0.5) * 0.002;
    final titulo = Uri.encodeComponent(p['titulo'] ?? 'OkVenta');

    final apple = Uri.parse('maps://?q=$titulo&ll=$latAprox,$lngAprox');
    if (await canLaunchUrl(apple)) {
      await launchUrl(apple);
    } else {
      await launchUrl(
        Uri.parse('https://www.google.com/maps?q=$latAprox,$lngAprox'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  String _formatDistancia(dynamic d) {
    if (d == null) return '';
    final km = (d as num).toDouble();
    return km < 1.0
        ? "${(km * 1000).toStringAsFixed(0)} m"
        : "${km.toStringAsFixed(1)} km";
  }

  // ── Filtro radio (bottom sheet) ───────────────────────────────────────────
  void _mostrarFiltroRadio() {
    double radioTmp = _radioKm;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Radio de búsqueda",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text("${radioTmp.toStringAsFixed(0)} km",
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              Slider(
                value: radioTmp,
                min: 1,
                max: 50,
                divisions: 49,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.divider,
                onChanged: (v) => set(() => radioTmp = v),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _radioKm = radioTmp);
                    _obtenerUbicacionYProductos();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Buscar en este radio",
                      style: TextStyle(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Marker widget ─────────────────────────────────────────────────────────
  Widget _buildMarker(Map<String, dynamic> p) {
    final bool sel = _seleccionado?['id'] == p['id'];
    final imagenUrl = p['imagen_url'] ?? '';
    final precio = p['precio'];

    return GestureDetector(
      onTap: () {
        setState(() => _seleccionado = sel ? null : p);
        if (!sel) {
          final lat = (p['lat'] as num?)?.toDouble();
          final lng = (p['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            _mapCtrl.move(LatLng(lat, lng), _mapCtrl.zoom);
          }
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Foto en miniatura con borde de selección
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(sel ? 10 : 8),
              border: Border.all(
                color: sel ? AppColors.primary : Colors.white,
                width: sel ? 2.5 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: sel
                      ? AppColors.primary.withOpacity(0.35)
                      : Colors.black.withOpacity(0.25),
                  blurRadius: sel ? 10 : 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(sel ? 8 : 6),
              child: Image.network(
                "${ApiService.baseUrl}$imagenUrl",
                width: sel ? 68 : 56,
                height: sel ? 68 : 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: sel ? 68 : 56,
                  height: sel ? 68 : 56,
                  color: AppColors.background,
                  child: const Icon(Icons.image_outlined,
                      color: AppColors.grayMid, size: 22),
                ),
              ),
            ),
          ),

          // Badge precio
          if (precio != null)
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : AppColors.carbon,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1))
                ],
              ),
              child: Text(
                "\$${_formatPrecio(precio)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

          // Punta indicadora
          CustomPaint(
            size: const Size(12, 6),
            painter: _PuntaPainter(
                sel ? AppColors.primary : AppColors.carbon),
          ),
        ],
      ),
    );
  }

  String _formatPrecio(dynamic precio) {
    final n = (precio as num).toInt();
    if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(0)}k";
    return n.toString();
  }

  // ── Tarjeta inferior cuando hay producto seleccionado ─────────────────────
  Widget _buildTarjetaSeleccionada(Map<String, dynamic> p) {
    final titulo = p['titulo'] ?? '';
    final precio = p['precio'];
    final imagenUrl = p['imagen_url'] ?? '';
    final distancia = _formatDistancia(p['distancia_km']);
    final categoria = p['categoria'] ?? '';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Imagen
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => ProductoDetalleScreen(producto: p))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    "${ApiService.baseUrl}$imagenUrl",
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: AppColors.background,
                      child: const Icon(Icons.image_outlined,
                          color: AppColors.grayMid),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Categoría + distancia
                    Row(
                      children: [
                        if (categoria.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(categoria,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500)),
                          ),
                        const Spacer(),
                        if (distancia.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.place_outlined,
                                  size: 11, color: AppColors.grayMid),
                              const SizedBox(width: 2),
                              Text(distancia,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.grayMid)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (precio != null)
                          Text(
                            "\$${precio.toString()}",
                            style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700),
                          ),
                        const Spacer(),
                        // Ver en mapa externo
                        if (p['lat'] != null)
                          GestureDetector(
                            onTap: () => _abrirEnMapa(p),
                            child: const Row(
                              children: [
                                Icon(Icons.open_in_new_rounded,
                                    size: 13, color: AppColors.grayMid),
                                SizedBox(width: 3),
                                Text("Maps",
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.grayMid)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Botón ver detalle
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => ProductoDetalleScreen(producto: p))),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dot de ubicación del usuario ──────────────────────────────────────────
  Widget _buildUserDot() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: Colors.blue.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 2)
        ],
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Encontrar",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            if (!_loading && !_errorPermisos)
              Text(
                "Radio: ${_radioKm.toStringAsFixed(0)} km · ${_productosCercanos.length} productos",
                style: const TextStyle(fontSize: 11, color: AppColors.grayMid),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.textPrimary),
            onPressed: _mostrarFiltroRadio,
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: AppColors.primary),
            onPressed: _obtenerUbicacionYProductos,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.divider),
        ),
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text("Obteniendo tu ubicación…",
                      style: TextStyle(color: AppColors.grayMid)),
                ],
              ),
            )
          : _errorPermisos
              ? _pantallaPermisos()
              : _buildMapa(),
    );
  }

  Widget _buildMapa() {
    // Posición inicial: el usuario, o Santiago de Chile como fallback
    final center = (_miLat != null && _miLng != null)
        ? LatLng(_miLat!, _miLng!)
        : LatLng(-33.4489, -70.6693);

    // Construir la lista de marcadores
    final markers = <Marker>[];

    // Dot del usuario
    if (_miLat != null && _miLng != null) {
      markers.add(Marker(
        point: LatLng(_miLat!, _miLng!),
        width: 24,
        height: 24,
        builder: (_) => _buildUserDot(),
      ));
    }

    // Marcadores de productos
    for (final p in _productosCercanos) {
      final lat = (p['lat'] as num?)?.toDouble();
      final lng = (p['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final bool sel = _seleccionado?['id'] == p['id'];
      markers.add(Marker(
        point: LatLng(lat, lng),
        width: sel ? 90 : 76,
        height: sel ? 100 : 86,
        anchorPos: AnchorPos.align(AnchorAlign.top),
        builder: (_) => _buildMarker(p),
      ));
    }

    // Círculos de 2 km por producto
    final circulos = _productosCercanos
        .where((p) => p['lat'] != null && p['lng'] != null)
        .map((p) => CircleMarker(
              point: LatLng(
                (p['lat'] as num).toDouble(),
                (p['lng'] as num).toDouble(),
              ),
              radius: 2000,           // 2 km en metros
              useRadiusInMeter: true,
              color: const Color(0xFF34C759).withOpacity(0),   // relleno: animado
              borderStrokeWidth: 2.5,
              borderColor: const Color(0xFF34C759).withOpacity(0), // borde: animado
            ))
        .toList();

    return Stack(
      children: [
        // ── Mapa ─────────────────────────────────────────────────────
        AnimatedBuilder(
          animation: _pulsoAnim,
          builder: (_, __) {
            // Actualizar opacidades en cada tick
            final relleno = 0.06 + _pulsoAnim.value * 0.10;   // 0.06 → 0.16
            final borde   = 0.35 + _pulsoAnim.value * 0.45;   // 0.35 → 0.80
            final circulosAnimados = _productosCercanos
                .where((p) => p['lat'] != null && p['lng'] != null)
                .map((p) => CircleMarker(
                      point: LatLng(
                        (p['lat'] as num).toDouble(),
                        (p['lng'] as num).toDouble(),
                      ),
                      radius: 2000,
                      useRadiusInMeter: true,
                      color: const Color(0xFF34C759).withOpacity(relleno),
                      borderStrokeWidth: 2.0,
                      borderColor:
                          const Color(0xFF34C759).withOpacity(borde),
                    ))
                .toList();

            return FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                center: center,
                zoom: 13.5,
                maxZoom: 19,
                onTap: (_, __) => setState(() => _seleccionado = null),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.okventa.app',
                ),
                // Círculos pulsantes DEBAJO de los marcadores
                CircleLayer(circles: circulosAnimados),
                MarkerLayer(
                  markers: markers,
                  rotate: false,
                ),
              ],
            );
          },
        ),

        // ── Badge contador arriba ──────────────────────────────────────
        if (_productosCercanos.isNotEmpty)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      "${_productosCercanos.length} producto${_productosCercanos.length == 1 ? '' : 's'} a ${_radioKm.toStringAsFixed(0)} km",
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Sin productos en el radio ──────────────────────────────────
        if (_productosCercanos.isEmpty && !_loading)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 8)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded,
                        size: 14, color: AppColors.grayMid),
                    const SizedBox(width: 6),
                    Text(
                      "Sin productos en ${_radioKm.toStringAsFixed(0)} km",
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grayMid),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _mostrarFiltroRadio,
                      child: const Text("Ampliar",
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Tarjeta del producto seleccionado ──────────────────────────
        if (_seleccionado != null)
          _buildTarjetaSeleccionada(_seleccionado!),

        // ── Botón centrar en mi posición ───────────────────────────────
        Positioned(
          bottom: _seleccionado != null ? 130 : 20,
          right: 16,
          child: Column(
            children: [
              _fabMapa(
                icon: Icons.my_location_rounded,
                onTap: () {
                  if (_miLat != null && _miLng != null) {
                    _mapCtrl.move(
                        LatLng(_miLat!, _miLng!),
                        _mapCtrl.zoom);
                  }
                },
              ),
              const SizedBox(height: 8),
              _fabMapa(
                icon: Icons.tune_rounded,
                onTap: _mostrarFiltroRadio,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fabMapa({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.carbon),
      ),
    );
  }

  // ── Pantallas auxiliares ──────────────────────────────────────────────────
  Widget _pantallaPermisos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off,
                size: 64, color: AppColors.grayMid.withOpacity(0.4)),
            const SizedBox(height: 20),
            const Text("Necesitamos tu ubicación",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            const Text(
              "Para mostrarte productos cerca de ti, necesitamos acceder a tu ubicación.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.grayMid, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async =>
                    await Geolocator.openAppSettings(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Abrir configuración",
                    style: TextStyle(
                        color: AppColors.textOnPrimary,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _obtenerUbicacionYProductos,
              child: const Text("Reintentar",
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painter para la punta del marcador ────────────────────────────────────────
class _PuntaPainter extends CustomPainter {
  final Color color;
  const _PuntaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PuntaPainter old) => old.color != color;
}
