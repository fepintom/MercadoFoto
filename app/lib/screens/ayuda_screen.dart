import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'ayuda_chat_screen.dart';

// ── Tipos de consulta ─────────────────────────────────────────────────────────

enum _TipoAyuda { pedido, venta, servicio, otros }

extension _TipoAyudaExt on _TipoAyuda {
  String get label {
    switch (this) {
      case _TipoAyuda.pedido:   return 'Un pedido';
      case _TipoAyuda.venta:    return 'Una venta / compra';
      case _TipoAyuda.servicio: return 'Un servicio';
      case _TipoAyuda.otros:    return 'Otro motivo';
    }
  }

  IconData get icono {
    switch (this) {
      case _TipoAyuda.pedido:   return Icons.shopping_bag_outlined;
      case _TipoAyuda.venta:    return Icons.storefront_outlined;
      case _TipoAyuda.servicio: return Icons.handyman_outlined;
      case _TipoAyuda.otros:    return Icons.help_outline_rounded;
    }
  }

  String get numeroLabel {
    switch (this) {
      case _TipoAyuda.pedido:   return 'Número de pedido';
      case _TipoAyuda.venta:    return 'Número de venta';
      case _TipoAyuda.servicio: return 'Número de servicio';
      case _TipoAyuda.otros:    return '';
    }
  }

  String get numeroHint {
    switch (this) {
      case _TipoAyuda.pedido:   return 'Ej: PED-00123';
      case _TipoAyuda.venta:    return 'Ej: VTA-00456';
      case _TipoAyuda.servicio: return 'Ej: SRV-00789';
      case _TipoAyuda.otros:    return '';
    }
  }

  bool get requiereNumero => this != _TipoAyuda.otros;
}

// ── Pantalla principal ────────────────────────────────────────────────────────

class AyudaScreen extends StatefulWidget {
  const AyudaScreen({super.key});

  @override
  State<AyudaScreen> createState() => _AyudaScreenState();
}

class _AyudaScreenState extends State<AyudaScreen> {
  _TipoAyuda? _tipoSeleccionado;
  final _numeroCtrl   = TextEditingController();
  final _detalleCtrl  = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool _enviando      = false;

  int? _userId;
  List<Map<String, dynamic>> _tickets = [];
  bool _cargandoTickets = false;

