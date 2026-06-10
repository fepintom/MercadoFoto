import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Tipos de consulta ─────────────────────────────────────────────────────────

enum _TipoAyuda { pedido, venta, servicio, otros }

extension _TipoAyudaExt on _TipoAyuda {
  String get label {
    switch (this) {
      case _TipoAyuda.pedido:   return 'Un pedido';
      case _TipoAyuda.venta:    return 'Una venta';
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
  bool _enviado       = false;

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _detalleCtrl.dispose();
    super.dispose();
  }

  void _seleccionar(_TipoAyuda tipo) {
    setState(() {
      _tipoSeleccionado = tipo;
      _numeroCtrl.clear();
      _detalleCtrl.clear();
      _enviado = false;
    });
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    // TODO: conectar con endpoint o email de soporte
    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      setState(() {
        _enviando = false;
        _enviado  = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
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
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent_rounded,
                        color: AppColors.primary, size: 22),
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

                    // ── Formulario (visible solo si hay tipo seleccionado) ──
                    if (_tipoSeleccionado != null) ...[
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _enviado
                            ? _buildConfirmacion()
                            : _buildFormulario(),
                      ),
                    ] else
                      _buildEstadoInicial(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

  // ── Confirmación de envío ──────────────────────────────────────────────────
  Widget _buildConfirmacion() {
    return Container(
      key: const ValueKey('confirmacion'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 32),
          ),
          const SizedBox(height: 14),
          const Text('¡Solicitud enviada!',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Recibimos tu consulta. Nuestro equipo de soporte\nse pondrá en contacto contigo a la brevedad.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.grayMid, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => setState(() {
              _tipoSeleccionado = null;
              _enviado = false;
              _numeroCtrl.clear();
              _detalleCtrl.clear();
            }),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
            label: const Text('Nueva consulta'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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
