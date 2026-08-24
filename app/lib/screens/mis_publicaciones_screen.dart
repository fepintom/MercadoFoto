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
      backgroundColor: AppColors.surface,
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
                  color: AppColors.divider,
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
              const Text(
                '¿Confirmar vendido?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '"${producto['titulo']}" migrará a tu lista de Vendidos.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.grayMid, height: 1.4),
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
                      activeColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const Text(
                      'No volver a mostrar',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.grayMid),
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
                        side: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancelar',
                          style: TextStyle(color: AppColors.textSecondary)),
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
      backgroundColor: AppColors.surface,
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
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.delete_outline, size: 44, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              '¿Eliminar "${producto['titulo']}"?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              "Esta acción no se puede deshacer.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grayMid, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Cancelar",
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Eliminar",
                        style: TextStyle(color: AppColors.textOnPrimary)),
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
        const SnackBar(
          content: Text("Publicación eliminada"),
          backgroundColor: AppColors.primary,
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
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: 0.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: selected ? Colors.white : AppColors.textSecondary,
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
          color: AppColors.carbon,
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
            color: AppColors.primary,
            onTap: () => cambiarEstado(producto['id'] as int, 'disponible'),
          ),
        const SizedBox(width: 8),
        // Eliminar
        _botonAccion(
          icono: Icons.delete_outline,
          label: "Eliminar",
          color: AppColors.primary,
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.divider, width: 0.5),
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
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: AppColors.carbon),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      "Mis publicaciones",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
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
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.grayMid),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: AppColors.grayMid),
                  suffixIcon: _busqueda.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() {
                              _busqueda = '';
                              aplicarFiltro();
                            });
                          },
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: AppColors.grayMid),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AppColors.divider, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AppColors.divider, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AppColors.primary, width: 1),
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
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _categoriaFiltro == null
                                  ? AppColors.primary
                                  : AppColors.divider,
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
                                  : AppColors.textSecondary,
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
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.divider,
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
                                    : AppColors.textSecondary,
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
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : publicacionesFiltradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 56, color: AppColors.grayMid),
                              const SizedBox(height: 12),
                              Text(
                                filtro == "activo"
                                    ? "No tienes publicaciones activas"
                                    : "No tienes publicaciones vendidas",
                                style: const TextStyle(
                                  color: AppColors.grayMid,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
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
