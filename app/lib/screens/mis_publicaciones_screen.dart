import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  @override
  void initState() {
    super.initState();
    cargarPublicaciones();
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
      if (filtro == "activo") return p["estado"] != "vendido";
      if (filtro == "vendido") return p["estado"] == "vendido";
      return true;
    }).toList();
  }

  Future<void> cambiarEstado(int id, String estado) async {
    try {
      await ApiService.cambiarEstado(id, estado);
      await cargarPublicaciones();
    } catch (e) {
      debugPrint("ERROR estado: $e");
    }
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
            onTap: () => cambiarEstado(producto['id'] as int, 'vendido'),
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
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (r) => false,
                    ),
                    child: Image.asset("assets/images/logo.png", height: 40),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Mis publicaciones",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Filtros
            Padding(
              padding: const EdgeInsets.all(16),
              child: _filtroTabs(),
            ),

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
