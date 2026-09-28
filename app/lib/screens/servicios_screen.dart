import 'dart:async';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/theme_service.dart';
import '../services/ubicacion_service.dart';
import '../services/vista_servicios_service.dart';
import '../theme/app_theme.dart';
import 'agregar_servicio_screen.dart';
import 'delivery_proximamente_screen.dart';
import 'delivery_registro_screen.dart';
import 'encontrar_screen.dart';
import 'okdelivery_pendientes_screen.dart';
import 'servicio_detalle_screen.dart';
import '../widgets/banner_publicidad.dart';
import '../widgets/barra_filtros.dart';
import '../widgets/insignia.dart';
import '../utils/regiones_chile.dart';
import '../widgets/net_image.dart';
class ServiciosScreen extends StatefulWidget {
  /// Texto con el que abrir el buscador ya escrito.
  ///
  /// Lo usa el detalle de un producto que requiere instalación: el comprador
  /// llega buscando "aire acondicionado" sin tener que escribirlo.
  final String? busquedaInicial;

  const ServiciosScreen({super.key, this.busquedaInicial});

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
          SnackBar(
            content: Text('Debes iniciar sesión para publicar'),
            backgroundColor: colors.primary,
          ),
        );
      }
      return;
    }
    // Tab 2 = Delivery → registro en pausa (ver okDeliveryDisponible)
    if (_tabController.index == 2) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DeliveryProximamenteScreen()),
      );
      _cargar();
      return;
    }
    // Pasar el tipo según el tab activo (0=Ofrezco, 1=Busco). El mapa de
    // servicios se mudó a Encontrar, junto con el de productos.
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
      backgroundColor: colors.background,
      // NestedScrollView y no un Column: es lo que permite que el encabezado
      // (título, publicidad, frase y pestañas) se vaya hacia arriba con el
      // mismo gesto que desplaza la lista, igual que el home del marketplace.
      // Con un Column el encabezado se quedaría fijo ocupando pantalla.
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [
                SliverToBoxAdapter(child: _cabecera()),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _ListaServicios(
                    servicios: _ofrezco,
                    tipo: 'ofrezco',
                    onRefresh: _cargar,
                    onPublicar: _irAAgregar,
                  ),
                  _ListaServicios(
                    servicios: _busco,
                    tipo: 'busco',
                    onRefresh: _cargar,
                    onPublicar: _irAAgregar,
                  ),
                  _DeliveryTab(
                    delivery: _delivery,
                    miUserId: _miUserId,
                    onRefresh: _cargar,
                    onRegistrarme: _irAAgregar,
                  ),
                ],
              ),
            ),
    );
  }

  /// Título, publicidad, frase y pestañas: todo en un bloque que se va con
  /// el scroll. La publicidad va entre el título y la frase, en el mismo
  /// sitio que ocupa en el home del marketplace.
  ///
  /// Va en tres piezas y no en un solo Container con padding porque el
  /// banner trae sus propios márgenes —los del home— y encerrarlo en un
  /// bloque con 16 de padding lo dejaría más angosto que allá.
  Widget _cabecera() {
    return Container(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Servicios',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                // El mapa de servicios vive ahora en Encontrar, junto con
                // el de productos; este botón lleva directo, con la capa de
                // servicios encendida.
                IconButton(
                  tooltip: 'Ver en el mapa',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const EncontrarScreen(soloServicios: true)),
                  ),
                  icon: Icon(Icons.map_outlined, color: colors.textPrimary),
                ),
                // Okventin servicios: solo en modo oscuro, mismo tamaño
                // agrandado que en el home (57).
                ValueListenableBuilder<bool>(
                  valueListenable: ThemeService.isDarkNotifier,
                  builder: (_, isDark, __) {
                    if (!isDark) return const SizedBox.shrink();
                    return Image.asset('assets/images/okventin_servicios.png',
                        width: 57, height: 57);
                  },
                ),
              ],
            ),
          ),

          const BannerPublicidad(avisos: avisosServicios),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encuentra o publica servicios profesionales',
                  style: TextStyle(fontSize: 13, color: colors.grayMid),
                ),
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabController,
                  labelColor: colors.primary,
                  unselectedLabelColor: colors.grayMid,
                  indicatorColor: colors.primary,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Ofrezco'),
                    Tab(text: 'Busco'),
                    Tab(text: 'Delivery'),
                  ],
                ),
              ],
            ),
          ),
        ],
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
  if (hex == null || hex.isEmpty) return colors.primary;
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return colors.primary;
  }
}

