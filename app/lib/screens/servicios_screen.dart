import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'agregar_servicio_screen.dart';
import 'servicio_detalle_screen.dart';

class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({super.key});

  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _ofrezco = [];
  List<Map<String, dynamic>> _busco   = [];
  bool _cargando = true;
  int? _miUserId;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _inicializar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _inicializar() async {
    _miUserId = await SessionService.obtenerUser();
    await _cargar();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _cargar());
  }

  Future<void> _cargar() async {
    try {
      final o = await ApiService.obtenerServicios(tipo: 'ofrezco');
      final b = await ApiService.obtenerServicios(tipo: 'busco');
      if (mounted) {
        setState(() {
          _ofrezco = o;
          _busco   = b;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _irAAgregar() async {
    // Re-fetch userId en el momento de pulsar (por si la sesión cambió)
    final uid = await SessionService.obtenerUser();
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para publicar'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
      return;
    }
    // Pasar el tipo según el tab activo (0=Ofrezco, 1=Busco, 2=Mapa→Ofrezco)
    final tipoInicial =
        _tabController.index == 1 ? 'busco' : 'ofrezco';
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarServicioScreen(tipoInicial: tipoInicial),
      ),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Servicios',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Encuentra o publica servicios profesionales',
                  style: TextStyle(fontSize: 13, color: AppColors.grayMid),
                ),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.grayMid,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Ofrezco'),
                    Tab(text: 'Busco'),
                    Tab(text: 'Mapa'),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 0.5, color: AppColors.divider),

          // Contenido
          Expanded(
            child: _cargando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _ListaServicios(
                        servicios: _ofrezco,
                        tipo: 'ofrezco',
                        onRefresh: _cargar,
                      ),
                      _ListaServicios(
                        servicios: _busco,
                        tipo: 'busco',
                        onRefresh: _cargar,
                      ),
                      _MapaServicios(
                        servicios: [..._ofrezco, ..._busco],
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) {
          final label = _tabController.index == 1
              ? 'Publicar solicitud'
              : 'Publicar servicio';
          return FloatingActionButton.extended(
            onPressed: _irAAgregar,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          );
        },
      ),
    );
  }
}

// ── Lista de servicios ────────────────────────────────────────────────────────

class _ListaServicios extends StatelessWidget {
  final List<Map<String, dynamic>> servicios;
  final String tipo;
  final Future<void> Function() onRefresh;

  const _ListaServicios({
    required this.servicios,
    required this.tipo,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (servicios.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.handyman_outlined,
                  size: 64, color: AppColors.grayMid.withOpacity(0.4)),
              const SizedBox(height: 16),
              Text(
                tipo == 'ofrezco'
                    ? 'Aún no hay servicios publicados'
                    : 'Aún no hay solicitudes de servicio',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                tipo == 'ofrezco'
                    ? 'Sé el primero en publicar lo que ofreces'
                    : 'Publica lo que necesitas y recibe propuestas',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.grayMid),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: servicios.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _TarjetaServicio(servicio: servicios[i]),
      ),
    );
  }
}

// ── Tarjeta de servicio ───────────────────────────────────────────────────────

class _TarjetaServicio extends StatelessWidget {
  final Map<String, dynamic> servicio;
  const _TarjetaServicio({required this.servicio});

