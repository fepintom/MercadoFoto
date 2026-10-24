import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as am;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import '../services/mapas_config.dart';
import '../widgets/controles_mapa.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/apple_mapkit.dart';
import '../services/session_service.dart';
import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/regiones_chile.dart';
import '../widgets/barra_filtros.dart';
import '../widgets/insignia.dart';
import '../widgets/okventin_servicio.dart';
import '../widgets/invitacion_servicio_instalacion.dart'
    show categoriaServicioParaProducto;
import '../widgets/net_image.dart';
import '../widgets/pines_apple.dart';
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

  /// true = es la pestaña "Encontrar" del menú (sin flecha de volver; la
  /// barra de abajo sigue a la vista).
  final bool esPestana;

  const EncontrarScreen(
      {super.key, this.soloServicios = false, this.esPestana = false});

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

  /// En iPhone el mapa es Apple Maps (nativo: nítido, modo oscuro y
  /// lugares). En Android sigue el mapa de CARTO.
  static bool get _apple => Platform.isIOS;
  am.AppleMapController? _appleCtrl;
  void Function(am.AppleMapController)? _pendienteApple;
  bool _generandoPines = false;

  // Buscador de Apple (lugares y direcciones), rutas y vista de calle.
  List<LugarApple> _lugares = [];
  Timer? _esperaBusqueda;
  LugarApple? _lugarSel;
  // Ruta en auto y a pie (se calculan las dos para mostrar ambos tiempos).
  RutaApple? _rutaAuto;
  RutaApple? _rutaPie;
  bool _aPie = false;
  RutaApple? get _ruta => _aPie ? (_rutaPie ?? _rutaAuto) : (_rutaAuto ?? _rutaPie);

  // "Ir": navegación dentro de la app (sigue tu posición + cronómetro).
  bool _navegando = false;
  bool _llegaste = false;
  DateTime? _inicioNav;
  Duration _transcurrido = Duration.zero;
  Timer? _cronometro;
  StreamSubscription<Position>? _posNav;
  LatLng? _origenRutaNav;
  Map<String, dynamic>? _rutaItem;
  bool _calculandoRuta = false;

  // "¿Cómo llegar aquí?": punto marcado manteniendo presionado el mapa.
  LatLng? _marcado;
  String? _marcadoDir;
  static Uint8List? _pinOkventin; // Okventín pixel art dentro del pin
  static Uint8List? _pinLugar; // gota azul con tiendita (lugares de Apple)
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
    if (_apple) {
      AppleMapKit.aplicarEstilo();
      _cargarPinesFijos();
    }
  }

  @override
  void dispose() {
    _esperaBusqueda?.cancel();
    _cronometro?.cancel();
    _posNav?.cancel();
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
      _encuadrarInicial();
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
      _encuadrarInicial();
    }
  }

  bool _yaEncuadrado = false;

  /// Al abrir, encuadra el mapa en lo que importa (una vez, cuando ya hay
  /// datos y ubicación): con radio, el círculo completo; sin radio, tu
  /// ubicación y lo más cercano. Así no aparece un mapa vacío o cortado.
  void _encuadrarInicial() {
    final yo = _yo;
    if (_yaEncuadrado || _cargando || yo == null) return;
    _yaEncuadrado = true;
    final centro = LatLng(yo.lat, yo.lng);
    List<LatLng> puntos;
    if (_radioAplica) {
      final dLat = _radioKm / 111.0;
      final dLng = _radioKm / (111.0 * math.cos(yo.lat * math.pi / 180));
      puntos = [
        LatLng(yo.lat - dLat, yo.lng - dLng),
        LatLng(yo.lat + dLat, yo.lng + dLng),
      ];
    } else {
      final cerca = [
        ..._productosVisibles,
        ..._serviciosVisibles,
      ]
          .map((m) => LatLng(
              (m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()))
          .toList()
        ..sort((a, b) => _distCuadrada(centro, a).compareTo(_distCuadrada(centro, b)));
      puntos = [centro, ...cerca.take(12)];
    }
    if (puntos.length < 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_apple) {
        _encajarApple(puntos, 60);
        return;
      }
      try {
        _mapCtrl.fitBounds(
          LatLngBounds.fromPoints(puntos),
          options: const FitBoundsOptions(
              padding: EdgeInsets.fromLTRB(40, 60, 40, 60), maxZoom: 15),
        );
      } catch (_) {}
    });
  }

  /// Ejecuta [accion] en el mapa de Apple apenas exista.
  void _conApple(void Function(am.AppleMapController) accion) {
    final c = _appleCtrl;
    if (c != null) {
      try {
        accion(c);
      } catch (_) {}
    } else {
      _pendienteApple = accion;
    }
  }

  void _encajarApple(List<LatLng> puntos, double margen) {
    var s = puntos.first.latitude, n = s;
    var o = puntos.first.longitude, e = o;
    for (final p in puntos) {
      s = math.min(s, p.latitude);
      n = math.max(n, p.latitude);
      o = math.min(o, p.longitude);
      e = math.max(e, p.longitude);
    }
    // Muy juntos: no acercar de más.
    if ((n - s) < 0.004 && (e - o) < 0.004) {
      _conApple((c) => c.animateCamera(am.CameraUpdate.newLatLngZoom(
          am.LatLng((s + n) / 2, (o + e) / 2), 15)));
      return;
    }
    _conApple((c) => c.animateCamera(am.CameraUpdate.newLatLngBounds(
        am.LatLngBounds(
            southwest: am.LatLng(s, o), northeast: am.LatLng(n, e)),
        margen)));
  }

  double _distCuadrada(LatLng a, LatLng b) {
    final dx = (a.latitude - b.latitude);
    final dy = (a.longitude - b.longitude) * math.cos(a.latitude * math.pi / 180);
    return dx * dx + dy * dy;
  }

  void _mover(LatLng p, double zoom) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_apple) {
        _conApple((c) => c.animateCamera(am.CameraUpdate.newLatLngZoom(
            am.LatLng(p.latitude, p.longitude), zoom)));
        return;
      }
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
      if (_apple) {
        _encajarApple(puntos, 40);
        return;
      }
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
    if (_apple) {
      _rutaA(Map<String, dynamic>.from(item));
      return;
    }
    // Punto aproximado: no se revela la dirección exacta del vendedor.
    final (la, ln) = _puntoAprox(item);
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
      // Como pestaña va bajo el encabezado de la app (con el logo): sin
      // barra propia. Abierta suelta, mantiene su barra con "volver".
      appBar: widget.esPestana ? null : AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.esPestana
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    size: 18, color: colors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
        titleSpacing: widget.esPestana ? 16 : 0,
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
                          _apple
                              ? _mapaApple(productos, servicios)
                              : _mapa(productos, servicios),
                          // Crédito del mapa (Apple pone el suyo).
                          if (!_apple)
                            Positioned(
                              left: 6,
                              bottom: 4,
                              child: MapasConfig.atribucion(),
                            ),
                          if (!hayFicha && _apple)
                            Positioned(
                              right: 12,
                              bottom: 16,
                              child: _controlesApple(),
                            ),
                          if (!hayFicha && !_apple)
                            Positioned(
                              right: 12,
                              bottom: 16,
                              // + / − y mi ubicación (iguales en todos
                              // los mapas de la app).
                              child: ControlesMapa(
                                controller: _mapCtrl,
                                cargandoUbicacion: _buscandoGps,
                                onMiUbicacion: () async {
                                  if (_modoZona) {
                                    setState(() => _modoZona = false);
                                  }
                                  await _cargarUbicacion();
                                },
                              ),
                            ),
                          if (_apple && _ruta != null)
                            Positioned(
                              top: 10,
                              left: 12,
                              right: 12,
                              child: _barraRuta(),
                            ),
                          if (_apple && _hayResultados && !_navegando)
                            Positioned(
                              top: 8,
                              left: 12,
                              right: 12,
                              child: _listaResultados(),
                            ),
                          if (productos.isEmpty &&
                              servicios.isEmpty &&
                              !(_apple && _hayResultados) &&
                              _ruta == null)
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
            padding: EdgeInsets.fromLTRB(12, widget.esPestana ? 8 : 4, 12, 8),
            child: Row(
              children: [
                _interruptorCapa(
                  texto: 'Productos',
                  // Caja: "productos" (el carro se confunde con comprar).
                  icono: Icons.inventory_2_rounded,
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
                  icono: Icons.handyman_rounded,
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
              height: 40,
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.divider),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  setState(() => _query = v.trim());
                  if (_apple) _buscarLugares(v.trim());
                },
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar en el mapa…',
                  hintStyle: TextStyle(color: colors.grayMid, fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 21, color: colors.primary),
                  // Con texto: borrar. Sin texto: recargar el mapa.
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() {
                              _query = '';
                              _lugares = [];
                            });
                          },
                          child:
                              Icon(Icons.close, size: 16, color: colors.grayMid))
                      : GestureDetector(
                          onTap: _cargarDatos,
                          child: Icon(Icons.refresh_rounded,
                              size: 19, color: colors.grayMid)),
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
          height: 40,
          decoration: BoxDecoration(
            color: activo ? color : colors.background,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: activo ? color : colors.divider, width: 0.8),
            boxShadow: activo
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono,
                  size: 18,
                  color: activo ? Colors.white : colors.textPrimary),
              const SizedBox(width: 7),
              Text(texto,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: activo ? Colors.white : colors.textPrimary)),
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
          width: 88,
          height: 68,
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
        ...MapasConfig.capas(),
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

  // ── Apple Maps (iPhone) ──────────────────────────────────────────────────

  String _claveP(Map p, bool sel) =>
      'p${p['id']}_${sel ? 1 : 0}_${p['precio']}_${colors.primary.toARGB32()}';
  String _claveS(Map s, bool sel) =>
      's${s['id']}_${sel ? 1 : 0}_${s['titulo']}_${colors.primary.toARGB32()}';

  /// Dibuja los pins que faltan (en segundo plano) y refresca el mapa.
  void _prepararPines(List<Map<String, dynamic>> productos,
      List<Map<String, dynamic>> servicios) {
    if (_generandoPines) return;
    final faltan = <Future<void> Function()>[];
    for (final p in productos) {
      final sel = _selProducto?['id'] == p['id'];
      final k = _claveP(p, sel);
      if (PinesApple.listo(k) == null) {
        final img = (p['imagen_url'] ?? '').toString();
        faltan.add(() => PinesApple.producto(
              clave: k,
              fotoUrl: img.isEmpty ? null : _url(img),
              precio: formatPrecio(p['precio']),
              sel: sel,
              colorPrecio: colors.primaryDark,
              colorSel: colors.primary,
              fondoFoto: colors.background,
              iconoVacio: colors.primary,
            ));
      }
    }
    for (final sv in servicios) {
      final sel = _selServicio?['id'] == sv['id'];
      final k = _claveS(sv, sel);
      if (PinesApple.listo(k) == null) {
        faltan.add(() => PinesApple.servicio(
              clave: k,
              titulo: (sv['titulo'] ?? 'Servicio').toString(),
              sel: sel,
              colorBase: colors.carbon,
              colorSel: colors.primary,
            ));
      }
    }
    if (faltan.isEmpty) return;
    _generandoPines = true;
    () async {
      // De a varios a la vez (las fotos se descargan en paralelo).
      for (var i = 0; i < faltan.length; i += 8) {
        await Future.wait(faltan.skip(i).take(8).map((f) async {
          try {
            await f();
          } catch (_) {}
        }));
        if (mounted) setState(() {});
      }
      _generandoPines = false;
      if (mounted) setState(() {});
    }();
  }

  Widget _mapaApple(List<Map<String, dynamic>> productos,
      List<Map<String, dynamic>> servicios) {
    final yo = _yo;
    final centro = yo != null ? LatLng(yo.lat, yo.lng) : _kSantiago;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _prepararPines(productos, servicios));

    final anotaciones = <am.Annotation>{};
    for (final sv in servicios) {
      final sel = _selServicio?['id'] == sv['id'];
      final png = PinesApple.listo(_claveS(sv, sel));
      if (png == null) continue;
      anotaciones.add(am.Annotation(
        annotationId: am.AnnotationId('s${sv['id']}'),
        position: am.LatLng(
            (sv['lat'] as num).toDouble(), (sv['lng'] as num).toDouble()),
        icon: am.BitmapDescriptor.fromBytes(png),
        anchor: const Offset(0.5, 1.0),
        zIndex: sel ? 1000 : 2,
        onTap: () => setState(() {
          _selProducto = null;
          _selServicio = sel ? null : sv;
        }),
      ));
    }
    for (final p in productos) {
      final sel = _selProducto?['id'] == p['id'];
      final png = PinesApple.listo(_claveP(p, sel));
      if (png == null) continue;
      anotaciones.add(am.Annotation(
        annotationId: am.AnnotationId('p${p['id']}'),
        position: am.LatLng(
            (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
        icon: am.BitmapDescriptor.fromBytes(png),
        anchor: const Offset(0.5, 1.0),
        zIndex: sel ? 1000 : 1,
        onTap: () => setState(() {
          _selServicio = null;
          _selProducto = sel ? null : p;
        }),
      ));
    }

    final lugar = _lugarSel;
    if (lugar != null) {
      anotaciones.add(am.Annotation(
        annotationId: am.AnnotationId('lugar'),
        position: am.LatLng(lugar.lat, lugar.lng),
        icon: _pinLugar != null
            ? am.BitmapDescriptor.fromBytes(_pinLugar!)
            : am.BitmapDescriptor.markerAnnotation,
        anchor: const Offset(0.5, 1.0),
        infoWindow: am.InfoWindow(title: lugar.nombre, snippet: lugar.direccion),
        zIndex: 2000,
      ));
    }

    final marcado = _marcado;
    if (marcado != null) {
      anotaciones.add(am.Annotation(
        annotationId: am.AnnotationId('marcado'),
        position: am.LatLng(marcado.latitude, marcado.longitude),
        icon: _pinOkventin != null
            ? am.BitmapDescriptor.fromBytes(_pinOkventin!)
            : am.BitmapDescriptor.markerAnnotation,
        anchor: const Offset(0.5, 1.0),
        zIndex: 3000,
        infoWindow: am.InfoWindow(
          title: '¿Cómo llegar aquí?',
          onTap: _rutaAlMarcado,
        ),
      ));
    }

    return am.AppleMap(
      initialCameraPosition: am.CameraPosition(
        target: am.LatLng(centro.latitude, centro.longitude),
        zoom: yo != null ? 13.5 : 11,
      ),
      mapType: const [
        am.MapType.standard,
        am.MapType.satellite,
        am.MapType.hybrid
      ][AppleMapKit.tipo.clamp(0, 2)],
      trafficEnabled: AppleMapKit.trafico,
      trackingMode: _navegando
          ? am.TrackingMode.followWithHeading
          : am.TrackingMode.none,
      polylines: {
        if (_ruta != null)
          am.Polyline(
            polylineId: am.PolylineId('ruta'),
            points: [for (final (la, ln) in _ruta!.puntos) am.LatLng(la, ln)],
            color: const Color(0xFF0A84FF),
            width: 6,
          ),
      },
      onMapCreated: (c) {
        _appleCtrl = c;
        AppleMapKit.aplicarEstilo();
        final pend = _pendienteApple;
        _pendienteApple = null;
        if (pend != null) pend(c);
      },
      myLocationEnabled: true,
      compassEnabled: false,
      pitchGesturesEnabled: true,
      rotateGesturesEnabled: true,
      annotations: anotaciones,
      circles: {
        if (_radioAplica && yo != null)
          am.Circle(
            circleId: am.CircleId('radio'),
            center: am.LatLng(yo.lat, yo.lng),
            radius: _radioKm * 1000,
            fillColor: colors.primary.withValues(alpha: 0.06),
            strokeColor: colors.primary.withValues(alpha: 0.5),
            strokeWidth: 2,
          ),
      },
      onTap: (_) => setState(() {
        _selProducto = null;
        _selServicio = null;
        _marcado = null;
      }),
      onLongPress: _marcar,
    );
  }

  /// + / − y mi ubicación sobre Apple Maps (mismo diseño que el resto).
  Widget _controlesApple() {
    Widget boton(IconData icono, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icono, size: 22, color: colors.textPrimary),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Material(
        color: colors.surface,
        elevation: 3,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _opcionesMapa,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.layers_outlined,
                size: 21, color: colors.textPrimary),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Material(
        color: colors.surface,
        elevation: 3,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          boton(Icons.add_rounded,
              () => _conApple((c) => c.animateCamera(am.CameraUpdate.zoomIn()))),
          Container(width: 28, height: 0.6, color: colors.divider),
          boton(Icons.remove_rounded,
              () => _conApple((c) => c.animateCamera(am.CameraUpdate.zoomOut()))),
        ]),
      ),
      const SizedBox(height: 10),
      _botonMiUbicacion(),
    ]);
  }

  /// Punto aproximado (fijo para cada publicación): no se revela la
  /// dirección exacta del vendedor.
  (double, double) _puntoAprox(Map item) {
    final lat = (item['lat'] as num).toDouble();
    final lng = (item['lng'] as num).toDouble();
    if (item['_exacto'] == true) return (lat, lng);
    final rng = math.Random('${item['id']}${item['titulo']}'.hashCode);
    return (
      lat + (rng.nextDouble() - 0.5) * 0.002,
      lng + (rng.nextDouble() - 0.5) * 0.002,
    );
  }

  void _aviso(String t) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          content: Text(t), behavior: SnackBarBehavior.floating));
  }

  // ── Buscador de Apple ──────────────────────────────────────────────────

  void _buscarLugares(String texto) {
    _esperaBusqueda?.cancel();
    if (texto.length < 3) {
      if (_lugares.isNotEmpty) setState(() => _lugares = []);
      return;
    }
    _esperaBusqueda = Timer(const Duration(milliseconds: 450), () async {
      final yo = _yo;
      final r = await AppleMapKit.buscar(texto,
          lat: yo?.lat ?? _kSantiago.latitude,
          lng: yo?.lng ?? _kSantiago.longitude);
      if (!mounted || _query != texto) return;
      setState(() => _lugares = r);
    });
  }

  void _irALugar(LugarApple l) {
    FocusScope.of(context).unfocus();
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _lugares = [];
      _lugarSel = l;
      _marcado = null;
      _selProducto = null;
      _selServicio = null;
    });
    _mover(LatLng(l.lat, l.lng), 16);
    Future.delayed(const Duration(milliseconds: 700), () {
      _appleCtrl?.showMarkerInfoWindow(am.AnnotationId('lugar'));
    });
  }

  // ── Resultados del buscador: primero OkVenta, después Apple ─────────────

  static String _sinTildes(String t) {
    const de = 'áéíóúüñÁÉÍÓÚÜÑ';
    const a = 'aeiouunAEIOUUN';
    final b = StringBuffer();
    for (final ch in t.split('')) {
      final i = de.indexOf(ch);
      b.write(i >= 0 ? a[i] : ch);
    }
    return b.toString().toLowerCase();
  }

  /// Productos y servicios de OkVenta que coinciden con lo escrito (todas
  /// las palabras, sin importar tildes), aunque su capa esté apagada. Los
  /// más cercanos primero.
  List<Map<String, dynamic>> get _resultadosOkventa {
    if (_query.length < 2) return const [];
    final palabras =
        _sinTildes(_query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    bool calza(Map m) {
      final t = _sinTildes([
        m['titulo'],
        m['categoria'],
        m['subcategoria'],
        m['descripcion'],
      ].where((x) => x != null).join(' '));
      return palabras.every(t.contains);
    }

    final out = <Map<String, dynamic>>[
      for (final s in _servicios)
        if (calza(s)) {...s, '_tipo': 'servicio'},
      for (final p in _productos)
        if (calza(p)) {...p, '_tipo': 'producto'},
    ]..sort((a, b) => _km(a).compareTo(_km(b)));
    return out.take(6).toList();
  }

  bool get _hayResultados =>
      _query.length >= 2 &&
      (_lugares.isNotEmpty || _resultadosOkventa.isNotEmpty);

  void _irAResultado(Map<String, dynamic> m) {
    FocusScope.of(context).unfocus();
    _searchCtrl.clear();
    final esServicio = m['_tipo'] == 'servicio';
    final item = Map<String, dynamic>.from(m)..remove('_tipo');
    final original = (esServicio ? _servicios : _productos)
        .firstWhere((x) => x['id'] == item['id'], orElse: () => item);
    setState(() {
      _query = '';
      _lugares = [];
      _marcado = null;
      if (esServicio) {
        _verServicios = true;
        _selProducto = null;
        _selServicio = original;
      } else {
        _verProductos = true;
        _selServicio = null;
        _selProducto = original;
      }
    });
    _mover(
        LatLng((item['lat'] as num).toDouble(),
            (item['lng'] as num).toDouble()),
        16);
  }

  Widget _tituloSeccion(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Text(t,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: colors.grayMid)),
      );

  Widget _filaResultado({
    required Widget icono,
    required String titulo,
    String? detalle,
    String? derecha,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
        child: Row(children: [
          SizedBox(width: 30, child: Center(child: icono)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary)),
                if (detalle != null && detalle.isNotEmpty)
                  Text(detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: colors.grayMid)),
              ],
            ),
          ),
          if (derecha != null && derecha.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(derecha,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary)),
          ],
        ]),
      ),
    );
  }

  Widget _listaResultados() {
    final ok = _resultadosOkventa;
    final apple = _lugares.take(5).toList();
    return ConstrainedBox(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5),
      child: Material(
        color: colors.surface,
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 6),
          children: [
            if (ok.isNotEmpty) ...[
              _tituloSeccion('En OkVenta'),
              for (final m in ok)
                _filaResultado(
                  icono: m['_tipo'] == 'servicio'
                      ? Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: colors.carbon, shape: BoxShape.circle),
                          child: const Icon(Icons.handyman_rounded,
                              size: 15, color: Colors.white),
                        )
                      : Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7)),
                          child: Icon(Icons.shopping_cart_outlined,
                              size: 15, color: colors.primary),
                        ),
                  titulo: (m['titulo'] ?? '').toString(),
                  detalle: m['_tipo'] == 'servicio'
                      ? [
                          'Servicio',
                          if (((m['rating'] as num?) ?? 0) > 0)
                            '★ ${((m['rating'] as num).toDouble()).toStringAsFixed(1)}',
                          (m['categoria'] ?? '').toString(),
                        ].where((x) => x.isNotEmpty).join(' · ')
                      : formatPrecio(m['precio']),
                  derecha: _fmtKm(_km(m)),
                  onTap: () => _irAResultado(m),
                ),
            ],
            if (apple.isNotEmpty) ...[
              if (ok.isNotEmpty) Divider(height: 8, color: colors.divider),
              _tituloSeccion('Lugares y direcciones'),
              for (final l in apple)
                _filaResultado(
                  icono: const Icon(Icons.storefront_rounded,
                      size: 20, color: Color(0xFF0A84FF)),
                  titulo: l.nombre,
                  detalle: l.direccion != l.nombre ? l.direccion : null,
                  onTap: () => _irALugar(l),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── "¿Cómo llegar aquí?" ───────────────────────────────────────────────

  Future<void> _cargarPinesFijos() async {
    try {
      _pinOkventin ??= (await rootBundle
              .load('assets/images/okventin_pin_mapa.png'))
          .buffer
          .asUint8List();
      _pinLugar ??= await PinesApple.gota(
          clave: 'lugar_apple',
          color: const Color(0xFF0A84FF),
          icono: Icons.storefront_rounded);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _marcar(am.LatLng p) {
    FocusScope.of(context).unfocus();
    setState(() {
      _marcado = LatLng(p.latitude, p.longitude);
      _marcadoDir = null;
      _selProducto = null;
      _selServicio = null;
    });
    AppleMapKit.direccion(p.latitude, p.longitude).then((d) {
      if (!mounted || _marcado == null) return;
      setState(() => _marcadoDir = d);
      _mostrarBurbuja();
    });
    _mostrarBurbuja();
  }

  void _mostrarBurbuja() {
    Future.delayed(const Duration(milliseconds: 350), () {
      _appleCtrl?.showMarkerInfoWindow(am.AnnotationId('marcado'));
    });
  }

  void _rutaAlMarcado() {
    final m = _marcado;
    if (m == null) return;
    _rutaA({
      'id': 'marcado',
      'titulo': _marcadoDir ?? 'Punto marcado',
      'lat': m.latitude,
      'lng': m.longitude,
      '_exacto': true,
    });
  }

  // ── Rutas ──────────────────────────────────────────────────────────────

  /// Calcula la ruta en auto y a pie (en paralelo) y la dibuja.
  Future<void> _rutaA(Map<String, dynamic> item) async {
    final yo = _yo;
    if (yo == null) {
      _aviso('Activa tu ubicación para calcular la ruta');
      return;
    }
    final (la, ln) = _puntoAprox(item);
    setState(() {
      _calculandoRuta = true;
      _selProducto = null;
      _selServicio = null;
      _rutaItem = item;
    });
    final rs = await Future.wait([
      AppleMapKit.ruta(
          desdeLat: yo.lat, desdeLng: yo.lng, hastaLat: la, hastaLng: ln),
      AppleMapKit.ruta(
          desdeLat: yo.lat,
          desdeLng: yo.lng,
          hastaLat: la,
          hastaLng: ln,
          aPie: true),
    ]);
    if (!mounted) return;
    setState(() {
      _calculandoRuta = false;
      _rutaAuto = rs[0];
      _rutaPie = rs[1];
      // Si no hay ruta en auto (p. ej. muy cerca), mostrar la de a pie.
      if (_rutaAuto == null && _rutaPie != null) _aPie = true;
    });
    final r = _ruta;
    if (r == null) {
      _rutaItem = null;
      _aviso('No se pudo calcular la ruta');
      return;
    }
    _encajarApple([for (final (a, b) in r.puntos) LatLng(a, b)], 70);
  }

  void _cerrarRuta() {
    _terminarNavegacion();
    setState(() {
      _rutaAuto = null;
      _rutaPie = null;
      _rutaItem = null;
      _marcado = null;
    });
  }

  // ── Navegación dentro de la app ("Ir") ─────────────────────────────────

  Future<void> _ir() async {
    final yo = _yo;
    if (_rutaItem == null || yo == null) return;
    _posNav?.cancel();
    _cronometro?.cancel();
    setState(() {
      _navegando = true;
      _llegaste = false;
      _inicioNav = DateTime.now();
      _transcurrido = Duration.zero;
      _origenRutaNav = LatLng(yo.lat, yo.lng);
    });
    _conApple((c) => c.animateCamera(
        am.CameraUpdate.newLatLngZoom(am.LatLng(yo.lat, yo.lng), 17)));
    // Cronómetro: cuenta hacia arriba desde que tocas "Ir".
    _cronometro = Timer.periodic(const Duration(seconds: 1), (_) {
      final i = _inicioNav;
      if (!mounted || i == null || _llegaste) return;
      setState(() => _transcurrido = DateTime.now().difference(i));
    });
    // Tu posición se actualiza mientras te mueves.
    try {
      _posNav = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 8,
        ),
      ).listen(_alMoverme);
    } catch (_) {}
  }

  Future<void> _alMoverme(Position pos) async {
    if (!mounted || !_navegando) return;
    final aqui = LatLng(pos.latitude, pos.longitude);
    setState(() => _yo = Coordenadas(pos.latitude, pos.longitude));
    final item = _rutaItem;
    if (item == null) return;
    final (la, ln) = _puntoAprox(item);
    // ¿Llegaste? (a menos de 35 m del destino)
    if (_dist(pos.latitude, pos.longitude, la, ln) * 1000 < 35) {
      _posNav?.cancel();
      setState(() => _llegaste = true);
      return;
    }
    // Recalcular la ruta cada ~50 m recorridos.
    final o = _origenRutaNav;
    if (o != null &&
        _dist(o.latitude, o.longitude, aqui.latitude, aqui.longitude) * 1000 <
            50) {
      return;
    }
    _origenRutaNav = aqui;
    final r = await AppleMapKit.ruta(
        desdeLat: aqui.latitude,
        desdeLng: aqui.longitude,
        hastaLat: la,
        hastaLng: ln,
        aPie: _aPie);
    if (!mounted || r == null || !_navegando) return;
    setState(() {
      if (_aPie) {
        _rutaPie = r;
      } else {
        _rutaAuto = r;
      }
    });
  }

  void _terminarNavegacion() {
    _posNav?.cancel();
    _posNav = null;
    _cronometro?.cancel();
    _cronometro = null;
    if (_navegando) {
      setState(() {
        _navegando = false;
        _llegaste = false;
      });
    }
  }

  static String _fmtCrono(Duration d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return h > 0 ? '$h:${dos(m)}:${dos(s)}' : '${dos(m)}:${dos(s)}';
  }

  Widget _barraRuta() {
    final r = _ruta!;
    const azul = Color(0xFF0A84FF);

    // ── Navegando: cronómetro + lo que falta ──
    if (_navegando) {
      return Material(
        color: colors.surface,
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(children: [
            Icon(
                _llegaste
                    ? Icons.flag_rounded
                    : (_aPie ? Icons.directions_walk : Icons.directions_car),
                size: 26,
                color: _llegaste ? Colors.green : azul),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_fmtCrono(_transcurrido),
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [ui.FontFeature.tabularFigures()],
                          color: colors.textPrimary)),
                  Text(
                      _llegaste
                          ? '¡Llegaste!'
                          : 'Faltan ${r.distancia} · aprox. ${r.tiempo}',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _llegaste
                              ? Colors.green
                              : colors.textSecondary)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _llegaste ? _cerrarRuta : _terminarNavegacion,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(_llegaste ? 'Cerrar' : 'Terminar'),
            ),
          ]),
        ),
      );
    }

    // ── Antes de salir: tiempo en auto y a pie ──
    Widget modo(IconData i, RutaApple? ruta, bool aPie) {
      final sel = _aPie == aPie;
      final hay = ruta != null;
      return Expanded(
        child: GestureDetector(
          onTap: !hay || sel ? null : () => setState(() => _aPie = aPie),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? azul : colors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(i, size: 18, color: sel ? Colors.white : colors.textPrimary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(hay ? ruta.tiempo : '—',
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: sel ? Colors.white : colors.textPrimary)),
              ),
            ]),
          ),
        ),
      );
    }

    return Material(
      color: colors.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                    _calculandoRuta
                        ? 'Calculando ruta…'
                        : '${r.distancia} · ${(_rutaItem?['titulo'] ?? '').toString()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 20, color: colors.grayMid),
                onPressed: _cerrarRuta,
              ),
            ]),
            Row(children: [
              modo(Icons.directions_car, _rutaAuto, false),
              const SizedBox(width: 6),
              modo(Icons.directions_walk, _rutaPie, true),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _calculandoRuta ? null : _ir,
                icon: const Icon(Icons.navigation_rounded, size: 17),
                label: const Text('Ir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Vista de calle ─────────────────────────────────────────────────────

  Future<void> _verCalle(Map item) async {
    final (la, ln) = _puntoAprox(item);
    final ok = await AppleMapKit.verCalle(la, ln);
    if (!ok && mounted) {
      _aviso('Apple no tiene vista de calle en este lugar');
    }
  }

  /// Botón cuadrado con ícono para la ficha (ruta / vista de calle).
  Widget _iconoFicha(IconData icono, String ayuda, VoidCallback onTap) {
    return Tooltip(
      message: ayuda,
      child: SizedBox(
        width: 42,
        height: 38,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: colors.textPrimary,
            side: BorderSide(color: colors.divider),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Icon(icono, size: 19),
        ),
      ),
    );
  }

  // ── Opciones del mapa ──────────────────────────────────────────────────

  void _opcionesMapa() {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setHoja) {
        void cambiar(VoidCallback f) {
          f();
          setHoja(() {});
          setState(() {});
          AppleMapKit.guardarOpciones();
          AppleMapKit.aplicarEstilo();
        }

        Widget opcion(String t, bool sel, VoidCallback onTap) => Expanded(
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? colors.primary : colors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(t,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : colors.textPrimary)),
                ),
              ),
            );

        Widget titulo(String t) => Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Text(t,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
            );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: colors.divider,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                titulo('Tipo de mapa'),
                Row(children: [
                  for (final (i, t) in const [
                    (0, 'Normal'),
                    (1, 'Satélite'),
                    (2, 'Híbrido')
                  ])
                    opcion(t, AppleMapKit.tipo == i,
                        () => cambiar(() => AppleMapKit.tipo = i)),
                ]),
                titulo('Lugares de Apple (comercios, restaurantes…)'),
                Row(children: [
                  for (final (v, t) in const [
                    ('todos', 'Todos'),
                    ('utiles', 'Solo útiles'),
                    ('ninguno', 'Ninguno')
                  ])
                    opcion(t, AppleMapKit.lugares == v,
                        () => cambiar(() => AppleMapKit.lugares = v)),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Text(
                      '"Solo útiles": metro y buses, estacionamientos, '
                      'bencineras, farmacias, hospitales, bancos y cajeros.',
                      style: TextStyle(fontSize: 11.5, color: colors.grayMid)),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text('Tráfico en vivo',
                      style:
                          TextStyle(fontSize: 14, color: colors.textPrimary)),
                  value: AppleMapKit.trafico,
                  activeColor: colors.primary,
                  onChanged: (v) => cambiar(() => AppleMapKit.trafico = v),
                ),
              ],
            ),
          ),
        );
      }),
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
      child: Icon(Icons.shopping_cart_outlined, size: 15, color: colors.primary),
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
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Qué servicio es: el título en miniatura sobre el pin.
          Container(
            constraints: const BoxConstraints(maxWidth: 86),
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: (sel ? colors.primary : colors.carbon)
                  .withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text((s['titulo'] ?? 'Servicio').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    height: 1.15,
                    fontWeight: FontWeight.w700)),
          ),
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
                  Icons.shopping_cart_outlined),
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
            if (_apple) ...[
              _iconoFicha(Icons.streetview_rounded, 'Ver la calle',
                  () => _verCalle(p)),
              const SizedBox(width: 8),
            ],
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
    // Sin foto propia: Okventín de oficio.
    final foto = OkventinServicio.foto(s) ?? '';
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
            if (_apple && !esMio) ...[
              _iconoFicha(Icons.streetview_rounded, 'Ver la calle',
                  () => _verCalle(s)),
              const SizedBox(width: 8),
              _iconoFicha(Icons.directions_outlined, 'Cómo llegar',
                  () => _rutaA(s)),
              const SizedBox(width: 8),
            ],
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