// ── Lista de servicios ────────────────────────────────────────────────────────

class _ListaServicios extends StatefulWidget {
  final List<Map<String, dynamic>> servicios;
  final String tipo;
  final Future<void> Function() onRefresh;

  /// Publicar. Va fijo a la derecha de la fila de filtros, al alcance del
  /// pulgar.
  final VoidCallback onPublicar;

  /// Búsqueda con la que abrir la pestaña, si se llegó buscando algo.
  final String? busquedaInicial;

  const _ListaServicios({
    required this.servicios,
    required this.tipo,
    required this.onRefresh,
    required this.onPublicar,
    this.busquedaInicial,
  });

  @override
  State<_ListaServicios> createState() => _ListaServiciosState();
}

class _ListaServiciosState extends State<_ListaServicios> {
  /// Categorías puestas en el filtro (pueden ser varias). Se muestran en
  /// rojo en la fila de arriba y se quitan arrastrándolas fuera.
  final List<String> _categoriasSel = [];

  /// Qué panel está abierto bajo la fila de filtros.
  PanelFiltro _panel = PanelFiltro.ninguno;

  /// Filtro de búsqueda en modo "Por zona": filtra por región en vez de
  /// por distancia.
  bool _modoZona = false;
  final List<String> _regionesSel = [];

  static final List<OpcionCategoria> _opcionesCategorias = [
    for (final c in _kCategorias)
      OpcionCategoria(c, _kCategoriaIconos[c] ?? Icons.more_horiz_rounded),
  ];
  final _searchCtrl = TextEditingController();
  String _query = '';

  // La vista (lista/miniaturas) y el tamaño de la grilla viven en
  // VistaServicios, no en el State: son preferencias globales y persistidas,
  // así que al cambiarlas en "Ofrezco" la pestaña "Busco" se redibuja sola.

  /// Radio de búsqueda en km. Mismo control y mismo rango que en el home,
  /// para que filtrar por distancia se sienta igual en toda la app.
  double _radioKm = 50;

  /// El filtro empieza apagado: al entrar se ven todos los servicios y es
  /// el usuario quien decide acotar. Al revés escondería resultados sin
  /// que nadie lo haya pedido.
  bool _filtroActivo = false;

  /// Mi ubicación, para medir la distancia. Sin ella el filtro no aplica.
  Coordenadas? _miUbicacion;

  /// Mientras se pide el GPS por primera vez.
  bool _cargandoUbicacion = true;

