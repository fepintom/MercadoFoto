import 'dart:async';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

class AyudaChatScreen extends StatefulWidget {
  final int ticketId;
  final String tipo;
  final String? numeroReferencia;

  const AyudaChatScreen({
    super.key,
    required this.ticketId,
    required this.tipo,
    this.numeroReferencia,
  });

  @override
  State<AyudaChatScreen> createState() => _AyudaChatScreenState();
}

class _AyudaChatScreenState extends State<AyudaChatScreen> {
  List<Map<String, dynamic>> _mensajes = [];
  Map<String, dynamic>? _ticket;
  bool _cargando = true;
  bool _enviando = false;
  final _msgCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _pollTimer;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _userId = await SessionService.obtenerUser();
    await _cargar();
    // Polling cada 8 segundos para recibir respuestas de soporte
    _pollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _cargar(silencioso: true),
    );
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso && mounted) setState(() => _cargando = true);
    try {
      final data = await ApiService.obtenerMensajesTicket(widget.ticketId);
      if (!mounted) return;
      final msgs = List<Map<String, dynamic>>.from(data['mensajes'] ?? []);
      final hadNew = msgs.length > _mensajes.length;
      setState(() {
        _mensajes = msgs;
        _ticket   = data['ticket'] as Map<String, dynamic>?;
        _cargando = false;
      });
      if (hadNew) _scrollAlFinal();
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _msgCtrl.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    _msgCtrl.clear();
    try {
      await ApiService.enviarMensajeTicket(widget.ticketId, texto);
      await _cargar(silencioso: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar. Intenta de nuevo.')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cerrarTicket() async {
    if (_userId == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Marcar como resuelto?'),
        content: const Text(
            'Cerrarás esta consulta. ¿El problema fue solucionado?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white),
            child: const Text('Sí, resuelto'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await ApiService.cerrarTicketAyuda(widget.ticketId, _userId!);
    if (mounted) Navigator.pop(context, true);
  }

  String get _tipoLabel {
    const map = {
      'pedido':       '📦 Pedido',
      'venta':        '🏪 Venta',
      'servicio':     '🔧 Servicio',
      'otros':        '❓ Consulta',
      'chat_directo': '💬 Chat con soporte',
    };
    return map[widget.tipo] ?? widget.tipo;
  }

  Color get _estadoColor {
    switch (_ticket?['estado']) {
      case 'en_proceso': return Colors.orange;
      case 'resuelto':   return Colors.green;
      default:           return AppColors.primary;
    }
  }

  String get _estadoLabel {
    switch (_ticket?['estado']) {
      case 'en_proceso': return 'En proceso';
      case 'resuelto':   return 'Resuelto';
      default:           return 'Abierto';
    }
  }

  @override
  Widget build(BuildContext context) {
    final resuelto = _ticket?['estado'] == 'resuelto';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                    bottom: BorderSide(color: AppColors.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: AppColors.carbon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_tipoLabel,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        if (widget.numeroReferencia != null &&
                            widget.numeroReferencia!.isNotEmpty)
                          Text('Ref: ${widget.numeroReferencia}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.grayMid)),
                      ],
                    ),
                  ),
                  // Badge estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _estadoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: _estadoColor.withOpacity(0.4)),
                    ),
                    child: Text(_estadoLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _estadoColor)),
                  ),
                  if (!resuelto) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _cerrarTicket,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded,
                            size: 18, color: Colors.green),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Aviso inicial ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primary.withOpacity(0.05),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ticket #${widget.ticketId} · '
                      'Te responderemos a la brevedad',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

            // ── Mensajes ────────────────────────────────────────────────────
            Expanded(
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: _mensajes.length,
                      itemBuilder: (_, i) =>
                          _BurbujaMensaje(mensaje: _mensajes[i]),
                    ),
            ),

            // ── Input (oculto si resuelto) ──────────────────────────────────
            if (!resuelto)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                      top: BorderSide(
                          color: AppColors.divider, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: AppColors.divider, width: 0.8),
                        ),
                        child: TextField(
                          controller: _msgCtrl,
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _enviar(),
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Escribe un mensaje…',
                            hintStyle: TextStyle(
                                fontSize: 13, color: AppColors.grayMid),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _enviar,
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _enviando
                            ? const Padding(
                                padding: EdgeInsets.all(11),
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: Colors.green.withOpacity(0.06),
                child: const Text(
                  '✅ Esta consulta fue marcada como resuelta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Burbuja de mensaje ────────────────────────────────────────────────────────

class _BurbujaMensaje extends StatelessWidget {
  final Map<String, dynamic> mensaje;
  const _BurbujaMensaje({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final esSoporte = mensaje['remitente'] == 'soporte';
    final texto = mensaje['mensaje'] as String? ?? '';
    final hora  = _formatHora(mensaje['created_at'] as String?);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            esSoporte ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (esSoporte) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded,
                  size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: esSoporte
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: esSoporte
                        ? AppColors.surface
                        : AppColors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(16),
                      topRight:    const Radius.circular(16),
                      bottomLeft:  Radius.circular(esSoporte ? 4 : 16),
                      bottomRight: Radius.circular(esSoporte ? 16 : 4),
                    ),
                    border: esSoporte
                        ? Border.all(color: AppColors.divider, width: 0.5)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    texto,
                    style: TextStyle(
                      fontSize: 14,
                      color: esSoporte
                          ? AppColors.textPrimary
                          : Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  esSoporte ? 'Soporte · $hora' : hora,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.grayMid),
                ),
              ],
            ),
          ),
          if (!esSoporte) const SizedBox(width: 6),
        ],
      ),
    );
  }

  String _formatHora(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h  = dt.hour.toString().padLeft(2, '0');
      final m  = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}
