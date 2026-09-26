import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/format_utils.dart';

import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/barra_filtros.dart';
import 'carrito_screen.dart';
import 'producto_detalle_screen.dart';
import '../widgets/net_image.dart';

// ── Modelo de categoría (movido aquí desde home_screen) ───────────────────────
class Categoria {
  final String nombre;
  final IconData icono;
  final List<String> subcategorias;
  const Categoria({required this.nombre, required this.icono, required this.subcategorias});
}

// ─────────────────────────────────────────────────────────────────────────────

class MarketplaceScreen extends StatefulWidget {
  // Props de ubicación/radio — gestionados por HomeScreen
  final double? miLat;
  final double? miLng;
  final double radioKm;
  final bool filtroUbicacionActivo;
  final Widget? banner;

  // ── Barra de distancia ──────────────────────────────────────────────
  // Antes vivía abajo, pegada al menú, y se tocaba sin querer con la palma.
  // Ahora se dibuja aquí, debajo de las categorías, igual que en Servicios.
  // El estado sigue en HomeScreen porque lo comparten todas las pestañas:
  // esta pantalla solo dibuja y avisa hacia arriba.
  final bool sinGps;
  final bool cargandoUbicacion;
  final ValueChanged<double>? onRadioChanged;
  final ValueChanged<double>? onRadioSoltado;
  final VoidCallback? onToggleUbicacion;

  /// "+ Publicar" (arriba a la derecha). Hace lo que antes hacía el botón
  /// "Vender" de la barra inferior.
  final VoidCallback? onPublicar;

  const MarketplaceScreen({
    super.key,
    this.miLat,
    this.miLng,
    this.radioKm = 50.0,
    this.filtroUbicacionActivo = false,
    this.banner,
    this.sinGps = false,
    this.cargandoUbicacion = false,
    this.onRadioChanged,
    this.onRadioSoltado,
    this.onToggleUbicacion,
    this.onPublicar,
  });

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  // ── Categorías ────────────────────────────────────────────────────────────
  static const List<Categoria> _categorias = [
    Categoria(nombre: "Automotriz",   icono: Icons.directions_car_rounded,       subcategorias: ["Repuestos", "Autos", "Motos", "Camiones"]),
    Categoria(nombre: "Electrónica",  icono: Icons.devices_rounded,              subcategorias: ["Computación", "Celulares", "TV", "Cámaras"]),
    Categoria(nombre: "Hogar",        icono: Icons.weekend_rounded,              subcategorias: ["Muebles", "Decoración", "Electrodomésticos"]),
    Categoria(nombre: "Ropa",         icono: Icons.checkroom_outlined,           subcategorias: ["Hombre", "Mujer", "Niños", "Accesorios"]),
    Categoria(nombre: "Deportes",     icono: Icons.fitness_center_rounded,       subcategorias: ["Equipamiento", "Ropa Deportiva", "Bicicletas"]),
    Categoria(nombre: "Ocio",         icono: Icons.sports_soccer_rounded,        subcategorias: ["Juguetes", "Entretenimiento", "Música"]),
    Categoria(nombre: "Mascotas",     icono: Icons.pets_rounded,                 subcategorias: ["Alimentos", "Accesorios", "Servicios"]),
    Categoria(nombre: "Salud",        icono: Icons.health_and_safety_outlined,   subcategorias: ["Equipos Médicos", "Belleza", "Bienestar"]),
    Categoria(nombre: "Construcción", icono: Icons.construction_outlined,        subcategorias: ["Herramientas", "Materiales", "Equipos"]),
    Categoria(nombre: "Fotografía",   icono: Icons.camera_alt_outlined,          subcategorias: ["Cámaras", "Lentes", "Iluminación", "Trípodes"]),
    Categoria(nombre: "Educación",    icono: Icons.menu_book_outlined,           subcategorias: ["Libros", "Cursos", "Instrumentos"]),
    Categoria(nombre: "Negocios",     icono: Icons.business_center_outlined,     subcategorias: ["Equipos", "Mobiliario", "Tecnología"]),
    // "General" no tiene subcategorías propias — decir "Otros" bajo
    // "General" era redundante.
    Categoria(nombre: "General",      icono: Icons.category_rounded,             subcategorias: []),
  ];
  /// Categorías puestas en el filtro (pueden ser varias). Se muestran en
  /// rojo en la fila de arriba y se quitan arrastrándolas fuera.
  final List<String> _categoriasSel = [];

