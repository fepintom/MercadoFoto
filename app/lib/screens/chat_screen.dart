import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/net_image.dart';
import 'producto_detalle_screen.dart';
class ChatScreen extends StatefulWidget {
  final int publicacionId;
  final String tituloProducto;
  final String imagenUrl;
  final int vendedorId;
  final String nombreVendedor;
  final String nombreComprador;

  const ChatScreen({
    super.key,
    required this.publicacionId,
    required this.tituloProducto,
    required this.imagenUrl,
    required this.vendedorId,
    required this.nombreVendedor,
    this.nombreComprador = '',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller      = TextEditingController();
  final _contraCtrl      = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _mensajes = [];
  int? _miUserId;
  bool _enviando = false;
  Timer? _pollingTimer;

  // datos del producto (puede llegar vacío desde notificaciones)
  String _titulo    = '';
  String _imagenUrl = '';
  int    _vendedorId = 0;
  bool   _esProductoUsado = false;

  @override
  void initState() {
    super.initState();
    _titulo     = widget.tituloProducto;
    _imagenUrl  = widget.imagenUrl;
    _vendedorId = widget.vendedorId;
    _inicializar();
  }

  Future<void> _inicializar() async {
    final sesion = await SessionService.obtenerSesion();
    _miUserId = sesion["user_id"];

    // Si llegamos sin datos del producto (desde notificación), los obtenemos
    if (_imagenUrl.isEmpty || _titulo.isEmpty) {
      try {
        final pub = await ApiService.obtenerPublicacion(widget.publicacionId);
        if (pub != null && mounted) {
          setState(() {
            _titulo     = pub['titulo']?.toString() ?? _titulo;
            _imagenUrl  = pub['imagen_url']?.toString() ?? _imagenUrl;
            _vendedorId = pub['user_id'] as int? ?? _vendedorId;
            _esProductoUsado = (pub['condicion']?.toString() ?? 'nuevo') == 'usado';
          });
        }
      } catch (_) {}
    } else {
      // Ya teníamos título/imagen (venimos del listado), pero igual
      // necesitamos la condición del producto para el aviso de fotos/videos.
      try {
        final pub = await ApiService.obtenerPublicacion(widget.publicacionId);
        if (pub != null && mounted) {
          setState(() {
            _esProductoUsado = (pub['condicion']?.toString() ?? 'nuevo') == 'usado';
          });
        }
      } catch (_) {}
    }

    await _cargarMensajes();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _cargarMensajes(),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _controller.dispose();
    _contraCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarMensajes() async {
    try {
      final data = await ApiService.obtenerChat(widget.publicacionId);
      if (!mounted) return;
      setState(() => _mensajes = data);
      _scrollAlFinal();
    } catch (e) {
      debugPrint("ERROR chat: $e");
    }
  }

  Future<void> _reproducirVideo(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir el video')));
      }
    }
  }

  void _verImagenCompleta(String url) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      barrierDismissible: false,
      pageBuilder: (_, animation, __) => _VisorImagenChat(url: url, animation: animation),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 200),
    ));
  }

  Future<void> _verProducto() async {
    try {
      final producto = await ApiService.obtenerPublicacion(widget.publicacionId);
      if (!mounted || producto == null) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProductoDetalleScreen(producto: producto),
      ));
    } catch (_) {}
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty || _miUserId == null) return;

    setState(() => _enviando = true);
    _controller.clear();

    try {
      await ApiService.enviarMensaje(
        publicacionId: widget.publicacionId,
        remitenteId: _miUserId!,
        mensaje: texto,
      );
      await _cargarMensajes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo enviar el mensaje")),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ── Envío de imágenes ────────────────────────────────────────────────────

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: colors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: colors.carbon.withOpacity(0.08), shape: BoxShape.circle),
                child: Icon(Icons.camera_alt_outlined, color: colors.textPrimary, size: 20),
              ),
              title: Text('Tomar foto',
                  style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _enviarImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.08), shape: BoxShape.circle),
                child: Icon(Icons.photo_library_outlined, color: colors.primary, size: 20),
              ),
              title: Text('Elegir de la galería',
                  style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _enviarImagen(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: colors.carbon.withOpacity(0.08), shape: BoxShape.circle),
                child: Icon(Icons.videocam_outlined, color: colors.textPrimary, size: 20),
              ),
              title: Text('Grabar video (máx. 10 s)',
                  style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _grabarYEnviarVideo();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarImagen(ImageSource source) async {
    if (_miUserId == null) return;
    try {
      final picked = await ImagePicker().pickImage(
          source: source, imageQuality: 75, maxWidth: 1080);
      if (picked == null) return;

      if (mounted) setState(() => _enviando = true);

      final bytes = await File(picked.path).readAsBytes();
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/chat/${widget.publicacionId}/imagen'),
      );
      req.fields['remitente_id'] = '${_miUserId!}';
      req.files.add(http.MultipartFile.fromBytes(
        'imagen', bytes,
        filename: 'chat_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      final streamed = await req.send().timeout(const Duration(seconds: 20));
      if (streamed.statusCode == 200) {
        await _cargarMensajes();
      } else {
        throw Exception('status ${streamed.statusCode}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar la imagen')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Graba un video corto directamente desde la cámara (no desde la
  /// galería) y lo envía por chat. maxDuration limita la grabación a 10s
  /// desde la propia cámara del picker.
  Future<void> _grabarYEnviarVideo() async {
    if (_miUserId == null) return;
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 10),
      );
      if (picked == null) return;

      if (mounted) setState(() => _enviando = true);

      final bytes = await File(picked.path).readAsBytes();
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/chat/${widget.publicacionId}/video'),
      );
      req.fields['remitente_id'] = '${_miUserId!}';
      req.files.add(http.MultipartFile.fromBytes(
        'video', bytes,
        filename: 'chatvid_${DateTime.now().millisecondsSinceEpoch}.mp4',
      ));
      final streamed = await req.send().timeout(const Duration(seconds: 40));
      if (streamed.statusCode == 200) {
        await _cargarMensajes();
      } else {
        throw Exception('status ${streamed.statusCode}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el video')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ── Lógica de ofertas ─────────────────────────────────────────────────────

  bool get _soyVendedor =>
      _miUserId != null && _miUserId == widget.vendedorId;

  /// True si ya existe una respuesta a la oferta en el índice dado.
  bool _ofertaRespondida(int indexOferta) {
    for (int i = indexOferta + 1; i < _mensajes.length; i++) {
      final msg = (_mensajes[i]['mensaje'] ?? '') as String;
      if (msg.startsWith('✅') ||
          msg.startsWith('❌') ||
          msg.startsWith('↩️')) {
        return true;
      }
    }
    return false;
  }

  /// Extrae el compradorId del mensaje de oferta (quien envió ese mensaje).
  int? _compradorDeOferta(int indexOferta) {
    return _mensajes[indexOferta]['remitente'] as int?;
  }

  Future<void> _responderOferta(
    String accion, {
    double? montoContra,
    String mensaje = '',
    required int compradorId,
  }) async {
    if (_miUserId == null) return;
    setState(() => _enviando = true);
    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/oferta/responder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'publicacion_id': widget.publicacionId,
          'vendedor_id':    _miUserId,
          'comprador_id':   compradorId,
          'accion':         accion,
          if (montoContra != null) 'monto_contra': montoContra,
          'mensaje':        mensaje,
        }),
      );
      await _cargarMensajes();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar respuesta')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarDialogoContraoferta(int compradorId) {
    _contraCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contraofertar',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: _contraCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Tu precio',
                prefixText: '\$',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final monto =
                      double.tryParse(_contraCtrl.text.trim());
                  if (monto == null || monto <= 0) return;
                  Navigator.pop(context);
                  _responderOferta(
                    'contraofertar',
                    montoContra: monto,
                    compradorId: compradorId,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Enviar contraoferta',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _burbuja(Map<String, dynamic> m, int index) {
    final esMio  = m['remitente'] == _miUserId;
    final texto  = (m['mensaje'] ?? '') as String;
    final hora   = _formatHora(m['fecha'] ?? '');
    final imagenUrl = m['imagen_url'] as String?;
    final videoUrl  = m['video_url'] as String?;

    // Burbuja de video
    if (videoUrl != null && videoUrl.isNotEmpty) {
      return Align(
        alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _reproducirVideo('${ApiService.baseUrl}$videoUrl'),
                child: Container(
                  width: 220, height: 160,
                  decoration: BoxDecoration(
                    color: colors.carbon,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(esMio ? 16 : 4),
                      bottomRight: Radius.circular(esMio ? 4 : 16),
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.play_circle_fill_rounded,
                        size: 48, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(hora,
                  style: TextStyle(fontSize: 10, color: colors.grayMid)),
            ],
          ),
        ),
      );
    }

    // Burbuja de imagen
    if (imagenUrl != null && imagenUrl.isNotEmpty) {
      return Align(
        alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _verImagenCompleta('${ApiService.baseUrl}$imagenUrl'),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(esMio ? 16 : 4),
                    bottomRight: Radius.circular(esMio ? 4 : 16),
                  ),
                  child: NetImage(
                    '${ApiService.baseUrl}$imagenUrl',
                    width: 220, height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(hora,
                  style: TextStyle(fontSize: 10, color: colors.grayMid)),
            ],
          ),
        ),
      );
    }

    final esOferta = texto.startsWith('💰 Oferta:');

    // Mostrar botones sólo al vendedor, sólo en la última oferta sin respuesta
    final mostrarAcciones = esOferta &&
        !esMio &&
        _soyVendedor &&
        !_ofertaRespondida(index);

    final burbuja = Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: esOferta
              ? colors.primary.withOpacity(0.12)
              : esMio
                  ? colors.primary
                  : colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(esMio ? 16 : 4),
            bottomRight: Radius.circular(esMio ? 4 : 16),
          ),
          border: esOferta
              ? Border.all(color: colors.primary.withOpacity(0.4))
              : null,
          boxShadow: [
            BoxShadow(
              color: colors.carbon.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              texto,
              style: TextStyle(
                color: esOferta
                    ? colors.primary
                    : esMio
                        ? colors.textOnPrimary
                        : colors.textPrimary,
                fontSize: esOferta ? 16 : 15,
                fontWeight:
                    esOferta ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hora,
              style: TextStyle(
                fontSize: 10,
                color: esOferta
                    ? colors.primary.withOpacity(0.6)
                    : esMio
                        ? colors.textOnPrimary.withOpacity(0.7)
                        : colors.grayMid,
              ),
            ),
          ],
        ),
      ),
    );

    if (!mostrarAcciones) return burbuja;

    // Botones de acción para el vendedor
    final compradorId = _compradorDeOferta(index) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        burbuja,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _enviando
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                        color: colors.primary, strokeWidth: 2),
                  ),
                )
              : Row(
                  children: [
                    // Aceptar
                    Expanded(
                      child: _botonOferta(
                        label: 'Aceptar',
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                        onTap: () => _responderOferta(
                          'aceptar',
                          compradorId: compradorId,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Contraofertar
                    Expanded(
                      child: _botonOferta(
                        label: 'Contraofertar',
                        icon: Icons.swap_horiz_rounded,
                        color: colors.primary,
                        onTap: () =>
                            _mostrarDialogoContraoferta(compradorId),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Rechazar
                    Expanded(
                      child: _botonOferta(
                        label: 'Rechazar',
                        icon: Icons.cancel_outlined,
                        color: Colors.red,
                        onTap: () => _responderOferta(
                          'rechazar',
                          compradorId: compradorId,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _botonOferta({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHora(String fecha) {
    try {
      final dt = DateTime.parse(fecha);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              size: 18, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _verProducto,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _imagenUrl.isNotEmpty
                    ? NetImage(
                        "${ApiService.baseUrl}$_imagenUrl",
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        color: colors.background,
                        child: Icon(Icons.image_outlined,
                            size: 18, color: colors.grayMid),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titulo.isNotEmpty ? _titulo : widget.tituloProducto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.nombreComprador.isNotEmpty
                          ? '${widget.nombreVendedor} · ${widget.nombreComprador}'
                          : widget.nombreVendedor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: colors.grayMid),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: colors.grayMid),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: ThemeService.isDarkNotifier,
                builder: (_, isDark, __) {
                  // Modo oscuro: mismo tamaño agrandado que en el home (57).
                  return Image.asset(
                    isDark ? 'assets/images/okventin_chat.png' : 'assets/images/mensajes.png',
                    width: isDark ? 57 : 26,
                    height: isDark ? 57 : 26,
                  );
                },
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: colors.divider),
        ),
      ),
      body: Column(
        children: [
          // Aviso: producto usado → sugerir pedir fotos/video del estado
          if (_esProductoUsado)
            Container(
              width: double.infinity,
              color: colors.primary.withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Te sugerimos solicitar imágenes o videos cortos "
                      "(máx 10 segundos) del producto para visualizar su estado",
                      style: TextStyle(
                          fontSize: 12,
                          color: colors.primary,
                          height: 1.3,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // Lista de mensajes
          Expanded(
            child: _mensajes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48,
                            color: colors.grayMid.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text(
                          "Sé el primero en escribir",
                          style: TextStyle(
                              color: colors.grayMid, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _mensajes.length,
                    itemBuilder: (_, i) => _burbuja(_mensajes[i], i),
                  ),
          ),

          // Input
          Container(
            color: colors.surface,
            padding: const EdgeInsets.only(
              left: 12, right: 12, top: 10, bottom: 10,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Botón bajar teclado
                  GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.keyboard_hide_rounded,
                          size: 22, color: colors.grayMid),
                    ),
                  ),
                  // Botón imagen
                  GestureDetector(
                    onTap: _enviando ? null : _mostrarOpcionesImagen,
                    child: Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.image_outlined,
                          size: 22, color: colors.grayMid),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: colors.divider),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: "Escribe un mensaje...",
                          hintStyle: TextStyle(
                              color: colors.grayMid, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _enviar(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _enviando ? null : _enviar,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _enviando
                            ? colors.grayMid
                            : colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _enviando
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Visor de imagen completa con zoom ────────────────────────────────────────
class _VisorImagenChat extends StatefulWidget {
  final String url;
  final Animation<double> animation;
  const _VisorImagenChat({required this.url, required this.animation});

  @override
  State<_VisorImagenChat> createState() => _VisorImagenChatState();
}

class _VisorImagenChatState extends State<_VisorImagenChat> {
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: GestureDetector(
          onTap: () {},
          child: Center(
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 0.8,
              maxScale: 5.0,
              child: Image.network(
                widget.url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      color: Colors.white54,
                      strokeWidth: 2,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
