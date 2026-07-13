import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'agregar_servicio_screen.dart';
import 'delivery_registro_screen.dart';
import 'mapa_ubicacion_picker_screen.dart';
import 'okdelivery_pendientes_screen.dart';
import 'servicio_detalle_screen.dart';
import '../widgets/net_image.dart';
class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({super.key});

  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _ofrezco   = [];
  List<Map<String, dynamic>> _busco     = [];
  List<Map<String, dynamic>> _delivery  = [];
  bool _cargando = true;
  int? _miUserId;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      final d = await ApiService.obtenerDelivery(soloActivos: false);
      if (mounted) {
        setState(() {
          _ofrezco  = o;
          _busco    = b;
          _delivery = d;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('ERROR cargando servicios: $e');
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
    // Tab 3 = Delivery → ir a pantalla de registro
    if (_tabController.index == 3) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DeliveryRegistroScreen()),
      );
      _cargar();
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
                    Tab(text: 'Delivery'),
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
                        miUserId: _miUserId,
                        onUbicacionActualizada: _cargar,
                      ),
                      _DeliveryTab(
                        delivery: _delivery,
                        miUserId: _miUserId,
                        onRefresh: _cargar,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _irAAgregar,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 26),
      ),
    );
  }
}

// ── Constantes compartidas ───────────────────────────────────────────────────

const _kCategorias = [
  'Construcción', 'Transporte', 'Electrodomésticos', 'Servicio',
  'Salud', 'Profesional', 'Asesorías', 'Computación', 'Otros',
];

const _kCategoriaIconos = <String, IconData>{
  'Construcción':       Icons.construction_outlined,
  'Transporte':         Icons.directions_car_outlined,
  'Electrodomésticos':  Icons.kitchen_outlined,
  'Servicio':           Icons.miscellaneous_services_outlined,
  'Salud':              Icons.health_and_safety_outlined,
  'Profesional':        Icons.business_center_outlined,
  'Asesorías':          Icons.support_agent_outlined,
  'Computación':        Icons.computer_outlined,
  'Otros':              Icons.more_horiz_rounded,
};

Color _hexColor(String? hex) {
  if (hex == null || hex.isEmpty) return AppColors.primary;
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return AppColors.primary;
  }
}

// ── Lista de servicios ────────────────────────────────────────────────────────

class _ListaServicios extends StatefulWidget {
  final List<Map<String, dynamic>> servicios;
  final String tipo;
  final Future<void> Function() onRefresh;

  const _ListaServicios({
    required this.servicios,
    required this.tipo,
    required this.onRefresh,
  });

  @override
  State<_ListaServicios> createState() => _ListaServiciosState();
}

class _ListaServiciosState extends State<_ListaServicios> {
  String? _categoriaSeleccionada;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // ── Tamaño (columnas, persistido y compartido entre Ofrezco/Busco) ───────
  // 1 columna = tarjeta horizontal ancha (diseño actual, sin cambios).
  // 2-3 columnas = tarjeta compacta vertical (como el marketplace).
  int _columnas = ColumnasServicios.valor;

