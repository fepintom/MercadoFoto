import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/net_image.dart';
import '../widgets/boton_anular_envio.dart';
import 'confirmar_envio_media_screen.dart';
import 'visor_media_screen.dart';

/// Chat de un servicio.
///
/// Va aparte del chat de productos a propósito: aquel está construido
/// entero alrededor de una publicación (cabecera del producto, ofertas,
/// contraofertas, fotos y videos). Un servicio necesita otra cosa —
/// mensajes y cotizaciones— y mezclarlos habría obligado a llenar de
/// condicionales una pantalla que hoy funciona.
///
/// Quien presta el servicio puede enviar una cotización: se genera un PDF
/// con el formato estándar de OkVenta y llega al chat como una tarjeta con
/// aceptar / rechazar. Al aceptar se cobra y arranca el Seguro Garantía.
class ChatServicioScreen extends StatefulWidget {
  final int servicioId;
  final int proveedorId;
  /// Con quién conversa el proveedor. El hilo es el par (servicio, cliente):
  /// cada cliente tiene su propia conversación, y así el proveedor puede
  /// cotizarle a una persona en concreto.
  final int clienteId;
  final String tituloServicio;
  final String nombreProveedor;
  final String nombreCliente;

  const ChatServicioScreen({
    super.key,
    required this.servicioId,
    required this.proveedorId,
    required this.clienteId,
    required this.tituloServicio,
    this.nombreProveedor = '',
    this.nombreCliente = '',
  });

  @override
  State<ChatServicioScreen> createState() => _ChatServicioScreenState();
}

