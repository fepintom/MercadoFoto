import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import 'producto_detalle_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  final String? categoriaFiltro;
  final String? subcategoriaFiltro;

  const MarketplaceScreen({
    super.key,
    this.categoriaFiltro,
    this.subcategoriaFiltro,
  });

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List<Map<String, dynamic>> publicaciones = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    cargarPublicaciones();
  }

  Future<void> cargarPublicaciones() async {
    try {
      var uri = Uri.parse("${ApiService.baseUrl}/publicaciones");

      // Aplicar filtro de categoría si existe
      if (widget.categoriaFiltro != null || widget.subcategoriaFiltro != null) {
        final params = <String, String>{};
        if (widget.categoriaFiltro != null) {
          params['categoria'] = widget.categoriaFiltro!;
        }
        if (widget.subcategoriaFiltro != null) {
          params['subcategoria'] = widget.subcategoriaFiltro!;
        }
        uri = uri.replace(queryParameters: params);
      }

      final response = await http.get(uri);
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

  Widget _itemProducto(Map<String, dynamic> item) {
    final imagenUrl = item['imagen_url'] ?? "";
    final titulo = item['titulo'] ?? "";
    final precio = item['precio'] ?? 0;
    final vendedor = item['nombre_vendedor'] ?? "Usuario invitado";
    final bool registrado = item['user_id'] != null;
    final categoria = item['categoria'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductoDetalleScreen(producto: item),
          ),
        ).then((_) => setState(() {}));
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
            // Imagen
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                "${ApiService.baseUrl}$imagenUrl",
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 140,
                  color: AppColors.background,
                  child: const Icon(Icons.image_not_supported,
                      color: AppColors.grayMid),
                ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categoría (si existe)
                  if (categoria != null && categoria.toString().isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        categoria.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ),

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
                        registrado
                            ? Icons.verified_user
                            : Icons.person_outline,
                        size: 12,
                        color: registrado
                            ? AppColors.carbon
                            : AppColors.grayMid,
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
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final tituloSeccion = widget.categoriaFiltro != null
        ? widget.subcategoriaFiltro != null
            ? "${widget.categoriaFiltro} · ${widget.subcategoriaFiltro}"
            : widget.categoriaFiltro!
        : "Marketplace";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header sección
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tituloSeccion,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              // Contador + carrito
              Row(
                children: [
                  Text(
                    "${publicaciones.length} productos",
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.grayMid,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Ícono carrito con badge
                  ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: CartService.cartNotifier,
                    builder: (_, cart, __) {
                      return Stack(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: cart.isNotEmpty
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.background,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              size: 18,
                              color: cart.isNotEmpty
                                  ? AppColors.primary
                                  : AppColors.grayMid,
                            ),
                          ),
                          if (cart.isNotEmpty)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    "${cart.length}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Sin resultados
        if (publicaciones.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 48, color: AppColors.grayMid),
                  const SizedBox(height: 12),
                  Text(
                    widget.categoriaFiltro != null
                        ? "Sin productos en esta categoría"
                        : "No hay productos disponibles",
                    style: const TextStyle(color: AppColors.grayMid),
                  ),
                ],
              ),
            ),
          ),

        // Grid
        if (publicaciones.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.68,
            ),
            itemCount: publicaciones.length,
            itemBuilder: (_, i) => _itemProducto(publicaciones[i]),
          ),
      ],
    );
  }
}
