import 'dart:async';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import '../widgets/net_image.dart';
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
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Mensajes',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Image.asset('assets/images/mensajes.png',
                  width: 28, height: 28),
            ),
          ),
        ],
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: colors.divider, height: 0.5),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_userId == null) {
      return Center(
        child: Text(
          'Inicia sesión para ver tus mensajes',
          style: TextStyle(color: colors.grayMid),
        ),
      );
    }

    if (_cargando) {
      return Center(
        child: CircularProgressIndicator(color: colors.primary),
      );
    }

    if (_conversaciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: colors.grayMid.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'Sin conversaciones aún',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando alguien te escriba o\nle escribas a un vendedor, aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.grayMid, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _cargar,
      child: ListView.separated(
        itemCount: _conversaciones.length,
        separatorBuilder: (_, __) =>
            Divider(height: 0.5, color: colors.divider),
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
    final ultimoMensaje = (conv['ultimo_mensaje'] ?? '').toString().trim().isEmpty
        ? '📷 Imagen'
        : conv['ultimo_mensaje'].toString();
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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        fecha,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.grayMid,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ultimoMensaje,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.grayMid,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Miniatura del producto
            NetImage(
              '${ApiService.baseUrl}$imagenProducto',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(8),
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
      backgroundColor: colors.primary.withOpacity(0.15),
      child: Text(
        initial,
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
    );
  }
}