  // ── Chat directo ───────────────────────────────────────────────────────────
  bool _mostrarBurbuja   = false;
  bool _abriendo         = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _detalleCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _userId = await SessionService.obtenerUser();
    if (_userId != null) _cargarTickets();
  }

  Future<void> _cargarTickets() async {
    if (_userId == null) return;
    setState(() => _cargandoTickets = true);
    try {
      final t = await ApiService.obtenerTicketsAyuda(_userId!);
      if (mounted) setState(() => _tickets = t);
    } catch (_) {}
    if (mounted) setState(() => _cargandoTickets = false);
  }

  void _seleccionar(_TipoAyuda tipo) {
    setState(() {
      _tipoSeleccionado = tipo;
      _numeroCtrl.clear();
      _detalleCtrl.clear();
    });
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para enviar una consulta')));
      return;
    }
    setState(() => _enviando = true);
    try {
      final result = await ApiService.crearTicketAyuda(
        userId:           _userId!,
        tipo:             _tipoSeleccionado!.name,
        numeroReferencia: _numeroCtrl.text.trim(),
        detalle:          _detalleCtrl.text.trim(),
      );
      if (!mounted) return;
      final ticketId = result['ticket_id'] as int;
      // Navegar directo al chat del ticket
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AyudaChatScreen(
            ticketId:         ticketId,
            tipo:             _tipoSeleccionado!.name,
            numeroReferencia: _numeroCtrl.text.trim(),
          ),
        ),
      );
      // Al volver, recargar lista de tickets y limpiar form
      _tipoSeleccionado = null;
      _numeroCtrl.clear();
      _detalleCtrl.clear();
      _cargarTickets();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al enviar. Verifica tu conexión.')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _abrirChatDirecto() async {
    setState(() { _mostrarBurbuja = false; _abriendo = true; });
    try {
      if (_userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Debes iniciar sesión para chatear con soporte')));
        return;
      }
      final result = await ApiService.crearChatDirecto(_userId!);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AyudaChatScreen(
            ticketId:         result['ticket_id'] as int,
            tipo:             'chat_directo',
            numeroReferencia: result['caso_numero'] as String?,
          ),
        ),
      );
      _cargarTickets();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo iniciar el chat. Intenta de nuevo.')));
      }
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Dimmer para cerrar burbuja al tocar afuera ─────────────────
            if (_mostrarBurbuja)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _mostrarBurbuja = false),
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox.expand(),
                ),
              ),

            Column(
              children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.divider, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: AppColors.carbon),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Obtener ayuda',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        Text('¿En qué te podemos ayudar?',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.grayMid)),
                      ],
                    ),
                  ),
                  // ── Monito ────────────────────────────────────────────
                  GestureDetector(
                    onTap: () => setState(() => _mostrarBurbuja = !_mostrarBurbuja),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🐒', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Contenido ──────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Selector de motivo ─────────────────────────────────
                    const Text('¿Qué tipo de ayuda necesitas?',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 12),

                    // Grid 2x2
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.6,
                      children: _TipoAyuda.values
                          .map((t) => _TarjetaTipo(
                                tipo: t,
                                seleccionado: _tipoSeleccionado == t,
                                onTap: () => _seleccionar(t),
                              ))
                          .toList(),
                    ),

                    const SizedBox(height: 24),

                    // ── Formulario ─────────────────────────────────────────
                    if (_tipoSeleccionado != null)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _buildFormulario(),
                      )
                    else
                      _buildEstadoInicial(),

                    // ── Consultas anteriores ───────────────────────────────
                    if (_tickets.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const Text('Mis consultas anteriores',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 10),
                      ..._tickets.map((t) => _TarjetaTicket(
                            ticket: t,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AyudaChatScreen(
                                    ticketId: t['id'] as int,
                                    tipo:     t['tipo'] as String,
                                    numeroReferencia:
                                        t['numero_referencia'] as String?,
                                  ),
                                ),
                              );
                              _cargarTickets();
                            },
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),  // Column principal

        // ── Burbuja "Chatea con nosotros" ─────────────────────────────
        if (_mostrarBurbuja)
          Positioned(
            top: 58, right: 16,
            child: _NubeBurbuja(
              onTap: _abriendo ? null : _abrirChatDirecto,
              cargando: _abriendo,
            ),
          ),
      ],  // Stack children
    ),    // Stack
  ),      // SafeArea
);
  }

  // ── Estado inicial (sin tipo elegido) ──────────────────────────────────────
  Widget _buildEstadoInicial() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.touch_app_rounded,
                size: 52, color: AppColors.grayMid.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text(
              'Selecciona el motivo\npara continuar',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: AppColors.grayMid, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Formulario de detalle ──────────────────────────────────────────────────
  Widget _buildFormulario() {
    final tipo = _tipoSeleccionado!;
    return Form(
      key: _formKey,
      child: Column(
        key: ValueKey(tipo),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título sección
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(tipo.icono, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Ayuda con ${tipo.label.toLowerCase()}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Campo número de referencia (solo si aplica)
          if (tipo.requiereNumero) ...[
            _labelCampo(tipo.numeroLabel),
            const SizedBox(height: 6),
            _campoTexto(
              controller: _numeroCtrl,
              hint: tipo.numeroHint,
              icon: Icons.tag_rounded,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Ingresa el número de referencia'
                  : null,
            ),
            const SizedBox(height: 16),
          ],

          // Campo detalle del problema
          _labelCampo('Detalle del problema'),
          const SizedBox(height: 6),
          _campoTexto(
            controller: _detalleCtrl,
            hint: 'Descríbenos qué ocurrió con el mayor detalle posible…',
            icon: Icons.edit_note_rounded,
            maxLines: 5,
            validator: (v) => (v == null || v.trim().length < 10)
                ? 'El detalle debe tener al menos 10 caracteres'
                : null,
          ),

          const SizedBox(height: 24),

          // Botón enviar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _enviando ? null : _enviar,
              icon: _enviando
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _enviando ? 'Enviando…' : 'Enviar solicitud de ayuda',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers de UI ──────────────────────────────────────────────────────────
  Widget _labelCampo(String texto) => Text(
        texto,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary),
      );

  Widget _campoTexto({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
          fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontSize: 13, color: AppColors.grayMid),
        prefixIcon: maxLines == 1
            ? Icon(icon, size: 18, color: AppColors.grayMid)
            : Padding(
                padding: const EdgeInsets.only(left: 14, top: 14),
                child: Icon(icon, size: 18, color: AppColors.grayMid),
              ),
        prefixIconConstraints: maxLines > 1
            ? const BoxConstraints(minWidth: 44)
            : null,
        alignLabelWithHint: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(
            horizontal: 16, vertical: maxLines > 1 ? 14 : 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}

// ── Burbuja "Chatea con nosotros" ────────────────────────────────────────────

class _NubeBurbuja extends StatelessWidget {
  final VoidCallback? onTap;
  final bool cargando;
  const _NubeBurbuja({required this.onTap, required this.cargando});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cuerpo de la burbuja
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.2), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cargando)
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.8, color: AppColors.primary),
                  )
                else
                  const Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: AppColors.primary),
                const SizedBox(width: 7),
                Text(
                  cargando ? 'Iniciando…' : 'Chatea con nosotros',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Cola triangular apuntando a la derecha (hacia el monito)
          CustomPaint(
            size: const Size(9, 16),
            painter: _ColaBurbuja(),
          ),
        ],
      ),
    );
  }
}

