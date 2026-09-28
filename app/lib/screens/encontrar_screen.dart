import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/regiones_chile.dart';
import '../widgets/barra_filtros.dart';
import '../widgets/insignia.dart';
import '../widgets/invitacion_servicio_instalacion.dart'
    show categoriaServicioParaProducto;
import '../widgets/net_image.dart';
import 'mapa_ubicacion_picker_screen.dart';
import 'producto_detalle_screen.dart';
import 'servicio_detalle_screen.dart';
import 'servicios_screen.dart';

/// Encontrar: EL mapa de la app.
///
/// Antes había dos mapas —este, solo con productos, y la pestaña "Mapa" de
/// OkServicios— cada uno con sus filtros y su código. Ahora hay uno:
///
/// - Arriba, dos interruptores: Productos y Servicios. Se pueden ver los dos
///   a la vez (pin con foto y precio / círculo oscuro con la llave), que es
///   justamente lo útil: el calentador en venta y el gasfíter que lo
///   instala, a dos cuadras.
/// - Debajo, la misma fila de filtros de OkMarket y OkServicios (filtro de
///   búsqueda cerca de mí / por zona, y categorías). Al elegir una región,
///   el mapa se mueve hasta allá.
/// - Al tocar un producto, la ficha muestra una descripción breve y si
///   requiere instalación: si la hace el vendedor, o qué proveedor de
///   OkServicios se sugiere.
///
/// En el mapa van solo los servicios que se OFRECEN: los "busco" son
/// pedidos, no lugares a donde ir.
class EncontrarScreen extends StatefulWidget {
  /// Abrir con la capa de servicios encendida y la de productos apagada
  /// (se llega así desde el botón de mapa de OkServicios).
  final bool soloServicios;

  const EncontrarScreen({super.key, this.soloServicios = false});

  @override
  State<EncontrarScreen> createState() => _EncontrarScreenState();
}

// Categorías de cada capa (las mismas que OkMarket y OkServicios).
const _kCatsProductos = <OpcionCategoria>[
  OpcionCategoria('Automotriz', Icons.directions_car_rounded),
  OpcionCategoria('Electrónica', Icons.devices_rounded),
  OpcionCategoria('Hogar', Icons.weekend_rounded),
  OpcionCategoria('Ropa', Icons.checkroom_outlined),
  OpcionCategoria('Deportes', Icons.fitness_center_rounded),
  OpcionCategoria('Ocio', Icons.sports_soccer_rounded),
  OpcionCategoria('Mascotas', Icons.pets_rounded),
  OpcionCategoria('Salud', Icons.health_and_safety_outlined),
  OpcionCategoria('Construcción', Icons.construction_outlined),
  OpcionCategoria('Fotografía', Icons.camera_alt_outlined),
  OpcionCategoria('Educación', Icons.menu_book_outlined),
  OpcionCategoria('Negocios', Icons.business_center_outlined),
  OpcionCategoria('General', Icons.category_rounded),
];

const _kCatsServicios = <OpcionCategoria>[
  OpcionCategoria('Construcción', Icons.construction_outlined),
  OpcionCategoria('Transporte', Icons.directions_car_outlined),
  OpcionCategoria('Electrodomésticos', Icons.kitchen_outlined),
  OpcionCategoria('Servicio', Icons.miscellaneous_services_outlined),
  OpcionCategoria('Salud', Icons.health_and_safety_outlined),
  OpcionCategoria('Profesional', Icons.business_center_outlined),
  OpcionCategoria('Asesorías', Icons.support_agent_outlined),
  OpcionCategoria('Computación', Icons.computer_outlined),
  OpcionCategoria('Otros', Icons.more_horiz_rounded),
];

final _kSantiago = LatLng(-33.4489, -70.6693);

class _EncontrarScreenState extends State<EncontrarScreen> {
  final _mapCtrl = MapController();
  final _searchCtrl = TextEditingController();

  // Datos
  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _servicios = [];
  bool _cargando = true;
  bool _errorConexion = false;
  int? _miUserId;

