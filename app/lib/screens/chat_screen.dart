import 'dart:async';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final int publicacionId;
  final String tituloProducto;
  final String imagenUrl;
  final int vendedorId;
  final String nombreVendedor;

  const ChatScreen({
    super.key,
    required this.publicacionId,
    required this.tituloProducto,
    required this.imagenUrl,
    required this.vendedorId,
    required this.nombreVendedor,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
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
    // Polling cada 5 segundos para mensajes nuevos
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _cargarMensajes(),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _controller.dispose();
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

  Widget _burbuja(Map<String, dynamic> m) {
    final esMio = m['remitente'] == _miUserId;
    final texto = m['mensaje'] ?? '';
    final hora = _formatHora(m['fecha'] ?? '');

    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: esMio ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(esMio ? 16 : 4),
            bottomRight: Radius.circular(esMio ? 4 : 16),
          ),
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
                color: esMio ? AppColors.textOnPrimary : AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hora,
              style: TextStyle(
                fontSize: 10,
                color: esMio
                    ? AppColors.textOnPrimary.withOpacity(0.7)
                    : AppColors.grayMid,
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
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: AppColors.textPrimary),
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
                  child: const Icon(Icons.image, size: 18, color: AppColors.grayMid),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    widget.nombreVendedor,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.grayMid,
                    ),
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
                            size: 48, color: AppColors.grayMid.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        const Text(
                          "Sé el primero en escribir",
                          style: TextStyle(color: AppColors.grayMid, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _mensajes.length,
                    itemBuilder: (_, i) => _burbuja(_mensajes[i]),
                  ),
          ),

          // Input
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
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
                          hintStyle: TextStyle(color: AppColors.grayMid, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
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
