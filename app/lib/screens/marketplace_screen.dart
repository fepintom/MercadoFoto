import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/format_utils.dart';

import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import 'producto_detalle_screen.dart';

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

  const MarketplaceScreen({
    super.key,
    this.miLat,
    this.miLng,
    this.radioKm = 50.0,
    this.filtroUbicacionActivo = false,
  });

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  // ── Categorías ────────────────────────────────────────────────────────────
  static const List<Categoria> _categorias = [
    Categoria(nombre: "Automotriz",  icono: Icons.directions_car_rounded,  subcategorias: ["Repuestos", "Autos", "Motos", "Camiones"]),
    Categoria(nombre: "Electrónica", icono: Icons.devices_rounded,         subcategorias: ["Computación", "Impresión 3D", "Celulares", "TV"]),
    Categoria(nombre: "Hogar",       icono: Icons.weekend_rounded,         subcategorias: ["Muebles", "Decoración", "Electrodomésticos"]),
    Categoria(nombre: "Ocio",        icono: Icons.sports_soccer_rounded,   subcategorias: ["Deportes", "Juguetes", "Entretenimiento"]),
    Categoria(nombre: "Mascotas",    icono: Icons.pets_rounded,            subcategorias: ["Alimentos", "Accesorios", "Servicios"]),
  ];
  String? _categoriaSeleccionada;
  String? _subcategoriaSeleccionada;

  // ── Datos ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _todas = [];
  List<Map<String, dynamic>> _filtradas = [];
  bool _loading = true;
  bool _errorConexion = false;

  // ── Búsqueda y precio ─────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  double? _precioMin;
  double? _precioMax;
  bool _buscando = false;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    cargarPublicaciones();
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
    if (_categoriaSeleccionada != null) {
      lista = lista.where((p) =>
        (p['categoria'] ?? '').toString().toLowerCase() ==
        _categoriaSeleccionada!.toLowerCase()
      ).toList();
    }
    if (_subcategoriaSeleccionada != null) {
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

    _filtradas = lista;
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
      backgroundColor: AppColors.carbon,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text("Filtrar por precio",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _campoFiltro(ctrl: minCtrl, hint: "Mínimo", prefix: "\$")),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text("—", style: TextStyle(color: AppColors.grayMid, fontSize: 18))),
              Expanded(child: _campoFiltro(ctrl: maxCtrl, hint: "Máximo", prefix: "\$")),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() { _precioMin = null; _precioMax = null; cargarPublicaciones(); });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Limpiar", style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _precioMin = double.tryParse(minCtrl.text.trim());
                      _precioMax = double.tryParse(maxCtrl.text.trim());
                      _aplicarFiltros();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Aplicar", style: TextStyle(color: AppColors.textOnPrimary)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _campoFiltro({required TextEditingController ctrl, required String hint, String? prefix}) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint, prefixText: prefix,
        hintStyle: const TextStyle(color: AppColors.grayMid, fontSize: 14),
        filled: true, fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  // ── Barra de categorías (inline, en el scroll) ────────────────────────────

  Widget _buildCategoryBar() {
    final catActual = _categorias.where((c) => c.nombre == _categoriaSeleccionada);
    final subcats = catActual.isNotEmpty ? catActual.first.subcategorias : <String>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Categorías principales
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            itemCount: _categorias.length,
            itemBuilder: (_, i) {
              final cat = _categorias[i];
              final selected = _categoriaSeleccionada == cat.nombre;
              return GestureDetector(
                onTap: () => setState(() {
                  _categoriaSeleccionada    = selected ? null : cat.nombre;
                  _subcategoriaSeleccionada = null;
                  _aplicarFiltros();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.divider,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icono, size: 13,
                          color: selected ? Colors.white : AppColors.grayMid),
                      const SizedBox(width: 5),
                      Text(cat.nombre,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : AppColors.textPrimary,
                          )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Subcategorías
        if (_categoriaSeleccionada != null && subcats.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                      color: selected ? AppColors.carbon : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.carbon : AppColors.divider,
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Text(sub,
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : AppColors.textSecondary,
                          )),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Card de producto ──────────────────────────────────────────────────────

  Widget _itemProducto(Map<String, dynamic> item) {
    final imagenUrl = item['imagen_url'] ?? "";
    final titulo    = item['titulo'] ?? "";
    final precio    = item['precio'] ?? 0;
    final vendedor  = item['nombre_vendedor'] ?? "Usuario invitado";
    final bool registrado = item['user_id'] != null;
    final categoria = item['categoria'];

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
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    height: 140, width: double.infinity,
                    color: Colors.white,
                    child: Image.network(
                      "${ApiService.baseUrl}$imagenUrl",
                      height: 140, width: double.infinity, fit: BoxFit.contain,
                      alignment: Alignment(0, -0.4),
                      errorBuilder: (_, __, ___) => Container(
                        height: 140, color: Colors.white,
                        child: const Icon(Icons.image_not_supported, color: AppColors.grayMid),
                      ),
                    ),
                  ),
                ),
                if (distKm != null)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.carbon.withValues(alpha: 0.80),
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
                  if (categoria != null && categoria.toString().isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(categoria.toString(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.primary)),
                    ),
                  Text(titulo,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text(formatPrecio(precio),
                      style: const TextStyle(fontSize: 17, color: AppColors.primary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(registrado ? Icons.verified_user : Icons.person_outline,
                          size: 12, color: registrado ? AppColors.carbon : AppColors.grayMid),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(vendedor,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: registrado ? AppColors.carbon : AppColors.grayMid)),
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
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(onTap: onClear, child: const Icon(Icons.close, size: 14, color: AppColors.primary)),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final tituloSeccion = _categoriaSeleccionada != null
        ? _subcategoriaSeleccionada != null
            ? "$_categoriaSeleccionada · $_subcategoriaSeleccionada"
            : _categoriaSeleccionada!
        : "Marketplace";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── 1. Barra búsqueda + tune ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      if (v.trim().isEmpty) setState(() => cargarPublicaciones());
                    },
                    onSubmitted: _buscarEnBackend,
                    decoration: InputDecoration(
                      hintText: "Buscar productos...",
                      hintStyle: const TextStyle(color: AppColors.grayMid, fontSize: 13),
                      prefixIcon: _buscando
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                            )
                          : const Icon(Icons.search, size: 18, color: AppColors.grayMid),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () { _searchCtrl.clear(); setState(() => cargarPublicaciones()); },
                              child: const Icon(Icons.close, size: 16, color: AppColors.grayMid))
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
                    color: _tieneFiltroPrecio ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _tieneFiltroPrecio ? AppColors.primary : AppColors.divider),
                  ),
                  child: Icon(Icons.tune, size: 18,
                      color: _tieneFiltroPrecio ? AppColors.textOnPrimary : AppColors.grayMid),
                ),
              ),
            ],
          ),
        ),

        // ── 2. Barra de categorías (inline, scrollable) ──────────────────────
        _buildCategoryBar(),

        // ── 3. Chip filtro precio activo ─────────────────────────────────────
        if (_tieneFiltroPrecio)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: _chipFiltro(
              label: _precioMin != null && _precioMax != null
                  ? "${formatPrecio(_precioMin)} — ${formatPrecio(_precioMax)}"
                  : _precioMin != null
                      ? "Desde ${formatPrecio(_precioMin)}"
                      : "Hasta ${formatPrecio(_precioMax)}",
              onClear: () => setState(() { _precioMin = null; _precioMax = null; cargarPublicaciones(); }),
            ),
          ),

        // ── 4. Header: título + cartera ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(tituloSeccion,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              GestureDetector(
                onTap: _mostrarConteoProductos,
                child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: CartService.cartNotifier,
                  builder: (_, cart, __) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: cart.isNotEmpty ? AppColors.primary.withValues(alpha: 0.10) : AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shopping_bag_outlined, size: 18,
                            color: cart.isNotEmpty ? AppColors.primary : AppColors.grayMid),
                      ),
                      if (cart.isNotEmpty)
                        Positioned(
                          right: -2, top: -2,
                          child: Container(
                            width: 15, height: 15,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
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

        // ── 5. Sin resultados / error ────────────────────────────────────────
        if (_filtradas.isEmpty)
          Padding(
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
                    color: _errorConexion ? AppColors.primary : AppColors.grayMid,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorConexion
                        ? "Sin conexión al servidor"
                        : _radioActivo
                            ? "Sin productos en ${_formatRadio(widget.radioKm)} de tu ubicación"
                            : _searchCtrl.text.isNotEmpty
                                ? "Sin resultados para \"${_searchCtrl.text}\""
                                : _categoriaSeleccionada != null
                                    ? "Sin productos en esta categoría"
                                    : "No hay productos disponibles",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _errorConexion ? AppColors.textPrimary : AppColors.grayMid,
                      fontSize: 14,
                      fontWeight: _errorConexion ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (_errorConexion) ...[
                    const SizedBox(height: 6),
                    Text(
                      "Verifica que el servidor esté activo\n(${ApiService.baseUrl})",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.grayMid, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: cargarPublicaciones,
                      icon: const Icon(Icons.refresh_rounded,
                          size: 18, color: AppColors.primary),
                      label: const Text("Reintentar",
                          style: TextStyle(color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                  if (_radioActivo && !_errorConexion)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text("Ajusta el radio en la barra inferior",
                          style: TextStyle(color: AppColors.grayMid, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ),

        // ── 6. Grid ──────────────────────────────────────────────────────────
        if (_filtradas.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.65,
            ),
            itemCount: _filtradas.length,
            itemBuilder: (_, i) => _itemProducto(_filtradas[i]),
          ),
      ],
    );
  }
}