  @override
  void initState() {
    super.initState();
    ColumnasServicios.cargar().then((v) {
      if (mounted) setState(() => _columnas = v);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtrados {
    var lista = widget.servicios;
    if (_categoriaSeleccionada != null) {
      lista = lista
          .where((s) => (s['categoria'] ?? 'Otros') == _categoriaSeleccionada)
          .toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      lista = lista.where((s) {
        final titulo = (s['titulo'] ?? '').toString().toLowerCase();
        final desc   = (s['descripcion'] ?? '').toString().toLowerCase();
        return titulo.contains(q) || desc.contains(q);
      }).toList();
    }
    return lista;
  }

  void _mostrarControlTamano() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
              const Text('Tamaño de las publicaciones',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Achica para ver más servicios, agranda para verlos más grandes',
                  style: TextStyle(fontSize: 12, color: AppColors.grayMid)),
              Row(
                children: [
                  const Icon(Icons.grid_view_rounded,
                      size: 16, color: AppColors.grayMid),
                  Expanded(
                    child: Slider(
                      value: _columnas.toDouble(),
                      min: 1,
                      max: 3,
                      divisions: 2,
                      activeColor: AppColors.primary,
                      onChanged: (v) {
                        final nuevo = v.round();
                        setSheetState(() => _columnas = nuevo);
                        setState(() => _columnas = nuevo);
                        ColumnasServicios.guardar(nuevo);
                      },
                    ),
                  ),
                  const Icon(Icons.crop_square_rounded,
                      size: 22, color: AppColors.grayMid),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    return Column(
      children: [
        // ── Buscador + control de tamaño ────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: widget.tipo == 'ofrezco'
                          ? 'Buscar servicios...'
                          : 'Buscar solicitudes...',
                      hintStyle: const TextStyle(color: AppColors.grayMid, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.grayMid),
                      suffixIcon: _query.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                              child: const Icon(Icons.close, size: 16, color: AppColors.grayMid),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _mostrarControlTamano,
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Icon(Icons.photo_size_select_large_outlined,
                      size: 17, color: AppColors.grayMid),
                ),
              ),
            ],
          ),
        ),

        // ── Categorías (fila propia, no comparte espacio con ningún botón) ──
        Container(
          color: AppColors.surface,
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            itemCount: _kCategorias.length,
            itemBuilder: (_, i) {
              final cat = _kCategorias[i];
              final sel = _categoriaSeleccionada == cat;
              final icon = _kCategoriaIconos[cat] ?? Icons.more_horiz_rounded;
              return GestureDetector(
                onTap: () => setState(() =>
                    _categoriaSeleccionada = sel ? null : cat),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: sel ? AppColors.primary : AppColors.divider,
                      width: 0.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13,
                          color: sel ? Colors.white : AppColors.grayMid),
                      const SizedBox(width: 5),
                      Text(cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: sel ? Colors.white : AppColors.textPrimary,
                          )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Divider(height: 0.5, color: AppColors.divider),

        Expanded(child: _buildLista(filtrados)),
      ],
    );
  }

  Widget _buildVacio() {
    final sinResultados = _categoriaSeleccionada != null || _query.isNotEmpty;
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
              sinResultados
                  ? 'Sin resultados'
                  : widget.tipo == 'ofrezco'
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
              sinResultados
                  ? 'Prueba con otra categoría o búsqueda'
                  : widget.tipo == 'ofrezco'
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

  // Espacio extra al final para que el FAB '+' no tape el último elemento.
  static const _kPaddingInferiorFab = 88.0;

  Widget _buildLista(List<Map<String, dynamic>> servicios) {
    if (servicios.isEmpty) return _buildVacio();

    if (_columnas == 1) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: AppColors.primary,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, _kPaddingInferiorFab),
          itemCount: servicios.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _TarjetaServicio(servicio: servicios[i]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, _kPaddingInferiorFab),
        itemCount: servicios.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columnas,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (_, i) =>
            _TarjetaServicioCompacta(servicio: servicios[i]),
      ),
    );
  }
}

// ── Preferencia de columnas (persistida) ─────────────────────────────────────

class ColumnasServicios {
  static const _kPref = 'srv_columnas';
  static int valor = 1;

  static Future<int> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    valor = prefs.getInt(_kPref) ?? 1;
    return valor;
  }

  static Future<void> guardar(int v) async {
    valor = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPref, v);
  }
}

// ── Tarjeta de servicio ───────────────────────────────────────────────────────

class _TarjetaServicio extends StatelessWidget {
  final Map<String, dynamic> servicio;
  const _TarjetaServicio({required this.servicio});

