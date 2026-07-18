import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

/// Chat con el agente de soporte IA de OkVenta.
///
/// Si la vista de origen tiene una orden en contexto, se pasa [ordenId] para
/// que el agente ya sepa de qué orden se trata sin que el usuario lo explique.
/// Las acciones sensibles (ej. cancelar orden) llegan como burbujas con
/// botones de confirmación: solo al confirmar se llama a /support/confirm-action.
class SoporteChatScreen extends StatefulWidget {
  final int? ordenId;

  const SoporteChatScreen({super.key, this.ordenId});

  @override
  State<SoporteChatScreen> createState() => _SoporteChatScreenState();
}

class _MensajeChat {
  final String rol; // 'user' | 'assistant'
  final String texto;
  Map<String, dynamic>? accion; // acción pendiente de confirmación
  String? accionEstado; // null | 'confirmada' | 'rechazada'

  _MensajeChat(this.rol, this.texto, {this.accion});
}

class _SoporteChatScreenState extends State<SoporteChatScreen> {
  final List<_MensajeChat> _mensajes = [];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _escribiendo = false;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _userId = await SessionService.obtenerUser();
    setState(() {
      _mensajes.add(_MensajeChat(
        'assistant',
        widget.ordenId != null
            ? '¡Hola! Soy el asistente de OkVenta. Veo que estás en la orden '
                '#${widget.ordenId}. ¿En qué te puedo ayudar?'
            : '¡Hola! Soy el asistente de OkVenta. Puedo ayudarte con pagos, '
                'entregas, cancelaciones y cómo funciona la app. ¿Qué necesitas?',
      ));
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _bajarScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _inputCtrl.text.trim();
    if (texto.isEmpty || _escribiendo || _userId == null) return;
    _inputCtrl.clear();
    setState(() {
      _mensajes.add(_MensajeChat('user', texto));
      _escribiendo = true;
    });
    _bajarScroll();

    try {
      final historial = _mensajes
          .where((m) => m.texto.isNotEmpty)
          .map((m) => {'role': m.rol, 'content': m.texto})
          .toList();
      // El último ya es el mensaje actual: no duplicarlo en el historial
      if (historial.isNotEmpty) historial.removeLast();

      final resp = await ApiService.supportChat(
        userId: _userId!,
        message: texto,
        orderId: widget.ordenId,
        conversationHistory: historial
            .map((h) => {'role': h['role']!, 'content': h['content']!})
            .toList(),
      );

      final reply = resp?['reply'] as String? ??
          'No pude procesar tu consulta. Intenta de nuevo en un momento.';
      final msg = _MensajeChat('assistant', reply);
      if (resp?['requires_confirmation'] == true && resp?['action'] != null) {
        msg.accion = Map<String, dynamic>.from(resp!['action']);
      }
      if (mounted) setState(() => _mensajes.add(msg));
    } catch (_) {
      if (mounted) {
        setState(() => _mensajes.add(_MensajeChat('assistant',
            'Tuve un problema de conexión. Intenta de nuevo en un momento.')));
      }
    } finally {
      if (mounted) setState(() => _escribiendo = false);
      _bajarScroll();
    }
  }

  Future<void> _confirmarAccion(_MensajeChat msg) async {
    if (_userId == null || msg.accion == null) return;
    setState(() => _escribiendo = true);
    try {
      final r = await ApiService.supportConfirmAction(
        userId: _userId!,
        actionToken: msg.accion!['action_token'] as String,
      );
      if (!mounted) return;
      setState(() {
        msg.accionEstado = 'confirmada';
        _mensajes.add(_MensajeChat('assistant',
            r['mensaje'] as String? ?? 'Listo, la acción fue ejecutada.'));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        msg.accionEstado = 'rechazada';
        _mensajes.add(_MensajeChat('assistant',
            e.toString().replaceFirst('Exception: ', '')));
      });
    } finally {
      if (mounted) setState(() => _escribiendo = false);
      _bajarScroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: AppColors.carbon),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ayuda OkVenta',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text('Asistente virtual',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.grayMid)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _mensajes.length + (_escribiendo ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _mensajes.length) return _burbujaEscribiendo();
                return _burbuja(_mensajes[i]);
              },
            ),
          ),
          // ── Input ────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                  top: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _enviar(),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu consulta…',
                      hintStyle: const TextStyle(
                          fontSize: 14, color: AppColors.grayMid),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _enviar,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _burbuja(_MensajeChat m) {
    final esUsuario = m.rol == 'user';
    return Align(
      alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: esUsuario ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(esUsuario ? 16 : 4),
            bottomRight: Radius.circular(esUsuario ? 4 : 16),
          ),
          border: esUsuario
              ? null
              : Border.all(color: AppColors.divider, width: 0.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.texto,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: esUsuario ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (m.accion != null) _panelConfirmacion(m),
          ],
        ),
      ),
    );
  }

  /// Botones de confirmar/rechazar dentro de la burbuja del agente.
  Widget _panelConfirmacion(_MensajeChat m) {
    final titulo = m.accion?['titulo'] as String? ?? '';
    final monto = m.accion?['monto'];
    if (m.accionEstado != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          m.accionEstado == 'confirmada'
              ? '✓ Cancelación confirmada'
              : 'Acción no ejecutada',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: m.accionEstado == 'confirmada'
                ? Colors.green
                : AppColors.grayMid,
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cancelar "$titulo"${monto != null ? ' (\$$monto)' : ''}',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _escribiendo ? null : () => _confirmarAccion(m),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Confirmar cancelación'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => m.accionEstado = 'rechazada'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.grayMid,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('No, gracias'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _burbujaEscribiendo() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 0.6),
        ),
        child: const SizedBox(
          width: 34,
          child: Text('•••',
              style: TextStyle(
                  fontSize: 16,
                  letterSpacing: 2,
                  color: AppColors.grayMid)),
        ),
      ),
    );
  }
}
