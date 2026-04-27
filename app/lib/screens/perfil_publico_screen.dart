import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'producto_detalle_screen.dart';

class PerfilPublicoScreen extends StatefulWidget {
  final int userId;
  final String nombre;

  const PerfilPublicoScreen({
    super.key,
    required this.userId,
    required this.nombre,
  });

  @override
  State<PerfilPublicoScreen> createState() => _PerfilPublicoScreenState();
}

class _PerfilPublicoScreenState extends State<PerfilPublicoScreen> {
  bool _cargando = true;
  String _nombre = '';
  List<dynamic> _publicaciones = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombre = widget.nombre;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final url = Uri.parse(
          '${ApiService.baseUrl}/usuarios/${widget.userId}/perfil_publico');
      final res =
          await http.get(url).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _nombre = data['nombre'] ?? widget.nombre;
          _publicaciones = data['publicaciones'] ?? [];
          _cargando = false;
        });
      } else {
        setState(() {
          _error = 'No se pudo cargar el perfil';
          _cargando = false;
        });
      }
    } catch (_) {
      setState(() {
        _error = 'Sin conexión al servidor';
        _cargando = false;
      });
    }
  }

  // ── Inicial del nombre para el avatar ─────────────────────────────────────
  String get _inicial =>
      _nombre.isNotEmpty ? _nombre[0].toUpperCase() : '?';

  // ── Precio formateado ──────────────────────────────────────────────────────
  String _formatPrecio(dynamic precio) {
    if (precio == null) return '';
    final n = (precio as num).toInt();
    // Formato con puntos: 1.500.000
    final s = n.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return '\$${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.carbon),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Perfil del vendedor',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _buildContenido(),
    );
  }

  // ── Estado de error ────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 56, color: AppColors.grayMid.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.grayMid,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  // ── Contenido principal ────────────────────────────────────────────────────
  Widget _buildContenido() {
    return CustomScrollView(
      slivers: [
        // ── Encabezado con avatar + nombre ──────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                // Avatar con inicial
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, Color(0xFF00C9A7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _inicial,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Nombre
                Text(
                  _nombre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 4),

                // Subtítulo de privacidad
                const Text(
                  'Solo se muestran sus publicaciones activas',
                  style: TextStyle(fontSize: 12, color: AppColors.grayMid),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Badge cantidad publicaciones
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_publicaciones.length} '
                    '${_publicaciones.length == 1 ? 'publicación' : 'publicaciones'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Separador ───────────────────────────────────────────────────────
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // ── Grid de publicaciones ────────────────────────────────────────────
        _publicaciones.isEmpty
            ? SliverToBoxAdapter(child: _buildSinPublicaciones())
            : SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _buildTarjeta(_publicaciones[i]),
                    childCount: _publicaciones.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                ),
              ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ── Sin publicaciones ──────────────────────────────────────────────────────
  Widget _buildSinPublicaciones() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 56, color: AppColors.grayMid.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            '$_nombre no tiene publicaciones activas',
            style: const TextStyle(
                fontSize: 15,
                color: AppColors.grayMid,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Tarjeta de producto ────────────────────────────────────────────────────
  Widget _buildTarjeta(Map<String, dynamic> prod) {
    final imagenUrl = prod['imagen_url'] as String? ?? '';
    final titulo = prod['titulo'] as String? ?? '';
    final precio = prod['precio'];

    return GestureDetector(
      onTap: () {
        // Navigamos al detalle pasando el objeto completo
        // (nombre_vendedor + user_id se añaden para que el detalle funcione)
        final prodConVendedor = Map<String, dynamic>.from(prod)
          ..['nombre_vendedor'] = _nombre
          ..['user_id'] = widget.userId;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductoDetalleScreen(producto: prodConVendedor),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14)),
                child: imagenUrl.isNotEmpty
                    ? Image.network(
                        imagenUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => _imagenPlaceholder(),
                      )
                    : _imagenPlaceholder(),
              ),
            ),

            // Info
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  if (precio != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatPrecio(precio),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagenPlaceholder() {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Icon(Icons.image_outlined,
            size: 36, color: AppColors.grayMid),
      ),
    );
  }
}
