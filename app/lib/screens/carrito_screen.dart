import 'package:flutter/material.dart';

import '../services/cart_service.dart';
import '../theme/app_theme.dart';

/// Pantalla del carrito de compras (ofertas hechas por el usuario).
///
/// Antes esto vivía solo como un modal (`_mostrarCarrito` en home_screen),
/// ahora es una pantalla propia para que tenga su AppBar e ícono dinámico
/// (assets/images/carrito.png), manteniendo el mismo contenido y estilo
/// visual que tenía el modal original.
class CarritoScreen extends StatelessWidget {
  const CarritoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Mi carrito',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Image.asset('assets/images/carrito.png',
                  width: 28, height: 28),
            ),
          ),
        ],
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.carbon),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppColors.divider, height: 0.5),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: CartService.cartNotifier,
          builder: (_, cart, __) {
            if (cart.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_bag_outlined,
                          size: 48, color: AppColors.grayMid),
                      const SizedBox(height: 12),
                      const Text(
                        "Tu carrito está vacío",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Las ofertas que hagas por productos aparecerán aquí.",
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 13, color: AppColors.grayMid),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Mis ofertas",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => CartService.clear(),
                      child: const Text(
                        "Vaciar",
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...cart.map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.divider, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item["titulo"] ?? "",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Precio publicado: \$${item["precio"]}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.grayMid,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Oferta: \$${item["oferta"]}",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }
}