  @override
  Widget build(BuildContext context) {
    const imgW = 63.0;
    const imgH = 70.0;
    final nombre    = '${servicio['nombre'] ?? ''} ${servicio['apellido'] ?? ''}'.trim();
    final fotoUrl   = servicio['foto_url'] as String? ?? '';
    final tipo      = servicio['tipo'] as String? ?? 'ofrezco';
    final titulo    = servicio['titulo'] as String? ?? '';
    final rating    = (servicio['rating'] as num?)?.toDouble() ?? 0.0;
    final numVal    = servicio['num_valoraciones'] as int? ?? 0;
    final modalidad = servicio['modalidad'] as String? ?? 'servicio';
    final valor     = (servicio['valor'] as num?)?.toDouble() ?? 0;
    final fotos     = servicio['fotos'] as List? ?? [];
    final verificado = servicio['certificado_verificado'] as bool? ?? false;
    final comunas   = servicio['comunas'] as String? ?? '';
    final tipoColor = tipo == 'ofrezco' ? AppColors.primary : Colors.orange;
    final prefix    = tipo == 'ofrezco' ? 'Ofrezco' : 'Busco';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left:   BorderSide(color: tipoColor, width: 4),
          top:    BorderSide(color: AppColors.divider, width: 0.5),
          right:  BorderSide(color: AppColors.divider, width: 0.5),
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
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
                ? _media(fotos.first as String, imgW, imgH)
                : _avatar(fotoUrl, nombre, imgW, imgH),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre + badge
                  Row(
                    children: [
                      // Avatar pequeño
                      CircleAvatar(
                        radius: 9,
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
                                    fontSize: 8,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700),
                              )
                            : null,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.grayMid)),
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

