import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

import 'home_screen.dart';
import 'producto_detalle_screen.dart';
import 'editar_publicacion_screen.dart';
import '../widgets/item_producto_widget.dart';

class MisPublicacionesScreen extends StatefulWidget {
  const MisPublicacionesScreen({super.key});

  @override
  State<MisPublicacionesScreen> createState() =>
      _MisPublicacionesScreenState();
}

class _MisPublicacionesScreenState extends State<MisPublicacionesScreen> {
  List publicaciones = [];
  List publicacionesFiltradas = [];
  bool loading = true;
  String filtro = "activo";

  // ── Búsqueda y categorías ─────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _busqueda = '';
  String? _categoriaFiltro;  // null = todas

  @override
  void initState() {
    super.initState();
    cargarPublicaciones();
    _searchCtrl.addListener(() {
      setState(() {
        _busqueda = _searchCtrl.text.toLowerCase();
        aplicarFiltro();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _categoriasDisponibles {
    final cats = publicaciones
        .map((p) => p['categoria'] as String?)
        .whereType<String>()
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return cats;
  }

  Future<void> cargarPublicaciones() async {
    setState(() => loading = true);
    try {
      final session = await SessionService.obtenerSesion();
      final userId = session["user_id"];
      final guestId = session["guest_id"];

      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/publicaciones"),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      final filtradas = (userId != null)
          ? data.where((p) => p["user_id"] == userId).toList()
          : data.where((p) => p["guest_id"] == guestId).toList();

      publicaciones = filtradas;
      aplicarFiltro();
      setState(() => loading = false);
    } catch (e) {
      debugPrint("ERROR MIS PUBLICACIONES: $e");
      setState(() => loading = false);
    }
  }

  void aplicarFiltro() {
    publicacionesFiltradas = publicaciones.where((p) {
      // Filtro estado
      if (filtro == "activo" && p["estado"] == "vendido") return false;
      if (filtro == "vendido" && p["estado"] != "vendido") return false;
      // Filtro categoría
      if (_categoriaFiltro != null &&
          (p["categoria"] as String?) != _categoriaFiltro) return false;
      // Filtro búsqueda
      if (_busqueda.isNotEmpty) {
        final titulo = (p["titulo"] as String? ?? '').toLowerCase();
        final desc   = (p["descripcion"] as String? ?? '').toLowerCase();
        if (!titulo.contains(_busqueda) && !desc.contains(_busqueda)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> cambiarEstado(int id, String estado) async {
    try {
      await ApiService.cambiarEstado(id, estado);
      await cargarPublicaciones();
    } catch (e) {
      debugPrint("ERROR estado: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al actualizar el estado'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _confirmarVendido(Map<String, dynamic> producto) async {
    // Verificar si el usuario eligió "no volver a mostrar"
    final prefs = await SharedPreferences.getInstance();
    final noMostrar = prefs.getBool('skip_confirm_vendido') ?? false;

    if (noMostrar) {
      await cambiarEstado(producto['id'] as int, 'vendido');
      return;
    }

    bool noVolverMostrar = false;

    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Ícono
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: Color(0xFF2E7D32), size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                '¿Confirmar vendido?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '"${producto['titulo']}" migrará a tu lista de Vendidos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: colors.grayMid, height: 1.4),
              ),
              const SizedBox(height: 20),
              // Checkbox no volver a mostrar
              GestureDetector(
                onTap: () => setModalState(() => noVolverMostrar = !noVolverMostrar),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: noVolverMostrar,
                      onChanged: (v) =>
                          setModalState(() => noVolverMostrar = v ?? false),
                      activeColor: colors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Text(
                      'No volver a mostrar',
                      style: TextStyle(
                          fontSize: 13, color: colors.grayMid),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Cancelar',
                          style: TextStyle(color: colors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Confirmar',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmar != true) return;

    if (noVolverMostrar) {
      await prefs.setBool('skip_confirm_vendido', true);
    }

    await cambiarEstado(producto['id'] as int, 'vendido');
  }

  Future<void> _eliminar(Map<String, dynamic> producto) async {
    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.delete_outline, size: 44, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              '¿Eliminar "${producto['titulo']}"?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              "Esta acción no se puede deshacer.",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.grayMid, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("Cancelar",
                        style: TextStyle(color: colors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("Eliminar",
                        style: TextStyle(color: colors.textOnPrimary)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmar != true) return;

    try {
      final session = await SessionService.obtenerSesion();
      await ApiService.eliminarPublicacion(
        producto['id'] as int,
        userId: session["user_id"],
      );
      await cargarPublicaciones();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Publicación eliminada"),
          backgroundColor: colors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al eliminar: $e")),
      );
    }
  }

  Future<void> _editar(Map<String, dynamic> producto) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditarPublicacionScreen(producto: producto),
      ),
    );
    if (resultado == true) await cargarPublicaciones();
  }

  Widget _filtroTabs() {
    return Row(
      children: [
        Expanded(child: _tabButton("activo", "Activos")),
        const SizedBox(width: 8),
        Expanded(child: _tabButton("vendido", "Vendidos")),
      ],
    );
  }

  Widget _tabButton(String key, String label) {
    final selected = filtro == key;
    return GestureDetector(
      onTap: () => setState(() {
        filtro = key;
        aplicarFiltro();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.primary : colors.divider,
            width: 0.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: selected ? Colors.white : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _accionesPublicacion(Map<String, dynamic> producto) {
    final estado = producto['estado'] ?? 'disponible';
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Editar
        _botonAccion(
          icono: Icons.edit_outlined,
          label: "Editar",
          color: colors.textPrimary,
          onTap: () => _editar(producto),
        ),
        const SizedBox(width: 8),
        // Marcar vendido / disponible
        if (estado != 'vendido')
          _botonAccion(
            icono: Icons.check_circle_outline,
            label: "Vendido",
            color: const Color(0xFF2E7D32),
            onTap: () => _confirmarVendido(producto),
          )
        else
          _botonAccion(
            icono: Icons.refresh,
            label: "Activar",
            color: colors.primary,
            onTap: () => cambiarEstado(producto['id'] as int, 'disponible'),
          ),
        const SizedBox(width: 8),
        // Eliminar
        _botonAccion(
          icono: Icons.delete_outline,
          label: "Eliminar",
          color: colors.primary,
          onTap: () => _eliminar(producto),
        ),
      ],
    );
  }

  Widget _botonAccion({
    required IconData icono,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: color),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  bottom: BorderSide(color: colors.divider, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HomeScreen()),
                          (r) => false,
                        );
                      }
                    },
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: colors.textPrimary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      "Mis publicaciones",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filtros
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _filtroTabs(),
            ),

            // Búsqueda
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar en mis publicaciones...',
                  hintStyle: TextStyle(
                      fontSize: 13, color: colors.grayMid),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 20, color: colors.grayMid),
                  suffixIcon: _busqueda.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() {
                              _busqueda = '';
                              aplicarFiltro();
                            });
                          },
                          child: Icon(Icons.close_rounded,
                              size: 18, color: colors.grayMid),
                        )
                      : null,
                  filled: true,
                  fillColor: colors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: colors.divider, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: colors.divider, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: colors.primary, width: 1),
                  ),
                ),
              ),
            ),