class _ChatServicioScreenState extends State<ChatServicioScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<dynamic> _mensajes = [];
  final Map<int, Map<String, dynamic>> _cotizaciones = {};
  int? _userId;
  bool _cargando = true;
  bool _enviando = false;
  bool _pagando = false;
  Timer? _poll;

  /// El servicio completo, para saber su precio y si se puede contratar.
  /// Se carga aparte porque a esta pantalla se llega desde varios lados y
  /// no todos tienen el objeto entero a mano.
  Map<String, dynamic>? _servicio;

  bool get _soyProveedor => _userId != null && _userId == widget.proveedorId;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    _userId = await SessionService.obtenerUser();
    ApiService.obtenerServicioPorId(widget.servicioId).then((srv) {
      if (mounted && srv != null) setState(() => _servicio = srv);
    }).catchError((_) {});
    await _cargar();
    if (mounted) setState(() => _cargando = false);
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _cargar());
  }

  Future<void> _cargar() async {
    try {
      final msgs = await ApiService.obtenerChatServicio(
          widget.servicioId, widget.clienteId);
      // Las cotizaciones se piden una sola vez cada una y se cachean: el
      // chat se refresca cada 5 s y no vale re-consultarlas en cada vuelta.
      for (final m in msgs) {
        final cid = m['cotizacion_id'];
        if (cid is int && !_cotizaciones.containsKey(cid)) {
          final c = await ApiService.obtenerCotizacion(cid);
          if (c != null) _cotizaciones[cid] = c;
        }
      }
      if (!mounted) return;
      final crecio = msgs.length != _mensajes.length;
      setState(() => _mensajes = msgs);
      if (crecio) _alFinal();
    } catch (_) {
      // Silencioso: es un refresco periódico.
    }
  }

  void _alFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  void _aviso(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: error ? colors.primary : colors.carbon,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty || _userId == null || _enviando) return;
    setState(() => _enviando = true);
    try {
      await ApiService.enviarMensajeServicio(
        servicioId: widget.servicioId,
        clienteId: widget.clienteId,
        remitenteId: _userId!,
        mensaje: texto,
      );
      _ctrl.clear();
      await _cargar();
      _alFinal();
    } catch (e) {
      _aviso('$e'.replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ── Adjuntos: fotos y video de evidencia ──────────────────────────────────

  void _menuAdjuntar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: colors.primary),
              title: Text('Tomar foto',
                  style: TextStyle(color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _enviarImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.photo_library_outlined, color: colors.primary),
              title: Text('Elegir de la galería',
                  style: TextStyle(color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _enviarImagen(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam_outlined, color: colors.primary),
              title: Text('Grabar video (máx. 1 min)',
                  style: TextStyle(color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _enviarVideo();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarImagen(ImageSource origen) async {
    if (_userId == null || _enviando) return;
    final picked = await ImagePicker()
        .pickImage(source: origen, imageQuality: 75, maxWidth: 1080);
    if (picked == null || !mounted) return;

    // Paso de confirmación: ver qué se eligió, poder comentarlo y poder
    // arrepentirse. Antes se enviaba apenas se soltaba el dedo.
    final envio = await Navigator.push<EnvioMedia>(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmarEnvioMediaScreen(archivo: File(picked.path)),
      ),
    );
    if (envio == null) return;

    setState(() => _enviando = true);
    try {
      await ApiService.enviarImagenChatServicio(
        servicioId: widget.servicioId,
        clienteId: widget.clienteId,
        remitenteId: _userId!,
        imagen: envio.archivo,
        comentario: envio.comentario,
      );
      await _cargar();
      _alFinal();
    } catch (e) {
      _aviso('$e'.replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _enviarVideo() async {
    if (_userId == null || _enviando) return;
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 1),
    );
    if (picked == null || !mounted) return;

    final envio = await Navigator.push<EnvioMedia>(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmarEnvioMediaScreen(
            archivo: File(picked.path), esVideo: true),
      ),
    );
    if (envio == null) return;

    setState(() => _enviando = true);
    try {
      await ApiService.enviarVideoChatServicio(
        servicioId: widget.servicioId,
        clienteId: widget.clienteId,
        remitenteId: _userId!,
        video: envio.archivo,
        comentario: envio.comentario,
      );
      await _cargar();
      _alFinal();
    } catch (e) {
      _aviso('$e'.replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ── Anular un envío propio ────────────────────────────────────────────────

  Future<void> _anularMensaje(Map m) async {
    final id = m['id'];
    if (id is! int || _userId == null) return;
    try {
      await ApiService.borrarMensajeChat(mensajeId: id, userId: _userId!);
      // Se quita de inmediato en vez de esperar el refresco de 5 s: si el
      // mensaje sigue ahí un rato, parece que no funcionó.
      if (mounted) {
        setState(() => _mensajes.removeWhere((x) => x is Map && x['id'] == id));
      }
    } catch (e) {
      _aviso('$e'.replaceFirst('Exception: ', ''), error: true);
      await _cargar();
    }
  }

  // ── Cotización ────────────────────────────────────────────────────────────

  Future<void> _abrirFormularioCotizacion() async {
    // El cliente viene dado por el hilo, no hay que deducirlo de quién
    // escribió último: el proveedor cotiza siempre a la persona con la que
    // está conversando.
    final clienteId = widget.clienteId;

    final empresaCtrl = TextEditingController(text: widget.tituloServicio);
    final servicioCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    final detalleCtrl = TextEditingController();

    final enviar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Enviar cotización',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const SizedBox(height: 4),
              Text('Se envía como PDF al chat, con el formato de OkVenta.',
                  style: TextStyle(fontSize: 12, color: colors.grayMid)),
              const SizedBox(height: 16),
              _campo('Nombre de empresa', empresaCtrl),
              const SizedBox(height: 12),
              _campo('Servicio cotizado', servicioCtrl),
              const SizedBox(height: 12),
              _campo('Monto del servicio', montoCtrl,
                  teclado: TextInputType.number),
              const SizedBox(height: 12),
              _campo('Detalle', detalleCtrl, lineas: 4),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Enviar cotización'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (enviar != true || _userId == null) return;

    final monto = double.tryParse(
        montoCtrl.text.replaceAll(RegExp(r'[^\d]'), ''));
    if (servicioCtrl.text.trim().isEmpty || monto == null || monto <= 0) {
      _aviso('Falta el servicio o el monto.', error: true);
      return;
    }

    try {
      await ApiService.enviarCotizacion(
        servicioId: widget.servicioId,
        proveedorId: widget.proveedorId,
        clienteId: clienteId,
        servicioCotizado: servicioCtrl.text.trim(),
        monto: monto,
        detalle: detalleCtrl.text.trim(),
        empresa: empresaCtrl.text.trim(),
      );
      await _cargar();
      _alFinal();
      _aviso('Cotización enviada');
    } catch (e) {
      _aviso('$e'.replaceFirst('Exception: ', ''), error: true);
    }
  }

  Widget _campo(String label, TextEditingController c,
      {TextInputType teclado = TextInputType.text, int lineas = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: colors.grayMid)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: teclado,
          maxLines: lineas,
          style: TextStyle(fontSize: 14, color: colors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: colors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.divider, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.divider, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _responderCotizacion(int cotizacionId, bool aceptar) async {
    if (_userId == null) return;
    try {
      if (!aceptar) {
        await ApiService.rechazarCotizacion(cotizacionId, _userId!);
        _cotizaciones.remove(cotizacionId);
        await _cargar();
        _aviso('Cotización rechazada');
        return;
      }

      final r = await ApiService.aceptarCotizacion(cotizacionId, _userId!);
      _cotizaciones.remove(cotizacionId);
      await _cargar();

      if (r['test_mode'] == true) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: colors.surface,
            title: Text('Servicio contratado',
                style: TextStyle(color: colors.textPrimary)),
            content: Text(
              '${r['mensaje'] ?? 'Pago simulado.'}\n\n'
              'Se abonó el 80% al proveedor. El 20% restante queda en el '
              'Seguro Garantía OkVenta por 30 días.',
              style: TextStyle(color: colors.textSecondary),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido')),
            ],
          ),
        );
      } else {
        final url = r['init_point'] as String?;
        if (url != null && url.isNotEmpty) {
          await launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      _aviso('$e'.replaceFirst('Exception: ', ''), error: true);
    }
  }

  // ── Contratar y pagar ─────────────────────────────────────────────────────
  //
  // Vive acá y no en el detalle del servicio porque ese es el orden real:
  // primero se contacta, luego se cotiza y recién al final se contrata. En
  // el detalle aparecía antes de haber hablado con nadie.

  Future<void> _pagarServicio() async {
    if (_userId == null || _pagando || _servicio == null) return;
    final monto = (_servicio!['valor'] as num?)?.toDouble() ?? 0;
    if (monto <= 0) {
      _aviso('Este servicio no tiene un precio fijo. Pídele una cotización.');
      return;
    }

    setState(() => _pagando = true);
    try {
      final data = await ApiService.crearPreferencia(
        compradorId: _userId!,
        vendedorId: widget.proveedorId,
        tipo: 'servicio',
        titulo: (_servicio!['titulo'] ?? 'Servicio').toString(),
        monto: monto,
        servicioId: widget.servicioId,
      );

      if (data['test_mode'] == true) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: colors.surface,
            title: Text('Servicio contratado',
                style: TextStyle(color: colors.textPrimary)),
            content: Text(
              'Pago simulado (modo prueba). No se realizó ningún cobro real.\n\n'
              'Se abonó el 80% al proveedor. El 20% restante queda en el '
              'Seguro Garantía OkVenta por 30 días.',
              style: TextStyle(color: colors.textSecondary),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido')),
            ],
          ),
        );
        await _cargar();
        return;
      }

      final initPoint =
          (data['init_point'] ?? data['sandbox_init_point'] ?? '').toString();
      if (initPoint.isEmpty) throw Exception('No se pudo iniciar el pago');
      await launchUrl(Uri.parse(initPoint),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      _aviso('$e'.replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _pagando = false);
    }
  }

  /// Barra de contratar. Solo la ve el cliente, y solo si el servicio tiene
  /// un precio fijo publicado — si no, el camino es pedir cotización.
  Widget _barraContratar() {
    if (_soyProveedor || _servicio == null) return const SizedBox.shrink();
    final monto = (_servicio!['valor'] as num?)?.toDouble() ?? 0;
    final tipo = (_servicio!['tipo'] ?? 'ofrezco').toString();
    if (tipo != 'ofrezco' || monto <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Precio publicado',
                  style: TextStyle(fontSize: 11.5, color: colors.grayMid)),
              Text(formatPrecio(monto),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary)),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: _pagando ? null : _pagarServicio,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: colors.grayMid,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _pagando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Contratar y pagar',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tituloServicio,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15)),
            Builder(builder: (_) {
              // Cada lado ve el nombre del otro.
              final otro = _soyProveedor
                  ? widget.nombreCliente
                  : widget.nombreProveedor;
              if (otro.isEmpty) return const SizedBox.shrink();
              return Text(otro,
                  style: TextStyle(fontSize: 11.5, color: colors.grayMid));
            }),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _cargando
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary))
                : _mensajes.isEmpty
                    ? _vacio()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        itemCount: _mensajes.length,
                        itemBuilder: (_, i) => _burbuja(_mensajes[i]),
                      ),
          ),
          _barraContratar(),
          _barraEnvio(),
        ],
      ),
    );
  }

  Widget _vacio() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 42, color: colors.grayMid),
            const SizedBox(height: 12),
            Text(
              _soyProveedor
                  ? 'Cuando alguien te escriba, podrás cotizarle desde aquí.'
                  : 'Escríbele para pedir una cotización.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.grayMid),
            ),
          ]),
        ),
      );

  Widget _burbuja(dynamic m) {
    final esMio = m['remitente'] == _userId;
    if (m['cotizacion_id'] != null) {
      return _tarjetaCotizacion(m['cotizacion_id'] as int, esMio);
    }

    final texto = m['mensaje']?.toString() ?? '';
    final videoUrl = (m['video_url'] ?? '').toString();
    final imagenUrl = (m['imagen_url'] ?? '').toString();

    Widget contenido;
    if (videoUrl.isNotEmpty) {
      contenido = _burbujaMedia(esMio, video: videoUrl, comentario: texto);
    } else if (imagenUrl.isNotEmpty) {
      contenido = _burbujaMedia(esMio, imagen: imagenUrl, comentario: texto);
    } else {
      contenido = Align(
        alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: esMio ? colors.primary : colors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(esMio ? 16 : 4),
              bottomRight: Radius.circular(esMio ? 4 : 16),
            ),
            border:
                esMio ? null : Border.all(color: colors.divider, width: 0.5),
          ),
          child: Text(
            texto,
            style: TextStyle(
                fontSize: 14,
                color: esMio ? Colors.white : colors.textPrimary),
          ),
        ),
      );
    }

    // Botón de anular bajo mis propios envíos, durante un minuto. Va a la
    // vista y no escondido en una pulsación larga: nadie descubre un gesto
    // que no se anuncia, y menos en el minuto que tiene para usarlo.
    if (esMio && m is Map && sePuedeAnular(m['fecha']?.toString())) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          contenido,
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BotonAnularEnvio(
              fecha: m['fecha']?.toString(),
              onAnular: () => _anularMensaje(m),
            ),
          ),
        ],
      );
    }
    return contenido;
  }

  /// Foto o video adjunto.
  ///
  /// Al tocarla se abre el visor de la app. Antes se lanzaba el navegador
  /// del teléfono con la URL del servidor: además de sacarte de la
  /// conversación, dejaba a la vista la dirección interna del servidor.
  Widget _burbujaMedia(bool esMio,
      {String? imagen, String? video, String comentario = ''}) {
    final url = '${ApiService.baseUrl}${video ?? imagen}';
    final esVideo = video != null;

    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment:
              esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisorMediaScreen(
                    url: url,
                    esVideo: esVideo,
                    comentario: comentario,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: esVideo
                    ? Container(
                        width: 200,
                        height: 150,
                        color: colors.carbon,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_circle_fill_rounded,
                                size: 40, color: Colors.white),
                            const SizedBox(height: 6),
                            Text('Toca para ver',
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        Colors.white.withValues(alpha: 0.85))),
                          ],
                        ),
                      )
                    : NetImage(url, width: 200, height: 200, fit: BoxFit.cover),
              ),
            ),

            // El comentario que acompañaba al archivo, pegado debajo: son
            // una sola cosa, no dos mensajes seguidos.
            if (comentario.trim().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxWidth: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: esMio ? colors.primary : colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: esMio
                      ? null
                      : Border.all(color: colors.divider, width: 0.5),
                ),
                child: Text(
                  comentario,
                  style: TextStyle(
                      fontSize: 13,
                      color: esMio ? Colors.white : colors.textPrimary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaCotizacion(int cotizacionId, bool esMia) {
    final c = _cotizaciones[cotizacionId];
    if (c == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: colors.primary),
          ),
        ),
      );
    }

    final estado = c['estado'] as String? ?? 'enviada';
    final pendiente = estado == 'enviada';
    final puedeResponder = pendiente && !esMia;
    final pdf = c['pdf_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: pendiente ? colors.primary.withOpacity(0.45) : colors.divider,
            width: pendiente ? 1.2 : 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.description_outlined, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Cotización de servicio',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
            ),
            if (!pendiente)
              Text(estado == 'aceptada' ? 'Aceptada' : 'Rechazada',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: estado == 'aceptada'
                          ? colors.success
                          : colors.grayMid)),
          ]),
          const SizedBox(height: 10),
          Text(c['servicio_cotizado']?.toString() ?? '',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary)),
          const SizedBox(height: 2),
          Text(formatPrecio(c['monto']),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colors.primary)),
          if ((c['detalle']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(c['detalle'].toString(),
                style: TextStyle(
                    fontSize: 12.5, color: colors.textSecondary, height: 1.4)),
          ],
          if (pdf != null && pdf.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('${ApiService.baseUrl}$pdf'),
                  mode: LaunchMode.externalApplication),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.picture_as_pdf_rounded,
                    size: 16, color: colors.primary),
                const SizedBox(width: 6),
                Text('Ver cotización en PDF',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: colors.primary)),
              ]),
            ),
          ],
          if (puedeResponder) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Te han enviado una cotización del servicio que deseas '
                'contratar. Al aceptar se realiza el pago: se abona el 80% al '
                'proveedor y el 20% queda en el Seguro Garantía OkVenta '
                'por 30 días.',
                style: TextStyle(
                    fontSize: 12, color: colors.textSecondary, height: 1.4),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _responderCotizacion(cotizacionId, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.grayMid,
                    side: BorderSide(color: colors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Rechazar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _responderCotizacion(cotizacionId, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Aceptar y pagar'),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _barraEnvio() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          // Adjuntar foto o video de evidencia.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _enviando ? null : _menuAdjuntar,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.divider, width: 0.5),
                ),
                child: Icon(Icons.attach_file_rounded,
                    size: 20, color: colors.grayMid),
              ),
            ),
          ),
          if (_soyProveedor)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: _abrirFormularioCotizacion,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.request_quote_outlined,
                      size: 20, color: colors.primary),
                ),
              ),
            ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                hintStyle: TextStyle(color: colors.grayMid, fontSize: 14),
                isDense: true,
                filled: true,
                fillColor: colors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: colors.divider, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: colors.divider, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: colors.primary, width: 1.2),
                ),
              ),
              onSubmitted: (_) => _enviar(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _enviando ? null : _enviar,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }
}