  /// La categoría, cuando hay exactamente una: es el único caso en que
  /// tienen sentido las subcategorías y el título con su nombre.
  String? get _categoriaUnica =>
      _categoriasSel.length == 1 ? _categoriasSel.first : null;
  String? _subcategoriaSeleccionada;

  /// Qué panel está abierto bajo la fila de filtros.
  PanelFiltro _panel = PanelFiltro.ninguno;

  static final List<OpcionCategoria> _opcionesCategorias = _categorias
      .map((c) => OpcionCategoria(c.nombre, c.icono))
      .toList();

  // ── Datos ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _todas = [];
  List<Map<String, dynamic>> _filtradas = [];
  bool _loading = true;
  bool _errorConexion = false;

  // ── Búsqueda y precio ─────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  double? _precioMin;

  /// 'nuevo', 'usado' o null (todos). Vive junto al precio porque se elige
  /// en el mismo panel de filtros.
  String? _condicionFiltro;

  /// Cómo se ordena la lista: 'recientes' (lo de siempre), 'precio_asc',
  /// 'precio_desc' o 'categoria'.
  String _orden = 'recientes';

  static const Map<String, String> _nombresOrden = {
    'recientes': 'Más recientes',
    'precio_asc': 'Precio: menor a mayor',
    'precio_desc': 'Precio: mayor a menor',
    'categoria': 'Por categoría',
  };
  double? _precioMax;
  bool _buscando = false;