                  // Título con prefijo "Ofrezco:" / "Busco:"
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$prefix: ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: tipoColor,
                          ),
                        ),
                        TextSpan(
                          text: titulo,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Comunas
                  if (comunas.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 10, color: AppColors.grayMid),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(comunas,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.grayMid)),
                        ),
                      ],
                    ),

                  const SizedBox(height: 4),

                  // Precio + estrellas
                  Row(
                    children: [
                      if (valor > 0)
                        Text(
                          '\$${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} / $modalidad',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: tipoColor),
                        ),
                      const Spacer(),
                      _Estrellas(rating: rating, size: 10),
                      const SizedBox(width: 2),
                      Text('($numVal)',
                          style: const TextStyle(
                              fontSize: 9, color: AppColors.grayMid)),
                    ],
                  ),

                  const SizedBox(height: 6),

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
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Ver detalle',
                          style: TextStyle(
                              fontSize: 10,
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
        NetImage(url, width: w, height: h, fit: BoxFit.cover),
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
      return NetImage(
        '${ApiService.baseUrl}$fotoUrl',
        width: w, height: h, fit: BoxFit.cover,
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

// ── Tarjeta compacta (grilla, 2-3 columnas) — imagen arriba, info abajo ──────
// Se activa cuando el control de tamaño reduce las publicaciones para ver
// más a la vez, igual que la grilla del marketplace.

class _TarjetaServicioCompacta extends StatelessWidget {
  final Map<String, dynamic> servicio;
  const _TarjetaServicioCompacta({required this.servicio});

  @override
  Widget build(BuildContext context) {
    final nombre    = '${servicio['nombre'] ?? ''} ${servicio['apellido'] ?? ''}'.trim();
    final fotoUrl   = servicio['foto_url'] as String? ?? '';
    final tipo      = servicio['tipo'] as String? ?? 'ofrezco';
    final titulo    = servicio['titulo'] as String? ?? '';
    final rating    = (servicio['rating'] as num?)?.toDouble() ?? 0.0;
    final numVal    = servicio['num_valoraciones'] as int? ?? 0;
    final modalidad = servicio['modalidad'] as String? ?? 'servicio';
    final valor     = (servicio['valor'] as num?)?.toDouble() ?? 0;
    final fotos     = servicio['fotos'] as List? ?? [];
    final tipoColor = tipo == 'ofrezco' ? AppColors.primary : Colors.orange;
    final prefix    = tipo == 'ofrezco' ? 'Ofrezco' : 'Busco';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServicioDetalleScreen(servicio: servicio),
        ),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen/avatar — el ancho crece o se achica con las columnas
            AspectRatio(
              aspectRatio: 1.3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  fotos.isNotEmpty
                      ? NetImage('${ApiService.baseUrl}${fotos.first}',
                          fit: BoxFit.cover)
                      : (fotoUrl.isNotEmpty
                          ? NetImage('${ApiService.baseUrl}$fotoUrl',
                              fit: BoxFit.cover)
                          : Container(
                              color: AppColors.primary.withOpacity(0.12),
                              child: Center(
                                child: Text(
                                  nombre.isNotEmpty
                                      ? nombre[0].toUpperCase()
                                      : 'S',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary),
                                ),
                              ),
                            )),
                  Positioned(
                    left: 0, top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: tipoColor,
                        borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(10)),
                      ),
                      child: Text(prefix,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  if (valor > 0)
                    Text(
                      '\$${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')} / $modalidad',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: tipoColor),
                    ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _Estrellas(rating: rating, size: 9),
                      const SizedBox(width: 2),
                      Text('($numVal)',
                          style: const TextStyle(
                              fontSize: 9, color: AppColors.grayMid)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab Delivery OkVenta ──────────────────────────────────────────────────────

class _DeliveryTab extends StatefulWidget {
  final List<Map<String, dynamic>> delivery;
  final int? miUserId;
  final Future<void> Function() onRefresh;

  const _DeliveryTab({
    required this.delivery,
    required this.miUserId,
    required this.onRefresh,
  });

  @override
  State<_DeliveryTab> createState() => _DeliveryTabState();
}

class _DeliveryTabState extends State<_DeliveryTab> {
  bool _toggling = false;

  Future<void> _toggleActivo(Map<String, dynamic> d) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    final nuevoActivo = !((d['activo'] as int? ?? 1) == 1);
    try {
      await ApiService.toggleDeliveryActivo(
          d['id'] as int, widget.miUserId!, nuevoActivo);
      await widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.delivery.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delivery_dining_outlined,
                  size: 64, color: AppColors.grayMid.withOpacity(0.4)),
              const SizedBox(height: 16),
              const Text(
                'No hay deliveries registrados aún',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Toca el botón + para registrarte como Delivery OkVenta',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.grayMid),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: widget.delivery.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final d = widget.delivery[i];
          final esMio = widget.miUserId != null &&
              d['user_id'] == widget.miUserId;
          final activo = (d['activo'] as int? ?? 1) == 1;
          final fotoUrl = d['foto_perfil'] as String? ?? '';
          final nombre = d['nombre'] as String? ?? 'Sin nombre';
          final vehiculo = d['tipo_vehiculo'] as String? ?? 'bicicleta';
          final comunas  = d['radio_km'] != null
              ? 'Radio: ${(d['radio_km'] as num).toStringAsFixed(0)} km'
              : '';

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: activo
                    ? Colors.green.withOpacity(0.35)
                    : AppColors.divider,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    backgroundImage: fotoUrl.isNotEmpty
                        ? NetworkImage('${ApiService.baseUrl}$fotoUrl')
                        : null,
                    child: fotoUrl.isEmpty
                        ? Text(
                            nombre[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: activo ? Colors.green : AppColors.grayMid,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(nombre,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  _vehiculoIcon(vehiculo),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: activo
                              ? Colors.green.withOpacity(0.1)
                              : AppColors.grayMid.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          activo ? '✅ Disponible' : '⏸ Inactivo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: activo ? Colors.green : AppColors.grayMid,
                          ),
                        ),
                      ),
                      if (comunas.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(comunas,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.grayMid)),
                      ],
                    ],
                  ),
                  if (esMio) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _toggling ? null : () => _toggleActivo(d),
                        icon: Icon(
                            activo
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            size: 16),
                        label: Text(
                          activo ? 'Pausar disponibilidad' : 'Activarme',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              activo ? Colors.orange : Colors.green,
                          side: BorderSide(
                              color: activo
                                  ? Colors.orange
                                  : Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    if (activo) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OkdeliveryPendientesScreen(
                                    deliveryId: d['id'] as int),
                              ),
                            );
                            widget.onRefresh();
                          },
                          icon: const Icon(Icons.delivery_dining_rounded,
                              size: 16),
                          label: const Text('Ver entregas disponibles',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              onTap: esMio
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeliveryRegistroScreen(
                              perfilExistente: d),
                        ),
                      );
                      widget.onRefresh();
                    }
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _vehiculoIcon(String v) {
    final icons = {
      'bicicleta': Icons.directions_bike_rounded,
      'moto':      Icons.two_wheeler_rounded,
      'auto':      Icons.directions_car_rounded,
    };
    return Icon(icons[v] ?? Icons.delivery_dining_outlined,
        size: 20, color: AppColors.grayMid);
  }
}

// ── Mapa de servicios ─────────────────────────────────────────────────────────

final _kSantiago = LatLng(-33.4489, -70.6693);

class _MapaServicios extends StatefulWidget {
  final List<Map<String, dynamic>> servicios;
  final int? miUserId;
  final VoidCallback onUbicacionActualizada;