  @override
  Widget build(BuildContext context) {
    final nombre    = '${servicio['nombre'] ?? ''} ${servicio['apellido'] ?? ''}'.trim();
    final fotoUrl   = servicio['foto_url'] as String? ?? '';
    final titulo    = servicio['titulo'] as String? ?? '';
    final rating    = (servicio['rating'] as num?)?.toDouble() ?? 0.0;
    final numVal    = servicio['num_valoraciones'] as int? ?? 0;
    final modalidad = servicio['modalidad'] as String? ?? 'servicio';
    final valor     = (servicio['valor'] as num?)?.toDouble() ?? 0;
    final fotos     = servicio['fotos'] as List? ?? [];
    final verificado = servicio['certificado_verificado'] as bool? ?? false;
    final comunas   = servicio['comunas'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Imagen del servicio o avatar del usuario
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            child: fotos.isNotEmpty
                ? _media(fotos.first as String, 90, 100)
                : _avatar(fotoUrl, nombre, 90, 100),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre + badge
                  Row(
                    children: [
                      // Avatar pequeño
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        backgroundImage: fotoUrl.isNotEmpty
                            ? NetworkImage(
                                '${ApiService.baseUrl}$fotoUrl')
                            : null,
                        child: fotoUrl.isEmpty
                            ? Text(
                                nombre.isNotEmpty
                                    ? nombre[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.grayMid)),
                      ),
                      if (verificado)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Colors.green, size: 10),
                              SizedBox(width: 2),
                              Text('Certificado',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Título
                  Text(titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),

                  // Comunas
                  if (comunas.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 11, color: AppColors.grayMid),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(comunas,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.grayMid)),
                        ),
                      ],
                    ),

                  const SizedBox(height: 6),

                  // Precio + estrellas + botón
                  Row(
                    children: [
                      // Precio
                      if (valor > 0)
                        Text(
                          '\$${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} / $modalidad',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                      const Spacer(),

                      // Estrellas
                      _Estrellas(rating: rating, size: 12),
                      const SizedBox(width: 2),
                      Text('($numVal)',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.grayMid)),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Botón ver detalle
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServicioDetalleScreen(
                              servicio: servicio),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                            color: AppColors.primary, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Ver detalle',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _media(String path, double w, double h) {
    final url = '${ApiService.baseUrl}$path';
    final isVideo = path.endsWith('.mp4') || path.endsWith('.mov');
    return Stack(
      children: [
        Image.network(url,
            width: w, height: h, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                width: w, height: h, color: AppColors.background,
                child: const Icon(Icons.image, color: AppColors.grayMid))),
        if (isVideo)
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
      ],
    );
  }

  Widget _avatar(String fotoUrl, String nombre, double w, double h) {
    if (fotoUrl.isNotEmpty) {
      return Image.network(
        '${ApiService.baseUrl}$fotoUrl',
        width: w, height: h, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarPlaceholder(nombre, w, h),
      );
    }
    return _avatarPlaceholder(nombre, w, h);
  }

  Widget _avatarPlaceholder(String nombre, double w, double h) {
    return Container(
      width: w, height: h,
      color: AppColors.primary.withOpacity(0.12),
      child: Center(
        child: Text(
          nombre.isNotEmpty ? nombre[0].toUpperCase() : 'S',
          style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.primary),
        ),
      ),
    );
  }
}

// ── Mapa de servicios ─────────────────────────────────────────────────────────

class _MapaServicios extends StatelessWidget {
  final List<Map<String, dynamic>> servicios;
  const _MapaServicios({required this.servicios});

  @override
  Widget build(BuildContext context) {
    final conUbicacion = servicios
        .where((s) => s['lat'] != null && s['lng'] != null)
        .toList();

    if (conUbicacion.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: AppColors.grayMid),
            SizedBox(height: 16),
            Text('Ningún servicio tiene ubicación registrada',
                style: TextStyle(color: AppColors.grayMid)),
          ],
        ),
      );
    }

    final first = conUbicacion.first;
    final center =
        LatLng(first['lat'] as double, first['lng'] as double);

    return FlutterMap(
      options: MapOptions(center: center, zoom: 12),
      children: [
        TileLayer(
          urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.okventa.app',
        ),
        MarkerLayer(
          markers: conUbicacion.map((s) {
            final tipo = s['tipo'] as String? ?? 'ofrezco';
            return Marker(
              point: LatLng(s['lat'] as double, s['lng'] as double),
              width: 44,
              height: 44,
              builder: (_) => GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ServicioDetalleScreen(servicio: s),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: tipo == 'ofrezco'
                        ? AppColors.primary
                        : Colors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: const Icon(Icons.handyman,
                      color: Colors.white, size: 22),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Widget estrellas ──────────────────────────────────────────────────────────

class _Estrellas extends StatelessWidget {
  final double rating;
  final double size;
  const _Estrellas({required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half   = !filled && i < rating;
        return Icon(
          half ? Icons.star_half : filled ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }
}