  @override
  void initState() {
    super.initState();
    final inicial = widget.busquedaInicial?.trim() ?? '';
    if (inicial.isNotEmpty) {
      _searchCtrl.text = inicial;
      _query = inicial;
    }
    UbicacionService.obtener().then((c) {
      if (!mounted) return;
      setState(() {
        _miUbicacion = c;
        _cargandoUbicacion = false;
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtrados {
    var lista = widget.servicios;
    if (_categoriasSel.isNotEmpty) {
      lista = lista
          .where((s) => _categoriasSel.contains(s['categoria'] ?? 'Otros'))
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

    // Distancia desde mi ubicación. Los servicios sin dirección marcada se
    // conservan: filtrarlos escondería publicaciones válidas que solo no
    // indicaron dónde atienden.
    final yo = _miUbicacion;
    if (yo != null && _filtroActivo && !_modoZona) {
      lista = lista.where((s) {
        final lat = s['lat'], lng = s['lng'];
        if (lat == null || lng == null) return true;
        final km = UbicacionService.distanciaKm(
            yo, Coordenadas((lat as num).toDouble(), (lng as num).toDouble()));
        return km <= _radioKm;
      }).toList();
    }

    // Por zona: solo los servicios con ubicación en alguna región elegida.
    if (_modoZona && _regionesSel.isNotEmpty) {
      final elegidas = _regionesSel.toSet();
      lista = lista.where((s) {
        final r = RegionesChile.regionDeItem(s);
        return r != null && elegidas.contains(r);
      }).toList();
    }
    return lista;
  }

  /// Distancia, categorías y "+ Publicar". Es el mismo widget que usa
  /// OkMarket, no una copia: así las dos pantallas se ven idénticas por
  /// construcción.
  Widget _barraFiltros() {
    final sinGps = _miUbicacion == null && !_cargandoUbicacion;
    return BarraFiltros(
      radioKm: _radioKm,
      distanciaActiva: _filtroActivo,
      sinGps: sinGps,
      cargandoUbicacion: _cargandoUbicacion,
      onToggleDistancia: () => setState(() => _filtroActivo = !_filtroActivo),
      onRadioChanged: (v) => setState(() {
        _radioKm = v;
        // Mover la barra es pedir el filtro: obligar además a pulsar el
        // ícono haría que arrastrar no hiciera nada visible.
        _filtroActivo = true;
      }),
      categorias: _opcionesCategorias,
      seleccionadas: _categoriasSel,
      onAgregarCategoria: (c) => setState(() {
        if (!_categoriasSel.contains(c)) _categoriasSel.add(c);
      }),
      onQuitarCategoria: (c) => setState(() => _categoriasSel.remove(c)),
      modoZona: _modoZona,
      regiones: _regionesSel,
      onModoZona: (z) => setState(() => _modoZona = z),
      onAgregarRegion: (r) => setState(() {
        if (!_regionesSel.contains(r)) _regionesSel.add(r);
      }),
      onQuitarRegion: (r) => setState(() => _regionesSel.remove(r)),
      panel: _panel,
      onPanel: (p) => setState(() => _panel = p),
      onPublicar: widget.onPublicar,
      etiquetaPublicar: widget.tipo == 'busco' ? 'Buscar' : 'Publicar',
    );
  }

  void _mostrarControlTamano() {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
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
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Cómo ver las publicaciones',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const SizedBox(height: 4),
              Text('Se aplica a todas las vistas de servicios',
                  style: TextStyle(fontSize: 12, color: colors.grayMid)),
              const SizedBox(height: 12),
              ValueListenableBuilder<bool>(
                valueListenable: VistaServicios.comoListaNotifier,
                builder: (_, comoLista, __) => Row(
                  children: [
                    Expanded(
                      child: _opcionVista(
                        icono: Icons.view_agenda_outlined,
                        titulo: 'Como lista',
                        seleccionado: comoLista,
                        onTap: () => VistaServicios.setComoLista(true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _opcionVista(
                        icono: Icons.grid_view_rounded,
                        titulo: 'Como miniaturas',
                        seleccionado: !comoLista,
                        onTap: () => VistaServicios.setComoLista(false),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tamaño: solo tiene sentido en la vista de miniaturas ─────
              ValueListenableBuilder<bool>(
                valueListenable: VistaServicios.comoListaNotifier,
                builder: (_, comoLista, __) {
                  if (comoLista) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text('Tamaño de las miniaturas',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Achica para ver más servicios por pantalla',
                          style:
                              TextStyle(fontSize: 12, color: colors.grayMid)),
                      ValueListenableBuilder<int>(
                        valueListenable: VistaServicios.columnasNotifier,
                        builder: (_, columnas, __) => Row(
                          children: [
                            Icon(Icons.grid_view_rounded,
                                size: 16, color: colors.grayMid),
                            Expanded(
                              child: Slider(
                                value: columnas.toDouble(),
                                min: 2,
                                max: 3,
                                divisions: 1,
                                activeColor: colors.primary,
                                onChanged: (v) =>
                                    VistaServicios.setColumnas(v.round()),
                              ),
                            ),
                            Icon(Icons.crop_square_rounded,
                                size: 22, color: colors.grayMid),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),

              // ── Color de fondo: solo en modo diurno ──────────────────────
              // En nocturno el fondo es negro y el control no haría nada.
              ValueListenableBuilder<bool>(
                valueListenable: ThemeService.isDarkNotifier,
                builder: (_, isDark, __) {
                  if (isDark) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text('Color de fondo',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Oscurece el gris del fondo de la app',
                          style:
                              TextStyle(fontSize: 12, color: colors.grayMid)),
                      ValueListenableBuilder<double>(
                        valueListenable: ThemeService.bgTintNotifier,
                        builder: (_, tint, __) => Row(
                          children: [
                            Icon(Icons.format_color_reset_rounded,
                                size: 16, color: colors.grayMid),
                            Expanded(
                              child: Slider(
                                value: tint,
                                min: 0,
                                max: 1,
                                activeColor: colors.primary,
                                onChanged: (v) => ThemeService.setBgTint(v),
                              ),
                            ),
                            Icon(Icons.format_color_fill_rounded,
                                size: 22, color: colors.primary),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Una de las dos opciones de vista ("Como lista" / "Como miniaturas").
  Widget _opcionVista({
    required IconData icono,
    required String titulo,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: seleccionado
              ? colors.primary.withOpacity(0.08)
              : colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? colors.primary : colors.divider,
            width: seleccionado ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono,
                size: 22,
                color: seleccionado ? colors.primary : colors.grayMid),
            const SizedBox(height: 6),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: seleccionado ? colors.primary : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;

    // CustomScrollView y no Column: es lo que permite que el banner se vaya
    // con el scroll mientras el buscador queda clavado arriba, igual que en
    // el home. Con un Column el banner ocuparía pantalla siempre.
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: colors.primary,
      child: CustomScrollView(
        // Que la lista pueda "tirarse" aunque quepa entera: sin esto el
        // gesto de refrescar no funciona cuando hay pocos servicios.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── Buscador + categorías + distancia (anclados) ────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _EncabezadoServiciosDelegate(
              height: _kAlturaBuscador +
                  BarraFiltros.alto(_panel, modoZona: _modoZona) +
                  _kAlturaDivisor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buscadorYVista(),
                  _barraFiltros(),
                  Divider(height: 0.5, color: colors.divider),
                ],
              ),
            ),
          ),

          if (filtrados.isEmpty)
            // Altura fija y no SliverFillRemaining: dentro de un
            // NestedScrollView ese sliver recibe restricciones infinitas y
            // revienta el layout.
            SliverToBoxAdapter(
              child: SizedBox(height: 320, child: _buildVacio()),
            )
          else
            _buildLista(filtrados),
        ],
      ),
    );
  }

  // ── Piezas del encabezado ─────────────────────────────────────────────

  /// Buscador + botón de "cómo ver". Queda anclado arriba al hacer scroll.
  Widget _buscadorYVista() {
    return Container(
        // Blanco, igual que el encabezado de arriba: antes esta franja era
        // gris y el resultado era blanco → gris → blanco → gris en cuatro
        // bandas seguidas. Ahora todo el encabezado es un solo bloque
        // blanco y el único corte contra el gris es el Divider de abajo.
        color: colors.surface,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(
          children: [
            Expanded(
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
                    hintText: widget.tipo == 'ofrezco'
                        ? 'Buscar servicios...'
                        : 'Buscar solicitudes...',
                    hintStyle: TextStyle(color: colors.grayMid, fontSize: 13),
                    prefixIcon: Icon(Icons.search, size: 18, color: colors.grayMid),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            child: Icon(Icons.close, size: 16, color: colors.grayMid),
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
                  color: colors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.divider),
                ),
                child: Icon(Icons.photo_size_select_large_outlined,
                    size: 17, color: colors.grayMid),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildVacio() {
    final sinResultados = _categoriasSel.isNotEmpty ||
        _query.isNotEmpty ||
        (_modoZona && _regionesSel.isNotEmpty);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: ThemeService.isDarkNotifier,
              builder: (_, isDark, __) {
                if (isDark) {
                  return Image.asset('assets/images/okventin_servicios.png',
                      height: 57);
                }
                return Icon(Icons.handyman_outlined,
                    size: 64, color: colors.grayMid.withOpacity(0.4));
              },
            ),
            const SizedBox(height: 16),
            Text(
              sinResultados
                  ? 'Sin resultados'
                  : widget.tipo == 'ofrezco'
                      ? 'Aún no hay servicios publicados'
                      : 'Aún no hay solicitudes de servicio',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary),
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
                  TextStyle(fontSize: 13, color: colors.grayMid),
            ),
          ],
        ),
      ),
    );
  }

  // Aire al final para que la última tarjeta no quede pegada al menú.
  // Antes eran 88 porque el botón flotante tapaba ese trozo; ya no existe,
  // así que basta con un margen normal.
  static const _kPaddingInferior = 20.0;

  /// La lista, como sliver: va dentro del mismo scroll que el banner, que
  /// es lo que hace que el banner se vaya al desplazarse. Una ListView
  /// aparte tendría su propio scroll y el banner quedaría fijo.
  Widget _buildLista(List<Map<String, dynamic>> servicios) {
    // Escucha las dos preferencias globales, así el cambio hecho desde el
    // panel se refleja al instante en esta pestaña y en la otra.
    return ValueListenableBuilder<bool>(
      valueListenable: VistaServicios.comoListaNotifier,
      builder: (_, comoLista, __) {
        if (comoLista) {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, _kPaddingInferior),
            sliver: SliverList.separated(
              itemCount: servicios.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _TarjetaServicio(servicio: servicios[i]),
            ),
          );
        }

        return ValueListenableBuilder<int>(
          valueListenable: VistaServicios.columnasNotifier,
          builder: (_, columnas, __) => SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, _kPaddingInferior),
            sliver: SliverGrid.builder(
              itemCount: servicios.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnas,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (_, i) =>
                  _TarjetaServicioCompacta(servicio: servicios[i]),
            ),
          ),
        );
      },
    );
  }
}

/// Altos del encabezado anclado: buscador + fila de filtros (su alto
/// depende del panel abierto, ver BarraFiltros.alto) + el divisor.
/// SliverPersistentHeader necesita saber cuánto mide antes de dibujarlo; si
/// se cambia el alto de alguna fila hay que actualizarlo aquí.
const double _kAlturaBuscador = 56;
const double _kAlturaDivisor = 0.5;

/// El encabezado que queda clavado arriba mientras el banner se va.
class _EncabezadoServiciosDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _EncabezadoServiciosDelegate(
      {required this.child, required this.height});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        // La sombra aparece solo cuando hay contenido pasando por debajo:
        // así se nota que el encabezado está flotando y no pegado.
        boxShadow: overlaps
            ? [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ]
            : const [],
      ),
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(_EncabezadoServiciosDelegate old) => true;
}

/// El botón de publicar, como pastilla.
///
/// Antes era un botón flotante grande sobre la lista: se comía una esquina
/// de la pantalla y tapaba la última tarjeta. Como pastilla usa la misma
/// forma que las categorías —el usuario ya sabe que eso se toca— y va junto
/// a la barra de distancia, donde queda a la vista sin estorbar.
class _PastillaPublicar extends StatelessWidget {
  final bool esBusco;
  final VoidCallback onTap;

  /// Texto propio. Sin esto, la pestaña Delivery diría "Publicar", que no es
  /// lo que hace ese botón.
  final String? etiqueta;

  const _PastillaPublicar(
      {required this.esBusco, required this.onTap, this.etiqueta});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.primarySuave,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 15, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              etiqueta ?? (esBusco ? 'Buscar' : 'Publicar'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
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
    final tipoColor = tipo == 'ofrezco' ? colors.primary : colors.warning;
    final prefix    = tipo == 'ofrezco' ? 'Ofrezco' : 'Busco';

    // El borde tiene que ser UNIFORME: Flutter ignora el borderRadius cuando
    // los lados difieren y pinta esquinas rectas, que es lo que hacía que la
    // franja roja se saliera de la tarjeta y chocara con la esquina redondeada
    // de la foto. La franja va como hijo recortado por el clipBehavior.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Franja de color según el tipo (ofrezco / busco).
            Container(width: 4, color: tipoColor),

            // Imagen del servicio o avatar del usuario. Va centrada: con
            // `stretch` la fila le impondría la altura completa de la tarjeta
            // y la deformaría.
            Center(
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
                        backgroundColor: colors.primary.withOpacity(0.15),
                        backgroundImage: fotoUrl.isNotEmpty
                            ? NetworkImage(
                                '${ApiService.baseUrl}$fotoUrl')
                            : null,
                        child: fotoUrl.isEmpty
                            ? Text(
                                nombre.isNotEmpty
                                    ? nombre[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                    fontSize: 8,
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700),
                              )
                            : null,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10, color: colors.grayMid)),
                      ),
                      if (verificado)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Insignia.certificado(tamano: 18),
                            SizedBox(width: 3),
                            Text('Certificado',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Insignia.dorado,
                                    fontWeight: FontWeight.w800)),
                          ],
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
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
                        Icon(Icons.location_on_outlined,
                            size: 10, color: colors.grayMid),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(comunas,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10, color: colors.grayMid)),
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
                          style: TextStyle(
                              fontSize: 9, color: colors.grayMid)),
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
                        foregroundColor: colors.primary,
                        side: BorderSide(
                            color: colors.primary, width: 1),
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
      color: colors.primary.withOpacity(0.12),
      child: Center(
        child: Text(
          nombre.isNotEmpty ? nombre[0].toUpperCase() : 'S',
          style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: colors.primary),
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
    final verificado = servicio['certificado_verificado'] == true ||
        servicio['certificado_verificado'] == 1;
    final tipoColor = tipo == 'ofrezco' ? colors.primary : colors.warning;
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
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.divider, width: 0.5),
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
                              color: colors.primary.withOpacity(0.12),
                              child: Center(
                                child: Text(
                                  nombre.isNotEmpty
                                      ? nombre[0].toUpperCase()
                                      : 'S',
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: colors.primary),
                                ),
                              ),
                            )),
                  if (verificado)
                    const Positioned(
                      right: 4, top: 4,
                      child: Insignia.certificado(tamano: 26),
                    ),
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
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary)),
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
                          style: TextStyle(
                              fontSize: 9, color: colors.grayMid)),
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

  /// Registrarse como delivery. Antes esto vivía en el botón flotante que
  /// compartían las cuatro pestañas; al quitarlo, esta pestaña se quedaba
  /// sin ninguna forma de entrar al registro.
  final VoidCallback onRegistrarme;

  const _DeliveryTab({
    required this.delivery,
    required this.miUserId,
    required this.onRefresh,
    required this.onRegistrarme,
  });

  @override
  State<_DeliveryTab> createState() => _DeliveryTabState();
}