  // ── Tamaño de tarjetas (columnas de la grilla, persistido) ───────────────
  static const _kColumnasPref = 'mkt_columnas';
  int _columnas = 2;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    cargarPublicaciones();
    _cargarColumnas();
  }

  Future<void> _cargarColumnas() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_kColumnasPref) ?? 2;
    if (mounted) setState(() => _columnas = v);
  }

  Future<void> _guardarColumnas(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kColumnasPref, v);
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
              Text('Tamaño de las publicaciones',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const SizedBox(height: 4),
              Text('Achica para ver más productos, agranda para verlos más grandes',
                  style: TextStyle(fontSize: 12, color: colors.grayMid)),
              Row(
                children: [
                  Icon(Icons.grid_view_rounded,
                      size: 16, color: colors.grayMid),
                  Expanded(
                    child: Slider(
                      value: _columnas.toDouble(),
                      min: 1,
                      max: 4,
                      divisions: 3,
                      activeColor: colors.primary,
                      onChanged: (v) {
                        setSheetState(() => _columnas = v.round());
                        setState(() => _columnas = v.round());
                        _guardarColumnas(v.round());
                      },
                    ),
                  ),
                  Icon(Icons.crop_square_rounded,
                      size: 22, color: colors.grayMid),
                ],
              ),

              // ── Color de fondo (solo modo claro) ────────────────────────
              const SizedBox(height: 12),
              Text('Color de fondo',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                'Oscurece el gris del fondo. Solo aplica al modo diurno.',
                style: TextStyle(fontSize: 12, color: colors.grayMid),
              ),
              ValueListenableBuilder<double>(
                valueListenable: ThemeService.bgTintNotifier,
                builder: (_, tint, __) {
                  return Row(
                    children: [
                      Icon(Icons.format_color_reset_rounded,
                          size: 16, color: colors.grayMid),
                      Expanded(
                        child: Slider(
                          value: tint,
                          min: 0,
                          max: 1,
                          activeColor: AppColors.primary,
                          onChanged: (v) => ThemeService.setBgTint(v),
                        ),
                      ),
                      Icon(Icons.format_color_fill_rounded,
                          size: 22, color: AppColors.primary),
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

  @override
  void didUpdateWidget(MarketplaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-filtra cuando el radio o la ubicación cambian desde HomeScreen
    if (oldWidget.radioKm != widget.radioKm ||
        oldWidget.filtroUbicacionActivo != widget.filtroUbicacionActivo ||
        oldWidget.miLat != widget.miLat ||
        oldWidget.miLng != widget.miLng) {
      setState(_aplicarFiltros);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Haversine (client-side) ───────────────────────────────────────────────

  double _distanciaKm(double lat1, double lng1, double lat2, double lng2) {
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

  // ── Carga (siempre todos, el filtro de categoría es client-side) ──────────

  Future<void> cargarPublicaciones() async {
    setState(() { _loading = true; _errorConexion = false; });
    try {
      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/publicaciones"),
      ).timeout(const Duration(seconds: 10));
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (!mounted) return;
      setState(() {
        _todas = List<Map<String, dynamic>>.from(data);
        _aplicarFiltros();
        _loading = false;
      });
    } catch (e) {
      debugPrint("ERROR MARKETPLACE: $e");
      if (!mounted) return;
      setState(() {
        _todas = [];
        _filtradas = [];
        _loading = false;
        _errorConexion = true;
      });
    }
  }

  // ── Filtros (client-side: texto + precio + categoría + radio) ─────────────

  void _aplicarFiltros() {
    var lista = List<Map<String, dynamic>>.from(_todas);

    // Categoría
    if (_categoriasSel.isNotEmpty) {
      final elegidas = _categoriasSel.map((c) => c.toLowerCase()).toSet();
      lista = lista.where((p) =>
        elegidas.contains((p['categoria'] ?? '').toString().toLowerCase())
      ).toList();
    }
    if (_categoriaUnica != null && _subcategoriaSeleccionada != null) {
      lista = lista.where((p) =>
        (p['subcategoria'] ?? '').toString().toLowerCase() ==
        _subcategoriaSeleccionada!.toLowerCase()
      ).toList();
    }

    // Texto
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      lista = lista.where((p) {
        final titulo = (p['titulo'] ?? '').toString().toLowerCase();
        final desc   = (p['descripcion'] ?? '').toString().toLowerCase();
        return titulo.contains(q) || desc.contains(q);
      }).toList();
    }

    // Precio
    if (_precioMin != null) lista = lista.where((p) => (p['precio'] as num? ?? 0) >= _precioMin!).toList();
    if (_precioMax != null) lista = lista.where((p) => (p['precio'] as num? ?? 0) <= _precioMax!).toList();

    // Condición. Se compara por el comienzo de la palabra y sin mayúsculas
    // porque no todas las publicaciones la guardan igual ("nuevo", "Nuevo",
    // "nuevo con etiqueta"). Las que no dicen nada quedan fuera mientras el
    // filtro esté puesto: no se puede afirmar que sean lo que se busca.
    if (_condicionFiltro != null) {
      lista = lista.where((p) {
        final c = (p['condicion'] ?? '').toString().trim().toLowerCase();
        return c.startsWith(_condicionFiltro!);
      }).toList();
    }

    // Radio — sin lat/lng → siempre visible | con lat/lng → filtrar por distancia
    if (_radioActivo) {
      lista = lista.where((p) {
        final lat = p['lat'];
        final lng = p['lng'];
        if (lat == null || lng == null) return true;
        return _distanciaKm(
          widget.miLat!, widget.miLng!,
          (lat as num).toDouble(), (lng as num).toDouble(),
        ) <= widget.radioKm;
      }).toList();
    }

    // ── Orden ───────────────────────────────────────────────────────────
    // Se ordena al final, sobre lo ya filtrado. La lista llega del servidor
    // de más nueva a más vieja, así que 'recientes' no toca nada: cualquier
    // otro orden rehace la lista sin perder ese criterio de desempate.
    switch (_orden) {
      case 'precio_asc':
        lista.sort((a, b) =>
            _precioDe(a).compareTo(_precioDe(b)));
        break;
      case 'precio_desc':
        lista.sort((a, b) =>
            _precioDe(b).compareTo(_precioDe(a)));
        break;
      case 'categoria':
        // Agrupadas alfabéticamente, y dentro de cada grupo se respeta el
        // orden de llegada (las más nuevas primero).
        lista.sort((a, b) => (a['categoria'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['categoria'] ?? '').toString().toLowerCase()));
        break;
    }

    _filtradas = lista;
  }

  /// El precio como número, tolerando que venga como texto o venga vacío.
  double _precioDe(Map<String, dynamic> p) {
    final v = p['precio'];
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? 0;
  }

  // ── Búsqueda en backend ───────────────────────────────────────────────────

  Future<void> _buscarEnBackend(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _aplicarFiltros(); _buscando = false; });
      return;
    }
    setState(() => _buscando = true);
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/buscar')
          .replace(queryParameters: {'q': query.trim()});
      final response = await http.get(uri);
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (!mounted) return;
      setState(() {
        _todas = List<Map<String, dynamic>>.from(data);
        _aplicarFiltros();
        _buscando = false;
      });
    } catch (e) {
      debugPrint("ERROR búsqueda: $e");
      if (mounted) setState(() => _buscando = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get _radioActivo => widget.filtroUbicacionActivo && widget.miLat != null && widget.miLng != null;
  bool get _tieneFiltroPrecio => _precioMin != null || _precioMax != null;

  /// Hay algún filtro del panel puesto (precio o condición). Pinta de rojo
  /// el botón de filtros y muestra la fila de chips.
  bool get _tieneFiltros =>
      _tieneFiltroPrecio || _condicionFiltro != null || _orden != 'recientes';

  String _formatRadio(double km) =>
      km < 10 ? "${km.toStringAsFixed(1)} km" : "${km.toStringAsFixed(0)} km";

  void _mostrarConteoProductos() {
    final msg = _radioActivo
        ? "${_filtradas.length} de ${_todas.length} productos en ${_formatRadio(widget.radioKm)}"
        : "${_filtradas.length} producto${_filtradas.length == 1 ? '' : 's'} disponible${_filtradas.length == 1 ? '' : 's'}";
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.white),
        const SizedBox(width: 8),
        Text(msg, style: const TextStyle(fontSize: 13)),
      ]),
      backgroundColor: colors.carbon,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ));
  }

  // ── Bottom sheet: filtro precio ───────────────────────────────────────────

  void _mostrarFiltrosPrecio() {
    final minCtrl = TextEditingController(text: _precioMin?.toStringAsFixed(0) ?? '');
    final maxCtrl = TextEditingController(text: _precioMax?.toStringAsFixed(0) ?? '');
    // Copia local: los chips cambian al tocarlos, pero la lista solo se
    // filtra al pulsar "Aplicar", igual que el precio.
    String? condicion = _condicionFiltro;
    String orden = _orden;
    // Categoría elegida desde el panel: solo se usa cuando el orden es
    // "Por categoría", que es donde tiene sentido acotar a una.
    String? categoria = _categoriaUnica;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      // StatefulBuilder: el botón de "ocultar teclado" necesita poder pedir
      // un rebuild propio del sheet (sin esto, el ícono no reflejaba bien
      // el foco al usar setState del builder externo).
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          // El teclado numérico tapaba por completo los campos: al usar
          // SingleChildScrollView + este padding igual a la altura del
          // teclado, el contenido queda siempre visible por encima de él.
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: colors.divider, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Filtros",
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                    // Botón para esconder el teclado y poder ver/tocar
                    // los botones de abajo (Limpiar / Aplicar).
                    TextButton.icon(
                      onPressed: () {
                        FocusScope.of(sheetCtx).unfocus();
                        setSheetState(() {});
                      },
                      icon: Icon(Icons.keyboard_hide_outlined, size: 18, color: colors.primary),
                      label: Text("Ocultar teclado",
                          style: TextStyle(color: colors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text("Ordenar por",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                const SizedBox(height: 8),
                for (final op in _nombresOrden.entries)
                  GestureDetector(
                    onTap: () => setSheetState(() => orden = op.key),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: orden == op.key
                            ? colors.primary.withValues(alpha: 0.08)
                            : colors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: orden == op.key ? colors.primary : colors.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            orden == op.key
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: orden == op.key ? colors.primary : colors.grayMid,
                          ),
                          const SizedBox(width: 10),
                          Text(op.value,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: orden == op.key
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: colors.textPrimary,
                              )),
                        ],
                      ),
                    ),
                  ),

                // Elegir UNA categoría. Aparece solo al ordenar por
                // categoría: es ahí donde la pregunta "¿cuál?" tiene sentido.
                if (orden == 'categoria') ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final c in <String?>[null, ..._categorias.map((e) => e.nombre)])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => setSheetState(() => categoria = c),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: categoria == c ? colors.primary : colors.background,
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(
                                      color: categoria == c ? colors.primary : colors.divider),
                                ),
                                child: Text(c ?? 'Todas',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: categoria == c
                                          ? colors.textOnPrimary
                                          : colors.textPrimary,
                                    )),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                Text("Estado",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                const SizedBox(height: 8),
                Row(children: [
                  for (final op in const [
                    [null, 'Todos'],
                    ['nuevo', 'Nuevo'],
                    ['usado', 'Usado'],
                  ]) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheetState(() => condicion = op[0]),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: condicion == op[0] ? colors.primary : colors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: condicion == op[0] ? colors.primary : colors.divider),
                          ),
                          child: Text(op[1]!,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: condicion == op[0] ? colors.textOnPrimary : colors.textPrimary,
                              )),
                        ),
                      ),
                    ),
                    if (op[0] != 'usado') const SizedBox(width: 8),
                  ],
                ]),
                const SizedBox(height: 18),
                Text("Precio",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textSecondary)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _campoFiltro(ctrl: minCtrl, hint: "Mínimo", prefix: "\$")),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text("—", style: TextStyle(color: colors.grayMid, fontSize: 18))),
                  Expanded(child: _campoFiltro(ctrl: maxCtrl, hint: "Máximo", prefix: "\$")),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        setState(() {
                          _precioMin = null;
                          _precioMax = null;
                          _condicionFiltro = null;
                          _orden = 'recientes';
                          cargarPublicaciones();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("Limpiar", style: TextStyle(color: colors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        setState(() {
                          _precioMin = double.tryParse(minCtrl.text.trim());
                          _precioMax = double.tryParse(maxCtrl.text.trim());
                          _condicionFiltro = condicion;
                          _orden = orden;
                          // La categoría del panel manda sobre la fila de
                          // pastillas de arriba: es la última que tocó.
                          if (orden == 'categoria') {
                            // Copia local: `categoria` la cambia el panel,
                            // así que Dart no puede asumir que sigue no nula.
                            final elegida = categoria;
                            _categoriasSel
                              ..clear()
                              ..addAll([if (elegida != null) elegida]);
                            _subcategoriaSeleccionada = null;
                          }
                          _aplicarFiltros();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("Aplicar", style: TextStyle(color: colors.textOnPrimary)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoFiltro({required TextEditingController ctrl, required String hint, String? prefix}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      // Se fija el color del texto explícitamente: sin esto, lo escrito no
      // se veía al abrir el teclado.
      style: TextStyle(color: colors.textPrimary, fontSize: 15),
      cursorColor: colors.primary,
      decoration: InputDecoration(
        hintText: hint, prefixText: prefix,
        prefixStyle: TextStyle(color: colors.textPrimary, fontSize: 15),
        hintStyle: TextStyle(color: colors.grayMid, fontSize: 14),
        filled: true, fillColor: colors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  // ── Categorías ────────────────────────────────────────────────────────────

  void _agregarCategoria(String c) => setState(() {
        if (!_categoriasSel.contains(c)) _categoriasSel.add(c);
        _subcategoriaSeleccionada = null;
        _aplicarFiltros();
      });

  void _quitarCategoria(String c) => setState(() {
        _categoriasSel.remove(c);
        _subcategoriaSeleccionada = null;
        _aplicarFiltros();
      });

  List<String> get _subcategoriasVisibles {
    final unica = _categoriaUnica;
    if (unica == null) return const [];
    final cat = _categorias.where((c) => c.nombre == unica);
    return cat.isNotEmpty ? cat.first.subcategorias : const [];
  }

  /// Subcategorías de la categoría puesta. Solo con UNA categoría: con
  /// varias, mezclar sus subcategorías en una fila no se entendería.
  Widget? _filaSubcategorias() {
    final subcats = _subcategoriasVisibles;
    if (subcats.isEmpty) return null;
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      itemCount: subcats.length,
      itemBuilder: (_, i) {
        final sub = subcats[i];
        final selected = _subcategoriaSeleccionada == sub;
        return GestureDetector(
          onTap: () => setState(() {
            _subcategoriaSeleccionada = selected ? null : sub;
            _aplicarFiltros();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? colors.carbon : colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? colors.carbon : colors.divider,
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(sub,
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : colors.textSecondary,
                  )),
            ),
          ),
        );
      },
    );
  }

  // ── Aspect ratio dinámico de la tarjeta (imagen cuadrada + texto fijo) ────
  // Evita que el bloque de texto se corte cuando hay más columnas (tarjetas
  // más angostas → la imagen cuadrada también se achica en alto, pero el
  // texto de abajo necesita ~118px sin importar el ancho).
  static const double _kAltoBloqueTexto = 132;

  double _aspectRatioTarjeta(BuildContext context) {
    final anchoDisponible = MediaQuery.of(context).size.width - 24; // padding lateral
    final anchoTarjeta =
        (anchoDisponible - (10 * (_columnas - 1))) / _columnas;
    // Si el teléfono tiene la letra agrandada (Ajustes → Pantalla → Tamaño
    // del texto), las mismas líneas ocupan más alto. Con un alto fijo, ahí
    // el texto se salía por abajo de la tarjeta; ahora el bloque crece en
    // la misma proporción que la letra.
    final escalaLetra =
        MediaQuery.textScalerOf(context).scale(10) / 10;
    final altoTarjeta =
        anchoTarjeta + _kAltoBloqueTexto * escalaLetra.clamp(1.0, 2.0);
    return anchoTarjeta / altoTarjeta;
  }

  // ── Card de producto ──────────────────────────────────────────────────────

  Widget _itemProducto(Map<String, dynamic> item) {
    final imagenUrl = item['imagen_url'] ?? "";
    final titulo    = item['titulo'] ?? "";
    final precio    = item['precio'] ?? 0;
    final vendedor  = item['nombre_vendedor'] ?? "Usuario invitado";
    final bool registrado = item['user_id'] != null;
    final categoria = item['categoria'];
    final condicion = (item['condicion'] as String?) ?? 'nuevo';
    final bool esNuevo = condicion == 'nuevo';

    double? distKm;
    if (_radioActivo && item['lat'] != null && item['lng'] != null) {
      distKm = _distanciaKm(
        widget.miLat!, widget.miLng!,
        (item['lat'] as num).toDouble(), (item['lng'] as num).toDouble(),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: item)),
      ).then((result) {
        if (result == true) {
          cargarPublicaciones(); // producto editado o eliminado → reload
        } else {
          setState(() {}); // solo refrescar estado local (favorito, etc.)
        }
      }),
      child: Container(
        // Último seguro: si por cualquier motivo el contenido no calzara,
        // se recorta en el borde redondeado en vez de pintarse encima de la
        // tarjeta vecina.
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: NetImage(
                    "${ApiService.baseUrl}$imagenUrl",
                    width: double.infinity,
                    fit: BoxFit.contain,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                  ),
                ),
                if (distKm != null)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.carbon.withValues(alpha: 0.80),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.near_me_rounded, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(_formatRadio(distKm),
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Una sola línea, siempre. Antes era un Wrap: con una
                  // categoría larga las etiquetas bajaban a una segunda
                  // línea, la tarjeta (que tiene alto fijo) se quedaba
                  // corta y el texto de abajo se salía de la cuadrícula.
                  Row(
                    children: [
                      // Condición: nuevo / usado
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (esNuevo ? colors.success : colors.warning)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(esNuevo ? 'Nuevo' : 'Usado',
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: esNuevo
                                    ? colors.success
                                    : colors.warning,
                                shadows: const [
                                  Shadow(
                                      color: Colors.black26,
                                      blurRadius: 1.5,
                                      offset: Offset(0, 0.4)),
                                ])),
                      ),
                      if (categoria != null && categoria.toString().isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(categoria.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: colors.primary,
                                    shadows: const [
                                      Shadow(
                                          color: Colors.black26,
                                          blurRadius: 1.5,
                                          offset: Offset(0, 0.4)),
                                    ])),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(titulo,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colors.textPrimary)),
                  const SizedBox(height: 6),
                  // FittedBox: si la tarjeta queda muy angosta (más columnas),
                  // el precio se achica para seguir viéndose completo en una
                  // sola línea en vez de cortarse.
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(formatPrecio(precio),
                          maxLines: 1,
                          style: TextStyle(fontSize: 17, color: colors.primary, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(registrado ? Icons.verified_user : Icons.person_outline,
                          size: 12, color: registrado ? colors.textPrimary : colors.grayMid),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(vendedor,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: registrado ? colors.textPrimary : colors.grayMid)),
                      ),
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

  // ── Chip de filtro ────────────────────────────────────────────────────────

  Widget _chipFiltro({required String label, required VoidCallback onClear}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(onTap: onClear, child: Icon(Icons.close, size: 14, color: colors.primary)),
        ],
      ),
    );
  }

  // ── Sticky header height (search + categories + optional chips) ──────────

  double get _stickyHeaderHeight {
    // buscador + fila de filtros (y el panel que esté abierto)
    double h = 60.0 +
        BarraFiltros.alto(_panel,
            conExtra: _subcategoriasVisibles.isNotEmpty);
    if (_tieneFiltros) h += 32.0;
    return h;
  }

  // ── Sticky header widget ──────────────────────────────────────────────────

  Widget _buildStickyHeader() {
    return Container(
      // Gris (igual que el fondo bajo las miniaturas de productos), para que
      // la barra resalte del blanco de arriba en vez de camuflarse.
      color: colors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search bar + tune button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      // Blanco para que resalte sobre el fondo gris del
                      // header (antes ambos eran blancos y se camuflaba).
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.divider),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1)),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) {
                        if (v.trim().isEmpty) setState(() => cargarPublicaciones());
                      },
                      onSubmitted: _buscarEnBackend,
                      decoration: InputDecoration(
                        hintText: "Buscar productos...",
                        hintStyle: TextStyle(color: colors.grayMid, fontSize: 13),
                        prefixIcon: _buscando
                            ? Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
                              )
                            : Icon(Icons.search, size: 18, color: colors.grayMid),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () { _searchCtrl.clear(); setState(() => cargarPublicaciones()); },
                                child: Icon(Icons.close, size: 16, color: colors.grayMid))
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _mostrarFiltrosPrecio,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _tieneFiltros ? colors.primary : colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _tieneFiltros ? colors.primary : colors.divider),
                    ),
                    child: Icon(Icons.tune, size: 18,
                        color: _tieneFiltros ? colors.textOnPrimary : colors.grayMid),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _mostrarControlTamano,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Icon(Icons.photo_size_select_large_outlined,
                        size: 17, color: colors.grayMid),
                  ),
                ),
              ],
            ),
          ),
          // Distancia, categorías y "+ Publicar": el mismo widget que usa
          // OkServicios, así las dos pantallas se comportan igual.
          BarraFiltros(
            fondo: colors.background,
            radioKm: widget.radioKm,
            distanciaActiva: widget.filtroUbicacionActivo,
            sinGps: widget.sinGps,
            cargandoUbicacion: widget.cargandoUbicacion,
            onRadioChanged: widget.onRadioChanged ?? (_) {},
            onRadioSoltado: widget.onRadioSoltado,
            onToggleDistancia: widget.onToggleUbicacion,
            categorias: _opcionesCategorias,
            seleccionadas: _categoriasSel,
            onAgregarCategoria: _agregarCategoria,
            onQuitarCategoria: _quitarCategoria,
            extraCategorias: _filaSubcategorias(),
            panel: _panel,
            onPanel: (p) => setState(() => _panel = p),
            onPublicar: widget.onPublicar,
          ),
          // Chips de los filtros puestos, cada uno con su X para quitarlo.
          if (_tieneFiltros)
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                children: [
                  if (_orden != 'recientes') ...[
                    _chipFiltro(
                      label: _nombresOrden[_orden] ?? _orden,
                      onClear: () => setState(() {
                        _orden = 'recientes';
                        _aplicarFiltros();
                      }),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (_condicionFiltro != null) ...[
                    _chipFiltro(
                      label: _condicionFiltro == 'nuevo' ? "Nuevo" : "Usado",
                      onClear: () => setState(() { _condicionFiltro = null; _aplicarFiltros(); }),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (_tieneFiltroPrecio)
                    _chipFiltro(
                      label: _precioMin != null && _precioMax != null
                          ? "${formatPrecio(_precioMin)} — ${formatPrecio(_precioMax)}"
                          : _precioMin != null
                              ? "Desde ${formatPrecio(_precioMin)}"
                              : "Hasta ${formatPrecio(_precioMax)}",
                      onClear: () => setState(() { _precioMin = null; _precioMax = null; cargarPublicaciones(); }),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(color: colors.primary),
      ));
    }

    final tituloSeccion = _categoriasSel.isEmpty
        ? "Okmarket"
        : _categoriaUnica != null && _subcategoriaSeleccionada != null
            ? "$_categoriaUnica · $_subcategoriaSeleccionada"
            : _categoriasSel.join(" · ");

    return CustomScrollView(
      slivers: [
        // ── Banner (se desvanece al hacer scroll) ────────────────────────────
        if (widget.banner != null)
          SliverToBoxAdapter(child: widget.banner),

        // ── Barra de búsqueda + categorías (anclada) ─────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _SearchHeaderDelegate(
            height: _stickyHeaderHeight,
            child: _buildStickyHeader(),
          ),
        ),

        // ── Título sección + ícono carrito ────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(tituloSeccion,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colors.textPrimary)),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CarritoScreen()),
                  ),
                  child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: CartService.cartNotifier,
                    builder: (_, cart, __) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: cart.isNotEmpty ? colors.primary.withValues(alpha: 0.10) : colors.background,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.shopping_bag_outlined, size: 18,
                              color: cart.isNotEmpty ? colors.primary : colors.grayMid),
                        ),
                        if (cart.isNotEmpty)
                          Positioned(
                            right: -2, top: -2,
                            child: Container(
                              width: 15, height: 15,
                              decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                              child: Center(child: Text("${cart.length}",
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700))),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),

        // ── Sin resultados / error ────────────────────────────────────────────
        if (_filtradas.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      _errorConexion
                          ? Icons.wifi_off_rounded
                          : _radioActivo
                              ? Icons.explore_off_rounded
                              : Icons.inventory_2_outlined,
                      size: 48,
                      color: _errorConexion ? colors.primary : colors.grayMid,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorConexion
                          ? "Sin conexión al servidor"
                          : _radioActivo
                              ? "Sin productos en ${_formatRadio(widget.radioKm)} de tu ubicación"
                              : _searchCtrl.text.isNotEmpty
                                  ? "Sin resultados para \"${_searchCtrl.text}\""
                                  : _categoriasSel.isNotEmpty
                                      ? "Sin productos en estas categorías"
                                      : "No hay productos disponibles",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _errorConexion ? colors.textPrimary : colors.grayMid,
                        fontSize: 14,
                        fontWeight: _errorConexion ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (_errorConexion) ...[
                      const SizedBox(height: 6),
                      Text(
                        "Verifica que el servidor esté activo\n(${ApiService.baseUrl})",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.grayMid, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: cargarPublicaciones,
                        icon: Icon(Icons.refresh_rounded,
                            size: 18, color: colors.primary),
                        label: Text("Reintentar",
                            style: TextStyle(color: colors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                    if (_radioActivo && !_errorConexion)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text("Ajusta el radio en la barra inferior",
                            style: TextStyle(color: colors.grayMid, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
          ),

        // ── Grid de productos ─────────────────────────────────────────────────
        if (_filtradas.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _itemProducto(_filtradas[i]),
                childCount: _filtradas.length,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columnas,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                // La imagen es cuadrada (AspectRatio 1) y el bloque de texto
                // debajo (categoría/título/precio/vendedor) mide ~118 sin
                // importar el ancho de la tarjeta. Si el aspect ratio fuera
                // fijo, con más columnas la tarjeta se hace tan baja que el
                // texto queda cortado. Lo calculamos según el ancho real.
                childAspectRatio: _aspectRatioTarjeta(context),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Delegate para cabecera anclada ────────────────────────────────────────────

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _SearchHeaderDelegate({required this.child, required this.height});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: overlapsContent
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
            : [],
      ),
      child: child,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(_SearchHeaderDelegate old) => old.height != height || old.child != child;
}
