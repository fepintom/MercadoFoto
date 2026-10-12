import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/api_service.dart';
import '../services/privados_service.dart';
import '../widgets/avatar_usuario.dart';
import 'chat_privado_screen.dart';
import '../services/session_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'chat_servicio_screen.dart';
import '../widgets/net_image.dart';
class MensajesScreen extends StatefulWidget {
  const MensajesScreen({super.key});

  @override
  State<MensajesScreen> createState() => _MensajesScreenState();
}

class _MensajesScreenState extends State<MensajesScreen> {
  List<Map<String, dynamic>> _conversaciones = [];
  List<Map<String, dynamic>> _privados = [];
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
      final privados = PrivadosService.conversaciones(_userId!);
      final data = await ApiService.obtenerConversaciones(_userId!);
      final priv = await privados;
      if (!mounted) return;
      setState(() {
        _conversaciones = data;
        _privados = priv;
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
              child: ValueListenableBuilder<bool>(
                valueListenable: ThemeService.isDarkNotifier,
                builder: (_, isDark, __) {
                  // Modo oscuro: tamaño base del home (57) +40% = 80.
                  return Image.asset(
                    isDark ? 'assets/images/okventin_chat.png' : 'assets/images/mensajes.png',
                    width: isDark ? 80 : 28,
                    height: isDark ? 80 : 28,
                  );
                },
              ),
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

    if (_conversaciones.isEmpty && _privados.isEmpty) {
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
        itemCount: _conversaciones.length + 1,
        separatorBuilder: (_, i) => i == 0
            ? const SizedBox.shrink()
            : Divider(height: 0.5, color: colors.divider),
        itemBuilder: (_, i) =>
            i == 0 ? _privadosFranja() : _buildItem(_conversaciones[i - 1]),
      ),
    );
  }

  /// Mensajes privados (los que nacen tocando a alguien en Comunidad):
  /// una fila de caras arriba, con el número de no leídos.
  Widget _privadosFranja() {
    if (_privados.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.mail_outline_rounded, size: 17, color: colors.primary),
            const SizedBox(width: 6),
            Text('Privados',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _privados.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final p = _privados[i];
                final nombre = (p['otro_nombre'] ?? 'Usuario').toString();
                final n = (p['no_leidos'] as num?)?.toInt() ?? 0;
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPrivadoScreen(
                          otroId: (p['otro_id'] as num).toInt(),
                          nombre: nombre,
                          fotoUrl: p['otro_foto']?.toString(),
                        ),
                      ),
                    );
                    _cargar();
                  },
                  child: SizedBox(
                    width: 64,
                    child: Column(children: [
                      Stack(clipBehavior: Clip.none, children: [
                        AvatarUsuario(
                            fotoUrl: p['otro_foto']?.toString(),
                            nombre: nombre,
                            tamano: 54),
                        if (n > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: colors.surface, width: 1.5),
                              ),
                              child: Text('$n',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      Text(nombre.split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  n > 0 ? FontWeight.w800 : FontWeight.w500,
                              color: colors.textPrimary)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
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

    // La bandeja ahora mezcla hilos de productos y de servicios; cada uno
    // abre su propia pantalla de chat.
    final esServicio = conv['tipo_hilo'] == 'servicio';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => esServicio
              ? ChatServicioScreen(
                  servicioId: conv['servicio_id'] as int,
                  proveedorId: conv['vendedor_id'] as int,
                  clienteId: conv['comprador_id'] as int,
                  tituloServicio: titulo,
                  nombreProveedor: conv['nombre_vendedor'] ?? '',
                  nombreCliente: conv['nombre_comprador'] ?? '',
                )
              : ChatScreen(
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
    // fotoUrl puede venir como ruta relativa (/uploads/...) del backend —
    // hay que anteponer baseUrl si no es ya una URL completa.
    final fotoCompleta = fotoUrl.isNotEmpty
        ? (fotoUrl.startsWith('http')
            ? fotoUrl
            : '${ApiService.baseUrl}$fotoUrl')
        : '';
    if (fotoCompleta.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: colors.primary.withOpacity(0.15),
        child: ClipOval(
          child: SizedBox(
            width: 52,
            height: 52,
            child: CachedNetworkImage(
              imageUrl: fotoCompleta,
              fit: BoxFit.cover,
              memCacheWidth: 156,
              fadeInDuration: const Duration(milliseconds: 120),
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
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
