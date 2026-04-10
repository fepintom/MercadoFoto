import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

import 'home_screen.dart';
import 'producto_detalle_screen.dart';
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
      await http.post(
        Uri.parse("${ApiService.baseUrl}/estado_publicacion"),
        body: {
          "publicacion_id": id.toString(),
          "estado": estado,
        },
      );
      await cargarPublicaciones();
    } catch (e) {
      debugPrint("ERROR estado: $e");
    }
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
                  bottom:
                      BorderSide(color: AppColors.divider, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HomeScreen()),
                      (r) => false,
                    ),
                    child: Image.asset("assets/images/logo.png",
                        height: 40),
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
                              final producto = publicacionesFiltradas[i];
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProductoDetalleScreen(
                                            producto: producto),
                                  ),
                                ),
                                child: ItemProductoWidget(
                                  producto: producto,
                                  onAction: (action) {
                                    if (action == "vendido") {
                                      cambiarEstado(
                                          producto["id"], "vendido");
                                    }
                                    if (action == "activar") {
                                      cambiarEstado(
                                          producto["id"], "disponible");
                                    }
                                  },
                                ),
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
