import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final sesion = await SessionService.obtenerSesion();
    _miUserId = sesion["user_id"];
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
      backgroundColor: AppColors.surface,
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
            const Text('Contraofertar',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
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
                  backgroundColor: AppColors.primary,
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
              ? AppColors.primary.withOpacity(0.12)
              : esMio
                  ? AppColors.primary
                  : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(esMio ? 16 : 4),
            bottomRight: Radius.circular(esMio ? 4 : 16),
          ),
          border: esOferta
              ? Border.all(color: AppColors.primary.withOpacity(0.4))
              : null,
          boxShadow: [
            BoxShadow(
              color: AppColors.carbon.withOpacity(0.06),
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
                    ? AppColors.primary
                    : esMio
                        ? AppColors.textOnPrimary
                        : AppColors.textPrimary,
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
                    ? AppColors.primary.withOpacity(0.6)
                    : esMio
                        ? AppColors.textOnPrimary.withOpacity(0.7)
                        : AppColors.grayMid,
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
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
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
                        color: AppColors.primary,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                "${ApiService.baseUrl}${widget.imagenUrl}",
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 36,
                  height: 36,
                  color: AppColors.background,
                  child: const Icon(Icons.image,
                      size: 18, color: AppColors.grayMid),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.tituloProducto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    widget.nombreComprador.isNotEmpty
                        ? '${widget.nombreVendedor} · ${widget.nombreComprador}'
                        : widget.nombreVendedor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.grayMid),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.divider),
        ),
      ),
      body: Column(
        children: [
          // Lista de mensajes
          Expanded(
            child: _mensajes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48,
                            color: AppColors.grayMid.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        const Text(
                          "Sé el primero en escribir",
                          style: TextStyle(
                              color: AppColors.grayMid, fontSize: 14),
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
            color: AppColors.surface,
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
                    child: const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.keyboard_hide_rounded,
                          size: 22, color: AppColors.grayMid),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: "Escribe un mensaje...",
                          hintStyle: TextStyle(
                              color: AppColors.grayMid, fontSize: 14),
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
                            ? AppColors.grayMid
                            : AppColors.primary,
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