class _ColaBurbuja extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(0, size.height / 2 - 7)
      ..lineTo(0, size.height / 2 + 7)
      ..lineTo(size.width, size.height / 2)
      ..close();
    canvas.drawPath(path, paint);

    // Borde de la cola
    final border = Paint()
      ..color = AppColors.primary.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Tarjeta de tipo de ayuda ──────────────────────────────────────────────────

class _TarjetaTipo extends StatelessWidget {
  final _TipoAyuda tipo;
  final bool seleccionado;
  final VoidCallback onTap;

  const _TarjetaTipo({
    required this.tipo,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? AppColors.primary : AppColors.divider,
            width: seleccionado ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: seleccionado
                    ? AppColors.primary.withOpacity(0.12)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(tipo.icono,
                  size: 17,
                  color:
                      seleccionado ? AppColors.primary : AppColors.grayMid),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tipo.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: seleccionado
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: seleccionado
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (seleccionado)
              const Icon(Icons.check_circle_rounded,
                  size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de ticket previo ───────────────────────────────────────────────────

class _TarjetaTicket extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;
  const _TarjetaTicket({required this.ticket, required this.onTap});

  static const _tipoLabels = {
    'pedido':   '📦 Pedido',
    'venta':    '🏪 Venta',
    'servicio': '🔧 Servicio',
    'otros':    '❓ Consulta',
  };

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'en_proceso': return Colors.orange;
      case 'resuelto':   return Colors.green;
      default:           return AppColors.primary;
    }
  }

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'en_proceso': return 'En proceso';
      case 'resuelto':   return 'Resuelto';
      default:           return 'Abierto';
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado     = ticket['estado'] as String? ?? 'abierto';
    final tipo       = ticket['tipo'] as String? ?? 'otros';
    final detalle    = ticket['detalle'] as String? ?? '';
    final respuestas = ticket['respuestas'] as int? ?? 0;
    final color      = _estadoColor(estado);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: respuestas > 0 ? color.withOpacity(0.4) : AppColors.divider,
            width: respuestas > 0 ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_tipoLabels[tipo] ?? tipo,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_estadoLabel(estado),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(detalle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grayMid)),
                  if (respuestas > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.reply_rounded,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '$respuestas respuesta${respuestas > 1 ? 's' : ''} de soporte',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: AppColors.grayMid),
          ],
        ),
      ),
    );
  }
}
