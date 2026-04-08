import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'producto_detalle_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List publicaciones = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    cargarPublicaciones();
  }

  Future<void> cargarPublicaciones() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/publicaciones"),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (!mounted) return;

      setState(() {
        publicaciones = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (e) {
      debugPrint("ERROR MARKETPLACE: $e");
      if (!mounted) return;
      setState(() {
        publicaciones = [];
        loading = false;
      });
    }
  }

  Widget _itemProducto(Map item) {
    final imagenUrl = item['imagen_url'] ?? "";
    final titulo = item['titulo'] ?? "";
    final precio = item['precio'] ?? 0;
    final vendedor = item['nombre_vendedor'] ?? "Usuario invitado";
    final bool registrado = item['user_id'] != null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductoDetalleScreen(producto: item),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── IMAGEN ───────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.network(
                "${ApiService.baseUrl}$imagenUrl",
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 140,
                  color: AppColors.background,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: AppColors.grayMid,
                  ),
                ),
              ),
            ),

            // ── INFO ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "\$${precio.toString()}",
                    style: const TextStyle(
                      fontSize: 17,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        registrado ? Icons.verified_user : Icons.person_outline,
                        size: 12,
                        color:
                            registrado ? AppColors.carbon : AppColors.grayMid,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vendedor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: registrado
                                ? AppColors.carbon
                                : AppColors.grayMid,
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── HEADER ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Marketplace",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                "${publicaciones.length} productos",
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.grayMid,
                ),
              ),
            ],
          ),
        ),

        // ── SIN PRODUCTOS ─────────────────────────────────────
        if (publicaciones.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                "No hay productos disponibles",
                style: TextStyle(color: AppColors.grayMid),
              ),
            ),
          ),

        // ── GRID ─────────────────────────────────────────────
        if (publicaciones.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemCount: publicaciones.length,
            itemBuilder: (_, i) => _itemProducto(publicaciones[i]),
          ),
      ],
    );
  }
}
