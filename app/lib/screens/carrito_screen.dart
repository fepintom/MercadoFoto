import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/net_image.dart';
import 'producto_detalle_screen.dart';

/// Carro de compras: productos guardados para comprar más tarde. El
/// checkout de OkVenta es por producto (cada uno con su propio vendedor y
/// envío), así que "Comprar" en cada ítem lleva a su publicación para
/// completar la compra ahí.
class CarritoScreen extends StatelessWidget {
  const CarritoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Mi carro',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
        actions: [
          // Okventin "compra exitosa": solo en modo oscuro, al entrar al carro.
          ValueListenableBuilder<bool>(
            valueListenable: ThemeService.isDarkNotifier,
            builder: (_, isDark, __) {
              if (!isDark) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: Image.asset('assets/images/okventin_compra.png',
                      width: 57, height: 57),
                ),
              );
            },
          ),
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: CartService.cartNotifier,
            builder: (_, cart, __) => cart.isEmpty
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () => CartService.clear(),
                    child: Text('Vaciar',
                        style: TextStyle(color: colors.primary)),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: CartService.cartNotifier,
          builder: (context, items, __) {
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 48, color: colors.grayMid),
                      SizedBox(height: 12),
                      Text('Tu carro está vacío',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary)),
                      SizedBox(height: 4),
                      Text(
                        'Agrega productos desde su publicación con\n'
                        '"Agregar al carro".',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 13, color: colors.grayMid),
                      ),
                    ],
                  ),
                ),
              );
            }

            final total = items.fold<double>(
                0, (acc, p) => acc + ((p['precio'] as num?)?.toDouble() ?? 0));

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _ItemCarrito(
                      producto: items[i],
                      onQuitar: () => CartService.quitarEn(i),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                        top: BorderSide(color: colors.divider, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Text('Total',
                          style: TextStyle(
                              fontSize: 14, color: colors.textSecondary)),
                      const SizedBox(width: 8),
                      Text(formatPrecio(total),
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: colors.primary)),
                      const Spacer(),
                      Text(
                          '${items.length} '
                          '${items.length == 1 ? "producto" : "productos"}',
                          style: TextStyle(
                              fontSize: 12, color: colors.grayMid)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ItemCarrito extends StatelessWidget {
  final Map<String, dynamic> producto;
  final VoidCallback onQuitar;

  const _ItemCarrito({required this.producto, required this.onQuitar});

  @override
  Widget build(BuildContext context) {
    final imagenUrl = producto['imagen_url']?.toString() ?? '';
    final titulo = producto['titulo']?.toString() ?? '';
    final precio = producto['precio'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imagenUrl.isNotEmpty
                ? NetImage("${ApiService.baseUrl}$imagenUrl",
                    width: 60, height: 60, fit: BoxFit.cover)
                : Container(
                    width: 60,
                    height: 60,
                    color: colors.background,
                    child: Icon(Icons.image_outlined,
                        color: colors.grayMid),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary)),
                const SizedBox(height: 4),
                if (precio != null)
                  Text(formatPrecio((precio as num).toDouble()),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colors.primary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(
                onPressed: onQuitar,
                icon: Icon(Icons.delete_outline_rounded,
                    size: 20, color: colors.grayMid),
                visualDensity: VisualDensity.compact,
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductoDetalleScreen(
                        producto: Map<String, dynamic>.from(producto),
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Comprar',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: colors.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
