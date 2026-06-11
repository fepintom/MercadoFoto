import 'dart:async';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class MensajesScreen extends StatefulWidget {
  const MensajesScreen({super.key});

  @override
  State<MensajesScreen> createState() => _MensajesScreenState();
}

class _MensajesScreenState extends State<MensajesScreen> {
  List<Map<String, dynamic>> _conversaciones = [];
  int? _userId;
  bool _cargando = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _inicializar() async {
    _userId = await SessionService.obtenerUser();
    await _cargar();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _cargar());
  }

  Future<void> _cargar() async {
    if (_userId == null) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    try {
      final data = await ApiService.obtenerConversaciones(_userId!);
      if (!mounted) return;
      setState(() {
        _conversaciones = data;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _formatFecha(String? fecha) {
    if (fecha == null) return '';
    try {
      final dt = DateTime.parse(fecha).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return 'Ayer';
      } else if (diff.inDays < 7) {
        const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
        return dias[dt.weekday - 1];
      } else {
        return '${dt.day}/${dt.month}';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Center(
        child: Text(
          'Inicia sesión para ver tus mensajes',
          style: TextStyle(color: AppColors.grayMid),
        ),
      );
    }

    if (_cargando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_conversaciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: AppColors.grayMid.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text(
              'Sin conversaciones aún',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuando alguien te escriba o\nle escribas a un vendedor, aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grayMid, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _cargar,
      child: ListView.separated(
        itemCount: _conversaciones.length,
        separatorBuilder: (_, __) =>
            Divider(height: 0.5, color: AppColors.divider),
        itemBuilder: (_, i) => _buildItem(_conversaciones[i]),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> conv) {
    final esVendedor = conv['vendedor_id'] == _userId;
    final otroNombre = esVendedor
        ? (conv['nombre_comprador'] ?? 'Comprador')
        : (conv['nombre_vendedor'] ?? 'Vendedor');
    final otraFoto = esVendedor
        ? (conv['foto_comprador'] ?? '')
        : (conv['foto_vendedor'] ?? '');
    final titulo = conv['titulo'] ?? '';
    final ultimoMensaje = conv['ultimo_mensaje'] ?? '';
    final fecha = _formatFecha(conv['ultimo_at']);
    final imagenProducto = conv['imagen_url'] ?? '';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            publicacionId: conv['publicacion_id'],
            tituloProducto: titulo,
            imagenUrl: imagenProducto,
            vendedorId: conv['vendedor_id'],
            nombreVendedor: conv['nombre_vendedor'] ?? '',
            nombreComprador: conv['nombre_comprador'] ?? '',
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar del otro usuario
            _avatar(otraFoto, otroNombre),
            const SizedBox(width: 12),
            // Info conversación
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otroNombre,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        fecha,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.grayMid,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ultimoMensaje,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.grayMid,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Miniatura del producto
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                '${ApiService.baseUrl}$imagenProducto',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: AppColors.background,
                  child: const Icon(Icons.image,
                      size: 20, color: AppColors.grayMid),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String fotoUrl, String nombre) {
    final initial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
    if (fotoUrl.isNotEmpty && fotoUrl.startsWith('http')) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(fotoUrl),
      );
    }
    return CircleAvatar(
      radius: 26,
      backgroundColor: AppColors.primary.withOpacity(0.15),
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
    );
  }
}