class _DeliveryTabState extends State<_DeliveryTab> {
  /// Botón de registro, con la misma pastilla roja que usa "Publicar".
  Widget _botonRegistro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Align(
        alignment: Alignment.centerRight,
        child: _PastillaPublicar(
          esBusco: false,
          etiqueta: 'Registrarme',
          onTap: widget.onRegistrarme,
        ),
      ),
    );
  }

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
                  size: 64, color: colors.grayMid.withOpacity(0.4)),
              const SizedBox(height: 16),
              Text(
                'No hay deliveries registrados aún',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Muy pronto podrás registrarte como Delivery OkVenta',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.grayMid),
              ),
              const SizedBox(height: 20),
              _PastillaPublicar(
                esBusco: false,
                etiqueta: 'Registrarme',
                onTap: widget.onRegistrarme,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _botonRegistro(),
        Expanded(
          child: RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: colors.primary,
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
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: activo
                    ? Colors.green.withOpacity(0.35)
                    : colors.divider,
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
                    backgroundColor: colors.primary.withOpacity(0.15),
                    backgroundImage: fotoUrl.isNotEmpty
                        ? NetworkImage('${ApiService.baseUrl}$fotoUrl')
                        : null,
                    child: fotoUrl.isEmpty
                        ? Text(
                            nombre[0].toUpperCase(),
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: colors.primary),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: activo ? Colors.green : colors.grayMid,
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
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary)),
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
                              : colors.grayMid.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          activo ? '✅ Disponible' : '⏸ Inactivo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: activo ? Colors.green : colors.grayMid,
                          ),
                        ),
                      ),
                      if (comunas.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(comunas,
                            style: TextStyle(
                                fontSize: 11, color: colors.grayMid)),
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
                              activo ? colors.warning : Colors.green,
                          side: BorderSide(
                              color: activo
                                  ? colors.warning
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
          ),
        ),
      ],
    );
  }

  Widget _vehiculoIcon(String v) {
    final icons = {
      'bicicleta': Icons.directions_bike_rounded,
      'moto':      Icons.two_wheeler_rounded,
      'auto':      Icons.directions_car_rounded,
    };
    return Icon(icons[v] ?? Icons.delivery_dining_outlined,
        size: 20, color: colors.grayMid);
  }
}

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