            // Chips de categoría
            if (_categoriasDisponibles.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Chip "Todas"
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _categoriaFiltro = null;
                          aplicarFiltro();
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _categoriaFiltro == null
                                ? colors.primary
                                : colors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _categoriaFiltro == null
                                  ? colors.primary
                                  : colors.divider,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'Todas',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _categoriaFiltro == null
                                  ? Colors.white
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Chips por categoría
                    ..._categoriasDisponibles.map((cat) {
                      final selected = _categoriaFiltro == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _categoriaFiltro = selected ? null : cat;
                            aplicarFiltro();
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected
                                  ? colors.primary
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? colors.primary
                                    : colors.divider,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Lista
            Expanded(
              child: loading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: colors.primary))
                  : publicacionesFiltradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 56, color: colors.grayMid),
                              const SizedBox(height: 12),
                              Text(
                                filtro == "activo"
                                    ? "No tienes publicaciones activas"
                                    : "No tienes publicaciones vendidas",
                                style: TextStyle(
                                  color: colors.grayMid,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: colors.primary,
                          onRefresh: cargarPublicaciones,
                          child: ListView.builder(
                            itemCount: publicacionesFiltradas.length,
                            itemBuilder: (_, i) {
                              final producto =
                                  publicacionesFiltradas[i] as Map<String, dynamic>;
                              return Column(
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProductoDetalleScreen(
                                            producto: producto),
                                      ),
                                    ).then((_) => cargarPublicaciones()),
                                    child: ItemProductoWidget(
                                      producto: producto,
                                      onAction: (action) {
                                        if (action == "vendido") {
                                          cambiarEstado(
                                              producto["id"] as int,
                                              "vendido");
                                        }
                                        if (action == "activar") {
                                          cambiarEstado(
                                              producto["id"] as int,
                                              "disponible");
                                        }
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 12),
                                    child: _accionesPublicacion(producto),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