  const _MapaServicios({
    required this.servicios,
    required this.miUserId,
    required this.onUbicacionActualizada,
  });

  @override
  State<_MapaServicios> createState() => _MapaServiciosState();
}

class _MapaServiciosState extends State<_MapaServicios> {
  bool    _guardando        = false;
  bool    _panelAbierto     = false;
  String? _filtroTipo;       // null = todos | 'ofrezco' | 'busco'
  String? _filtroCategoria;  // null = todas | nombre de categoría

  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _serviciosFiltrados {
    var lista = widget.servicios.where((s) {
      if (_filtroTipo != null && s['tipo'] != _filtroTipo) return false;
      if (_filtroCategoria != null && s['categoria'] != _filtroCategoria) {
        return false;
      }
      return true;
    }).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      lista = lista.where((s) {
        final titulo = (s['titulo'] ?? '').toString().toLowerCase();
        final cat    = (s['categoria'] ?? '').toString().toLowerCase();
        return titulo.contains(q) || cat.contains(q);
      }).toList();
    }
    return lista;
  }

  Future<void> _ajustarRadio(Map<String, dynamic> s) async {
    final result = await Navigator.push<UbicacionElegida>(
      context,
      MaterialPageRoute(
        builder: (_) => MapaUbicacionPickerScreen(
          latInicial:    (s['lat'] as num).toDouble(),
          lngInicial:    (s['lng'] as num).toDouble(),
          radioKmInicial: (s['radio_km'] as num?)?.toDouble() ?? 5.0,
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _guardando = true);
    try {
      final resp = await http.patch(
        Uri.parse('${ApiService.baseUrl}/servicios/${s['id']}/ubicacion'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id':  widget.miUserId,
          'lat':      result.lat,
          'lng':      result.lng,
          'radio_km': result.radioKm,
        }),
      );
      if (resp.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ubicación actualizada'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onUbicacionActualizada();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtrados     = _serviciosFiltrados;
    final conUbicacion  = filtrados
        .where((s) => s['lat'] != null && s['lng'] != null)
        .toList();
    final todos         = widget.servicios
        .where((s) => s['lat'] != null && s['lng'] != null)
        .toList();

    final center = todos.isNotEmpty
        ? LatLng(
            (todos.first['lat'] as num).toDouble(),
            (todos.first['lng'] as num).toDouble(),
          )
        : _kSantiago;

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(center: center, zoom: 11),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.okventa.app',
            ),

            // ── Círculos de cobertura ─────────────────────────────────────
            if (conUbicacion.isNotEmpty)
              CircleLayer(
                circles: conUbicacion.map((s) {
                  final radioKm = (s['radio_km'] as num?)?.toDouble() ?? 5.0;
                  final color   = _hexColor(s['color_hex'] as String?);
                  return CircleMarker(
                    point: LatLng(
                      (s['lat'] as num).toDouble(),
                      (s['lng'] as num).toDouble(),
                    ),
                    radius: radioKm * 1000,
                    useRadiusInMeter: true,
                    color: color.withOpacity(0.12),
                    borderStrokeWidth: 1.5,
                    borderColor: color.withOpacity(0.5),
                  );
                }).toList(),
              ),

            // ── Globos de texto ───────────────────────────────────────────
            if (conUbicacion.isNotEmpty)
              MarkerLayer(
                markers: conUbicacion.map((s) {
                  final tipo    = s['tipo'] as String? ?? 'ofrezco';
                  final titulo  = s['titulo'] as String? ?? '';
                  final esMio   = widget.miUserId != null &&
                      s['user_id'] == widget.miUserId;
                  final color   = _hexColor(s['color_hex'] as String?);
                  final palabras = titulo.trim()
                      .split(RegExp(r'\s+'))
                      .take(2)
                      .join(' ');
                  final label =
                      '${tipo == 'ofrezco' ? 'Ofrezco' : 'Busco'}: $palabras';

                  return Marker(
                    point: LatLng(
                      (s['lat'] as num).toDouble(),
                      (s['lng'] as num).toDouble(),
                    ),
                    width: 170,
                    height: esMio ? 64 : 46,
                    anchorPos: AnchorPos.align(AnchorAlign.bottom),
                    builder: (_) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ServicioDetalleScreen(servicio: s),
                            ),
                          ),
                          child: _GloboMarcador(label: label, color: color),
                        ),
                        // Botón ajustar radio SOLO para el titular
                        if (esMio)
                          GestureDetector(
                            onTap: _guardando ? null : () => _ajustarRadio(s),
                            child: Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: color.withOpacity(0.5)),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4)
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.radar_rounded,
                                      size: 11, color: color),
                                  const SizedBox(width: 3),
                                  Text('Ajustar radio',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: color)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),

        // ── Panel de filtros (izquierda) ──────────────────────────────────
        Positioned(
          left: 8,
          top: 12,
          child: _buildFiltroPanel(),
        ),

        // Aviso cuando no hay ubicaciones tras filtrar
        if (conUbicacion.isEmpty)
          Positioned(
            top: 16,
            left: 110,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline,
                      size: 13, color: AppColors.grayMid),
                  SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Sin ubicación registrada',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.grayMid),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Buscador inferior ──────────────────────────────────────────
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar servicio en el mapa…',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.grayMid),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: AppColors.grayMid),
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.grayMid),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              ),
            ),
          ),
        ),

        if (_guardando)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  // ── Panel de filtros lateral izquierdo (colapsable) ──────────────────────
  Widget _buildFiltroPanel() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: 88,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header — toca para expandir/colapsar
              GestureDetector(
                onTap: () => setState(() {
                  _panelAbierto = !_panelAbierto;
                  if (!_panelAbierto) {
                    _filtroTipo      = null;
                    _filtroCategoria = null;
                  }
                }),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 7),
                  color: AppColors.carbon,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text('Filtrar',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                      Icon(
                        _panelAbierto
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 13,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),

              // Contenido — solo visible cuando el panel está abierto
              if (_panelAbierto) ...[
                // Filtro por tipo
                _fBtn(null, Icons.apps_rounded, 'Todos',
                    _filtroTipo == null, AppColors.carbon),
                _fBtn('ofrezco', Icons.handyman_outlined, 'Ofrezco',
                    _filtroTipo == 'ofrezco', AppColors.primary),
                _fBtn('busco', Icons.search_rounded, 'Busco',
                    _filtroTipo == 'busco', Colors.orange),

                Container(height: 0.5, color: AppColors.divider),

                // Categorías (scrollable)
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: _kCategorias.map((cat) {
                        final icon =
                            _kCategoriaIconos[cat] ?? Icons.more_horiz_rounded;
                        final sel = _filtroCategoria == cat;
                        return InkWell(
                          onTap: () => setState(() {
                            _filtroCategoria = sel ? null : cat;
                          }),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            color: sel
                                ? AppColors.primary.withOpacity(0.1)
                                : null,
                            child: Column(
                              children: [
                                Icon(icon,
                                    size: 16,
                                    color: sel
                                        ? AppColors.primary
                                        : AppColors.grayMid),
                                const SizedBox(height: 2),
                                Text(
                                  cat.length > 8
                                      ? '${cat.substring(0, 7)}…'
                                      : cat,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: sel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: sel
                                        ? AppColors.primary
                                        : AppColors.grayMid,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _fBtn(String? tipo, IconData icon, String label,
      bool sel, Color color) {
    return InkWell(
      onTap: () => setState(() {
        _filtroTipo = (tipo == null || _filtroTipo == tipo) ? tipo : tipo;
        if (tipo == null) _filtroTipo = null;
        else _filtroTipo = _filtroTipo == tipo ? null : tipo;
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        color: sel ? color.withOpacity(0.1) : null,
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: sel ? color : AppColors.grayMid),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? color : AppColors.grayMid,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Globo de marcador (speech bubble) ────────────────────────────────────────

class _GloboMarcador extends StatelessWidget {
  final String label;
  final Color  color;
  const _GloboMarcador({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Burbuja
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        // Triángulo puntero — truco de borders sin CustomPainter
        SizedBox(
          width: 12,
          height: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: const BorderSide(
                    width: 6, color: Colors.transparent),
                right: const BorderSide(
                    width: 6, color: Colors.transparent),
                top: BorderSide(width: 6, color: color),
              ),
            ),
          ),
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
