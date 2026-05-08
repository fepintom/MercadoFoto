import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/format_utils.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'producto_detalle_screen.dart';

class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  List<Map<String, dynamic>> _favoritos = [];
  bool _loading = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final sesion = await SessionService.obtenerSesion();
      _userId = sesion["user_id"];
      if (_userId != null) {
        final data = await ApiService.obtenerFavoritos(_userId!);
        if (!mounted) return;
        setState(() => _favoritos = data);
      }
    } catch (e) {
      debugPrint("ERROR favoritos: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _quitarFavorito(int publicacionId) async {
    if (_userId == null) return;
    try {
      await ApiService.quitarFavorito(_userId!, publicacionId);
      setState(() {
        _favoritos.removeWhere((p) => p['id'] == publicacionId);
      });
    } catch (e) {
      debugPrint("ERROR quitar favorito: $e");
    }
  }

  Widget _tarjetaFavorito(Map<String, dynamic> p) {
    final imagenUrl = p['imagen_url'] ?? '';
    final titulo = p['titulo'] ?? '';
    final precio = p['precio'] ?? 0;
    final categoria = p['categoria'];
    final estado = p['estado'] ?? 'disponible';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: p)),
      ).then((_) => _cargar()),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.carbon.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Imagen
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
              child: Container(
                width: 90, height: 90, color: Colors.white,
                child: Image.network(
                  "${ApiService.baseUrl}$imagenUrl",
                  width: 90,
                  height: 90,
                  fit: BoxFit.contain,
                  alignment: const Alignment(0, -0.4),
                  errorBuilder: (_, __, ___) => Container(
                    width: 90,
                    height: 90,
                    color: Colors.white,
                    child: const Icon(Icons.image_not_supported,
                        color: AppColors.grayMid),
                  ),
                ),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          formatPrecio(precio),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (estado == 'vendido') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.grayMid.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Vendido",
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.grayMid),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Botón quitar
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => _confirmarQuitar(p['id'] as int, titulo),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite,
                      color: AppColors.primary, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarQuitar(int id, String titulo) async {
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
            const Icon(Icons.favorite_border, size: 40, color: AppColors.grayMid),
            const SizedBox(height: 12),
            Text(
              '¿Quitar "$titulo" de favoritos?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
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
                    child: const Text("Quitar",
                        style: TextStyle(color: AppColors.textOnPrimary)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmar == true) _quitarFavorito(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Mis favoritos",
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.divider),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _userId == null
              ? _sinLogin()
              : _favoritos.isEmpty
                  ? _vacio()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _cargar,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _favoritos.length,
                        itemBuilder: (_, i) => _tarjetaFavorito(_favoritos[i]),
                      ),
                    ),
    );
  }

  Widget _vacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border,
              size: 60, color: AppColors.grayMid.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text(
            "No tienes favoritos todavía",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            "Guarda productos que te interesen\npara verlos rápido después",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grayMid, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _sinLogin() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline,
              size: 48, color: AppColors.grayMid.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text(
            "Inicia sesión para ver tus favoritos",
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