  // Ubicación
  Coordenadas? _yo;
  bool _buscandoGps = true;

  // Capas
  bool _verProductos = true;
  bool _verServicios = false;

  // Filtros (la misma barra que OkMarket / OkServicios)
  PanelFiltro _panel = PanelFiltro.ninguno;
  double _radioKm = 10;
  bool _distanciaActiva = false;
  bool _modoZona = false;
  final List<String> _regiones = [];
  final List<String> _categorias = [];
  String _query = '';

  // Selección
  Map<String, dynamic>? _selProducto;
  Map<String, dynamic>? _selServicio;

  @override
  void initState() {
    super.initState();
    if (widget.soloServicios) {
      _verProductos = false;
      _verServicios = true;
    }
    SessionService.obtenerUser().then((id) {
      if (mounted) setState(() => _miUserId = id);
    });
    _cargarDatos();
    _cargarUbicacion();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Carga ────────────────────────────────────────────────────────────────

  /// Se traen TODAS las publicaciones y servicios con ubicación, no solo
  /// los cercanos: el modo "Por zona" busca en otras regiones.
  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _errorConexion = false;
    });
    try {
      final r = await http
          .get(Uri.parse('${ApiService.baseUrl}/publicaciones'))
          .timeout(const Duration(seconds: 15));
      final todos = List<Map<String, dynamic>>.from(
          jsonDecode(utf8.decode(r.bodyBytes)));
      final servs = await ApiService.obtenerServicios(tipo: 'ofrezco');
      if (!mounted) return;
      setState(() {
        _productos = todos
            .where((p) =>
                p['lat'] is num &&
                p['lng'] is num &&
                (p['estado'] ?? 'disponible') == 'disponible')
            .toList();
        _servicios =
            servs.where((s) => s['lat'] is num && s['lng'] is num).toList();
        _cargando = false;
      });
    } catch (e) {
      debugPrint('ERROR Encontrar: $e');
      if (mounted) {
        setState(() {
          _cargando = false;
          _errorConexion = true;
        });
      }
    }
  }

  Future<void> _cargarUbicacion({bool centrar = true}) async {
    setState(() => _buscandoGps = true);
    final c = await UbicacionService.obtener(usarCache: !centrar);
    if (!mounted) return;
    setState(() {
      _yo = c ?? _yo;
      _buscandoGps = false;
    });
    if (c != null) {
      final uid = await SessionService.obtenerUser();
      if (uid != null) {
        try {
          await ApiService.actualizarUbicacion(
              userId: uid, lat: c.lat, lng: c.lng);
        } catch (_) {}
      }
      if (centrar) _mover(LatLng(c.lat, c.lng), 13.5);
    }
  }

  void _mover(LatLng p, double zoom) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapCtrl.move(p, zoom);
      } catch (_) {}
    });
  }

  /// Encuadra el mapa en las regiones elegidas.
  void _encuadrarRegiones() {
    final puntos = <LatLng>[
      for (final r in _regiones)
        for (final (lat, lng) in RegionesChile.puntosDe(r)) LatLng(lat, lng),
    ];
    if (puntos.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapCtrl.fitBounds(
          LatLngBounds.fromPoints(puntos),
          options: const FitBoundsOptions(
              padding: EdgeInsets.all(40), maxZoom: 12),
        );
      } catch (_) {}
    });
  }

  // ── Filtrado ─────────────────────────────────────────────────────────────

  bool get _radioAplica => !_modoZona && _distanciaActiva && _yo != null;
  bool get _zonaAplica => _modoZona && _regiones.isNotEmpty;

  bool _pasaUbicacion(Map item) {
    if (_zonaAplica) {
      final r = RegionesChile.regionDeItem(item);
      return r != null && _regiones.contains(r);
    }
    if (_radioAplica) return _km(item) <= _radioKm;
    return true;
  }

  /// Cada capa se filtra solo con las categorías que son suyas: elegir
  /// "Transporte" (de servicios) no debe esconder todos los productos.
  bool _pasaCategoria(Map item, List<OpcionCategoria> propias) {
    final mias =
        _categorias.where((c) => propias.any((o) => o.nombre == c)).toList();
    if (mias.isEmpty) return true;
    return mias.contains((item['categoria'] ?? '').toString());
  }

  bool _pasaTexto(Map item) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return (item['titulo'] ?? '').toString().toLowerCase().contains(q) ||
        (item['categoria'] ?? '').toString().toLowerCase().contains(q);
  }

  List<Map<String, dynamic>> get _productosVisibles => !_verProductos
      ? const []
      : _productos
          .where((p) =>
              _pasaUbicacion(p) &&
              _pasaCategoria(p, _kCatsProductos) &&
              _pasaTexto(p))
          .toList();

  List<Map<String, dynamic>> get _serviciosVisibles => !_verServicios
      ? const []
      : _servicios
          .where((s) =>
              _pasaUbicacion(s) &&
              _pasaCategoria(s, _kCatsServicios) &&
              _pasaTexto(s))
          .toList();

  /// Categorías que ofrece la barra según las capas encendidas. Con las
  /// dos, se juntan sin repetir (Construcción y Salud existen en ambas).
  List<OpcionCategoria> get _opcionesCategorias {
    final out = <OpcionCategoria>[];
    void sumar(List<OpcionCategoria> l) {
      for (final o in l) {
        if (!out.any((x) => x.nombre == o.nombre)) out.add(o);
      }
    }

    if (_verProductos) sumar(_kCatsProductos);
    if (_verServicios) sumar(_kCatsServicios);
    return out;
  }

  /// Al apagar una capa, sus categorías dejan de tener sentido en el filtro.
  void _limpiarCategoriasHuerfanas() {
    final validas = _opcionesCategorias.map((o) => o.nombre).toSet();
    _categorias.removeWhere((c) => !validas.contains(c));
  }

  // ── Utilidades ───────────────────────────────────────────────────────────

  static double _dist(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _km(Map item) {
    final yo = _yo;
    final lat = item['lat'], lng = item['lng'];
    if (yo == null || lat is! num || lng is! num) return double.infinity;
    return _dist(yo.lat, yo.lng, lat.toDouble(), lng.toDouble());
  }

  static String _fmtKm(double km) {
    if (km.isInfinite) return '';
    return km < 1
        ? '${(km * 1000).toStringAsFixed(0)} m'
        : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  static String _url(String u) =>
      u.startsWith('http') ? u : '${ApiService.baseUrl}$u';

  static bool _si(dynamic v) => v == true || v == 1 || v == '1';

  /// La descripción viene con marcas de formato (negritas, viñetas): para
  /// dos líneas de adelanto basta el texto plano.
  static String _textoPlano(dynamic d) => (d ?? '')
      .toString()
      .replaceAll(RegExp(r'[*_#>`~]'), '')
      .replaceAll(RegExp(r'^\s*[-•]\s*', multiLine: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _nombreServicio(Map s) => [s['nombre'], s['apellido']]
      .where((x) => x != null && '$x'.trim().isNotEmpty)
      .join(' ');

  Future<void> _comoLlegar(Map item) async {
    final lat = (item['lat'] as num?)?.toDouble();
    final lng = (item['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    // Punto aproximado: no se revela la dirección exacta del vendedor.
    final rng = math.Random();
    final la = lat + (rng.nextDouble() - 0.5) * 0.002;
    final ln = lng + (rng.nextDouble() - 0.5) * 0.002;
    final titulo =
        Uri.encodeComponent((item['titulo'] ?? 'OkVenta').toString());
    final apple = Uri.parse('maps://?q=$titulo&ll=$la,$ln');
    if (await canLaunchUrl(apple)) {
      await launchUrl(apple);
    } else {
      await launchUrl(Uri.parse('https://www.google.com/maps?q=$la,$ln'),
          mode: LaunchMode.externalApplication);
    }
  }

  // ── Instalación: quién la hace ────────────────────────────────────────────

  String _catServicioDe(Map p) => categoriaServicioParaProducto(
      (p['categoria'] ?? '').toString(), (p['subcategoria'] ?? '').toString());

  /// El servicio que publicó el propio vendedor para instalar (el que le
  /// ofrece publicar la invitación después de vender), si existe.
  Map<String, dynamic>? _servicioDelVendedor(Map p) {
    final vendedor = p['user_id'];
    if (vendedor == null) return null;
    final cat = _catServicioDe(p);
    final suyos = _servicios.where((s) => s['user_id'] == vendedor).toList();
    if (suyos.isEmpty) return null;
    return suyos.firstWhere(
      (s) =>
          (s['titulo'] ?? '').toString().toLowerCase().contains('instala') ||
          s['categoria'] == cat,
      orElse: () => suyos.first,
    );
  }

  /// Proveedor sugerido para instalar un producto.
  ///
  /// Solo si la categoría del producto tiene una equivalencia clara en
  /// OkServicios: sugerir a alguien de "Otros" sería recomendar a
  /// cualquiera. Entre los que calzan: primero certificados, después mejor
  /// nota y al final el más cercano al producto. Además tiene que atender
  /// esa zona: no se sugiere a alguien a 300 km.
  Map<String, dynamic>? _proveedorSugerido(Map p) {
    final cat = _catServicioDe(p);
    if (cat == 'Otros') return null;
    final plat = p['lat'], plng = p['lng'];
    if (plat is! num || plng is! num) return null;

    final candidatos = <(Map<String, dynamic>, double)>[];
    for (final s in _servicios) {
      if (s['categoria'] != cat || s['user_id'] == p['user_id']) continue;
      final d = _dist(plat.toDouble(), plng.toDouble(),
          (s['lat'] as num).toDouble(), (s['lng'] as num).toDouble());
      final cobertura =
          math.max(((s['radio_km'] as num?) ?? 5).toDouble(), 25.0);
      if (d <= cobertura) candidatos.add((s, d));
    }
    if (candidatos.isEmpty) return null;
    candidatos.sort((a, b) {
      final ca = _si(a.$1['certificado_verificado']) ? 1 : 0;
      final cb = _si(b.$1['certificado_verificado']) ? 1 : 0;
      if (ca != cb) return cb - ca;
      final ra = ((a.$1['rating'] as num?) ?? 0).toDouble();
      final rb = ((b.$1['rating'] as num?) ?? 0).toDouble();
      if (ra != rb) return rb.compareTo(ra);
      return a.$2.compareTo(b.$2);
    });
    final mejor = Map<String, dynamic>.from(candidatos.first.$1);
    mejor['_km_al_producto'] = candidatos.first.$2;
    return mejor;
  }

  // ── Dueño de un servicio: ajustar ubicación y radio ───────────────────────
  // Vivía en el mapa de OkServicios; se trae aquí para no perderlo.

  Future<void> _ajustarUbicacion(Map<String, dynamic> s) async {
    final res = await Navigator.push<UbicacionElegida>(
      context,
      MaterialPageRoute(
        builder: (_) => MapaUbicacionPickerScreen(
          latInicial: (s['lat'] as num).toDouble(),
          lngInicial: (s['lng'] as num).toDouble(),
          radioKmInicial: ((s['radio_km'] as num?) ?? 5).toDouble(),
        ),
      ),
    );
    if (res == null || !mounted) return;
    try {
      final r = await http.patch(
        Uri.parse('${ApiService.baseUrl}/servicios/${s['id']}/ubicacion'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _miUserId,
          'lat': res.lat,
          'lng': res.lng,
          'radio_km': res.radioKm,
        }),
      );
      if (!mounted) return;
      final ok = r.statusCode == 200;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            ok ? '✅ Ubicación actualizada' : 'No se pudo actualizar la ubicación'),
        backgroundColor: ok ? Colors.green : colors.primary,
      ));
      if (ok) {
        setState(() => _selServicio = null);
        _cargarDatos();
      }
    } catch (_) {}
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final productos = _productosVisibles;
    final servicios = _serviciosVisibles;
    final hayFicha = _selProducto != null || _selServicio != null;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 18, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text('Encontrar',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: Icon(Icons.refresh_rounded, color: colors.textPrimary),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: Column(
        children: [
          _encabezado(productos.length, servicios.length),
          Expanded(
            child: _cargando
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary))
                : _errorConexion
                    ? _vistaError()
                    : Stack(
                        children: [
                          _mapa(productos, servicios),
                          if (!hayFicha)
                            Positioned(
                              right: 12,
                              bottom: 16,
                              child: _botonMiUbicacion(),
                            ),
                          if (productos.isEmpty && servicios.isEmpty)
                            Positioned(
                              top: 12,
                              left: 12,
                              right: 12,
                              child: _avisoVacio(),
                            ),
                          if (_selProducto != null)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: _fichaProducto(_selProducto!),
                            ),
                          if (_selServicio != null)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: _fichaServicio(_selServicio!),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _encabezado(int nProd, int nServ) {
    return Container(
      color: colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Capas: se pueden encender las dos. Nunca quedan las dos
          // apagadas: apagar la última enciende la otra.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                _interruptorCapa(
                  texto: 'Productos',
                  icono: Icons.shopping_bag_outlined,
                  n: nProd,
                  activo: _verProductos,
                  color: colors.primary,
                  onTap: () => setState(() {
                    _verProductos = !_verProductos;
                    if (!_verProductos && !_verServicios) _verServicios = true;
                    _limpiarCategoriasHuerfanas();
                    _selProducto = null;
                  }),
                ),
                const SizedBox(width: 8),
                _interruptorCapa(
                  texto: 'Servicios',
                  icono: Icons.handyman_outlined,
                  n: nServ,
                  activo: _verServicios,
                  color: colors.carbon,
                  onTap: () => setState(() {
                    _verServicios = !_verServicios;
                    if (!_verProductos && !_verServicios) _verProductos = true;
                    _limpiarCategoriasHuerfanas();
                    _selServicio = null;
                  }),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.divider),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.trim()),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar en el mapa…',
                  hintStyle: TextStyle(color: colors.grayMid, fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: colors.grayMid),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          child:
                              Icon(Icons.close, size: 16, color: colors.grayMid))
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),
          BarraFiltros(
            radioKm: _radioKm,
            distanciaActiva: _distanciaActiva,
            sinGps: _yo == null && !_buscandoGps,
            cargandoUbicacion: _buscandoGps,
            onRadioChanged: (v) => setState(() {
              _radioKm = v;
              _distanciaActiva = true;
            }),
            onToggleDistancia: () =>
                setState(() => _distanciaActiva = !_distanciaActiva),
            modoZona: _modoZona,
            regiones: _regiones,
            onModoZona: (z) {
              setState(() => _modoZona = z);
              final yo = _yo;
              if (z) {
                _encuadrarRegiones();
              } else if (yo != null) {
                _mover(LatLng(yo.lat, yo.lng), 12.5);
              }
            },
            onAgregarRegion: (r) {
              setState(() {
                if (!_regiones.contains(r)) _regiones.add(r);
              });
              _encuadrarRegiones();
            },
            onQuitarRegion: (r) {
              setState(() => _regiones.remove(r));
              _encuadrarRegiones();
            },
            categorias: _opcionesCategorias,
            seleccionadas: _categorias,
            onAgregarCategoria: (c) => setState(() {
              if (!_categorias.contains(c)) _categorias.add(c);
            }),
            onQuitarCategoria: (c) => setState(() => _categorias.remove(c)),
            panel: _panel,
            onPanel: (p) => setState(() => _panel = p),
          ),
          Divider(height: 0.5, thickness: 0.5, color: colors.divider),
        ],
      ),
    );
  }

  Widget _interruptorCapa({
    required String texto,
    required IconData icono,
    required int n,
    required bool activo,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36,
          decoration: BoxDecoration(
            color: activo ? color : colors.background,
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: activo ? color : colors.divider, width: 0.8),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(activo ? Icons.check_rounded : icono,
                  size: 15, color: activo ? Colors.white : colors.grayMid),
              const SizedBox(width: 5),
              Text(texto,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: activo ? Colors.white : colors.textSecondary)),
              if (activo && !_cargando) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$n',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapa(List<Map<String, dynamic>> productos,
      List<Map<String, dynamic>> servicios) {
    final yo = _yo;
    final centro = yo != null ? LatLng(yo.lat, yo.lng) : _kSantiago;

    final markers = <Marker>[
      for (final s in servicios)
        Marker(
          point: LatLng(
              (s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()),
          width: 44,
          height: 50,
          anchorPos: AnchorPos.align(AnchorAlign.top),
          builder: (_) => _pinServicio(s),
        ),
      for (final p in productos)
        Marker(
          point: LatLng(
              (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
          width: 64,
          height: 60,
          anchorPos: AnchorPos.align(AnchorAlign.top),
          builder: (_) => _pinProducto(p),
        ),
      if (yo != null)
        Marker(
          point: LatLng(yo.lat, yo.lng),
          width: 22,
          height: 22,
          builder: (_) => _puntoYo(),
        ),
    ];

    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        center: centro,
        zoom: yo != null ? 13.5 : 11,
        maxZoom: 19,
        onTap: (_, __) => setState(() {
          _selProducto = null;
          _selServicio = null;
        }),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.okventa.app',
        ),
        if (_radioAplica && yo != null)
          CircleLayer(circles: [
            CircleMarker(
              point: LatLng(yo.lat, yo.lng),
              radius: _radioKm * 1000,
              useRadiusInMeter: true,
              color: colors.primary.withValues(alpha: 0.06),
              borderStrokeWidth: 1.5,
              borderColor: colors.primary.withValues(alpha: 0.5),
            ),
          ]),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _puntoYo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: Colors.blue.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 2),
        ],
      ),
    );
  }

  /// Producto: foto + precio, como siempre.
  Widget _pinProducto(Map<String, dynamic> p) {
    final sel = _selProducto?['id'] == p['id'];
    final img = (p['imagen_url'] ?? '').toString();
    final vacio = Container(
      width: 30,
      height: 30,
      color: colors.background,
      child: Icon(Icons.shopping_bag_outlined, size: 15, color: colors.primary),
    );
    final instala = _si(p['instalacion_vendedor']);
    return GestureDetector(
      onTap: () => setState(() {
        _selServicio = null;
        _selProducto = sel ? null : p;
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(clipBehavior: Clip.none, children: [
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: sel ? colors.primary : Colors.white,
                  width: sel ? 2.5 : 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 5,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: img.isEmpty
                  ? vacio
                  : NetImage(_url(img),
                      width: 30, height: 30, errorWidget: vacio),
            ),
          ),
          if (instala)
            const Positioned(
              right: -8,
              top: -6,
              child: Insignia.instalacion(tamano: 16, explicable: false),
            ),
          ]),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            constraints: const BoxConstraints(maxWidth: 64),
            decoration: BoxDecoration(
              color: sel ? colors.primary : colors.primaryDark,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(formatPrecio(p['precio']),
                  maxLines: 1,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          CustomPaint(
            size: const Size(10, 5),
            painter: _PuntaPainter(sel ? colors.primary : colors.primaryDark),
          ),
        ],
      ),
    );
  }

  /// Servicio: círculo oscuro con la llave, para que no se confunda con un
  /// producto aunque estén uno encima del otro.
  Widget _pinServicio(Map<String, dynamic> s) {
    final sel = _selServicio?['id'] == s['id'];
    final cert = _si(s['certificado_verificado']);
    return GestureDetector(
      onTap: () => setState(() {
        _selProducto = null;
        _selServicio = sel ? null : s;
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: sel ? 38 : 34,
                height: sel ? 38 : 34,
                decoration: BoxDecoration(
                  color: sel ? colors.primary : colors.carbon,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 5,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.handyman_rounded,
                    size: 17, color: Colors.white),
              ),
              if (cert)
                const Positioned(
                  right: -5,
                  top: -5,
                  child: Insignia.certificado(tamano: 18, explicable: false),
                ),
            ],
          ),
          CustomPaint(
            size: const Size(10, 6),
            painter: _PuntaPainter(sel ? colors.primary : colors.carbon),
          ),
        ],
      ),
    );
  }

  Widget _botonMiUbicacion() {
    return Material(
      color: colors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          if (_modoZona) setState(() => _modoZona = false);
          _cargarUbicacion();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: _buscandoGps
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.primary))
              : Icon(Icons.my_location, size: 20, color: colors.primary),
        ),
      ),
    );
  }

  Widget _avisoVacio() {
    final texto = _zonaAplica
        ? 'Nada con ubicación en ${_regiones.length == 1 ? _regiones.first : 'esas regiones'}'
        : _radioAplica
            ? 'Nada a menos de ${_fmtKm(_radioKm)} de ti'
            : 'Sin resultados con estos filtros';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8),
        ],
      ),
      child: Row(children: [
        Icon(Icons.search_off_rounded, size: 18, color: colors.grayMid),
        const SizedBox(width: 8),
        Expanded(
            child: Text(texto,
                style: TextStyle(fontSize: 13, color: colors.textSecondary))),
      ]),
    );
  }

  Widget _vistaError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: colors.primary),
          const SizedBox(height: 12),
          Text('Sin conexión al servidor',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: colors.textPrimary)),
          const SizedBox(height: 12),
          TextButton(
              onPressed: _cargarDatos,
              child: Text('Reintentar', style: TextStyle(color: colors.primary))),
        ]),
      ),
    );
  }

  // ── Fichas ───────────────────────────────────────────────────────────────

  Widget _contenedorFicha(
      {required Widget child, required VoidCallback onClose}) {
    return Material(
      color: colors.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Padding(padding: const EdgeInsets.all(12), child: child),
          Positioned(
            right: 2,
            top: 2,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: colors.grayMid),
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniatura(String url, IconData icono) {
    final fallback = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
          color: colors.background, borderRadius: BorderRadius.circular(10)),
      child: Icon(icono, color: colors.grayMid),
    );
    if (url.isEmpty) return fallback;
    return NetImage(_url(url),
        width: 72,
        height: 72,
        borderRadius: BorderRadius.circular(10),
        errorWidget: fallback);
  }

  Widget _descripcion(dynamic d) {
    final t = _textoPlano(d);
    if (t.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(t,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12.5, height: 1.3, color: colors.textSecondary)),
    );
  }

  Widget _fichaProducto(Map<String, dynamic> p) {
    final km = _km(p);
    return _contenedorFicha(
      onClose: () => setState(() => _selProducto = null),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _miniatura((p['imagen_url'] ?? '').toString(),
                  Icons.shopping_bag_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((p['titulo'] ?? '').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(formatPrecio(p['precio']),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: colors.primary)),
                      Text(
                        [
                          (p['nombre_vendedor'] ?? '').toString(),
                          _fmtKm(km),
                        ].where((x) => x.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colors.grayMid),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _descripcion(p['descripcion']),
          _lineaInstalacion(p),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _comoLlegar(p),
                icon: const Icon(Icons.directions_outlined, size: 16),
                label: const Text('Cómo llegar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.divider),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProductoDetalleScreen(producto: p)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Ver producto'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _cajaInstalacion({
    required IconData icono,
    Widget? lider,
    required Color color,
    required String titulo,
    String? detalle,
    String? accion,
    VoidCallback? onAccion,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.6),
      ),
      child: Row(children: [
        lider ?? Icon(icono, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              if (detalle != null && detalle.isNotEmpty)
                Text(detalle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11.5, color: colors.textSecondary)),
            ],
          ),
        ),
        if (accion != null)
          TextButton(
            onPressed: onAccion,
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(accion,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  /// Línea de instalación de la ficha de producto. Tres casos: la hace el
  /// vendedor / se sugiere un proveedor de OkServicios / no requiere (nada).
  Widget _lineaInstalacion(Map<String, dynamic> p) {
    if (!_si(p['requiere_instalacion'])) return const SizedBox.shrink();

    if (_si(p['instalacion_vendedor'])) {
      final suyo = _servicioDelVendedor(p);
      return _cajaInstalacion(
        icono: Icons.check_circle_rounded,
        lider: const Insignia.instalacion(tamano: 26),
        color: Insignia.dorado,
        titulo: 'Instalación incluida',
        detalle: 'La hace el mismo vendedor',
        accion: suyo != null ? 'Ver servicio' : null,
        onAccion: suyo == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ServicioDetalleScreen(servicio: suyo))),
      );
    }

    final prov = _proveedorSugerido(p);
    if (prov != null) {
      final rating = ((prov['rating'] as num?) ?? 0).toDouble();
      final kmProv = prov['_km_al_producto'];
      final partes = <String>[
        _nombreServicio(prov),
        (prov['titulo'] ?? '').toString(),
        if (rating > 0) '★ ${rating.toStringAsFixed(1)}',
        if (kmProv is double) 'a ${_fmtKm(kmProv)} del producto',
      ].where((x) => x.isNotEmpty).toList();
      return _cajaInstalacion(
        icono: Icons.handyman_rounded,
        lider: _si(prov['certificado_verificado'])
            ? const Insignia.certificado(tamano: 26)
            : null,
        color: colors.carbon,
        titulo: _si(prov['certificado_verificado'])
            ? 'Requiere instalación · sugerido (certificado)'
            : 'Requiere instalación · sugerido',
        detalle: partes.join(' · '),
        accion: 'Ver',
        onAccion: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ServicioDetalleScreen(servicio: prov))),
      );
    }

    // Sin proveedor que calce (o categoría sin equivalencia): se manda a
    // buscar, igual que en el detalle del producto.
    return _cajaInstalacion(
      icono: Icons.build_outlined,
      color: colors.warning,
      titulo: 'Requiere instalación',
      detalle: 'El vendedor no la hace',
      accion: 'Buscar',
      onAccion: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServiciosScreen(
              busquedaInicial: (p['categoria'] ?? '').toString()),
        ),
      ),
    );
  }

  Widget _fichaServicio(Map<String, dynamic> s) {
    final fotos = s['fotos'];
    final foto =
        (fotos is List && fotos.isNotEmpty) ? fotos.first.toString() : '';
    final rating = ((s['rating'] as num?) ?? 0).toDouble();
    final nVal = ((s['num_valoraciones'] as num?) ?? 0).toInt();
    final cert = _si(s['certificado_verificado']);
    final valor = s['valor'];
    final porHora = s['modalidad'] == 'hora';
    final km = _km(s);
    final esMio = _miUserId != null && s['user_id'] == _miUserId;

    final datos = <String>[
      if (valor is num && valor > 0)
        '${formatPrecio(valor)}${porHora ? ' / hora' : ''}',
      if (rating > 0) '★ ${rating.toStringAsFixed(1)} ($nVal)',
      _fmtKm(km),
    ].where((x) => x.isNotEmpty).join(' · ');

    return _contenedorFicha(
      onClose: () => setState(() => _selServicio = null),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _miniatura(foto, Icons.handyman_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((s['titulo'] ?? '').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Flexible(
                          child: Text(_nombreServicio(s),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: colors.textSecondary)),
                        ),
                        if (cert) ...[
                          const SizedBox(width: 4),
                          const Insignia.certificado(tamano: 18),
                        ],
                      ]),
                      if (datos.isNotEmpty)
                        Text(datos,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _descripcion(s['descripcion']),
          const SizedBox(height: 10),
          Row(children: [
            if (esMio) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _ajustarUbicacion(s),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Ajustar ubicación'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ServicioDetalleScreen(servicio: s)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.carbon,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(esMio ? 'Ver mi servicio' : 'Ver y contactar'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// La punta de los pines.
class _PuntaPainter extends CustomPainter {
  final Color color;
  const _PuntaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PuntaPainter old) => old.color != color;
}
