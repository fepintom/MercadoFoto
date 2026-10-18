import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Medios de pago aceptados en OkVenta (Visa, Mastercard, Mercado Pago,
/// Webpay) con su "Ver todos". Es la misma sección del detalle de producto,
/// separada para usarla también en el detalle de servicios.
class MediosPago extends StatelessWidget {
  /// Texto de la última fila del "Ver todos" (producto vs. servicio).
  final String proteccionTitulo;
  final String proteccionDetalle;

  const MediosPago({
    super.key,
    this.proteccionTitulo = 'Siempre con Compra protegida',
    this.proteccionDetalle =
        'El pago se hace dentro de OkVenta y el vendedor recibe el dinero solo cuando confirmas que te llegó.',
  });

  static List<Widget> tarjetas() => [
        _visa(),
        _mastercard(),
        _mercadoPago(),
        _webpay(),
      ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Medios de pago',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _verTodos(context),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Ver todos',
                    style:
                        TextStyle(fontSize: 12.5, color: colors.textPrimary)),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: colors.textPrimary),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: tarjetas()),
      ],
    );
  }

  void _verTodos(BuildContext context) {
    hojaInfo(context, 'Medios de pago', [
      Wrap(spacing: 8, runSpacing: 8, children: tarjetas()),
      const SizedBox(height: 18),
      filaInfo(Icons.credit_card_rounded, 'Tarjetas de crédito',
          'Visa, Mastercard y otras. Puedes pagar en cuotas según tu banco.'),
      filaInfo(Icons.account_balance_outlined, 'Débito y Webpay',
          'Pagas con tu tarjeta de débito o cuenta bancaria.'),
      filaInfo(Icons.account_balance_wallet_outlined, 'Mercado Pago',
          'Con el saldo de tu cuenta de Mercado Pago.'),
      filaInfo(Icons.verified_user_outlined, proteccionTitulo,
          proteccionDetalle),
    ]);
  }

  // ── Piezas reutilizables para hojas informativas ─────────────────────────

  static Widget filaInfo(IconData icono, String titulo, String detalle) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 22, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(detalle,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: colors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      );

  /// Hoja inferior con título y contenido desplazable.
  static void hojaInfo(
      BuildContext context, String titulo, List<Widget> contenido) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
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
                const SizedBox(height: 16),
                Text(titulo,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary)),
                const SizedBox(height: 14),
                ...contenido,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tarjetas ─────────────────────────────────────────────────────────────

  static BoxDecoration _deco(Color color) => BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
        ),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      );

  static Widget _visa() => Container(
        width: 34,
        height: 24,
        alignment: Alignment.center,
        decoration: _deco(const Color(0xFF1A1F71)),
        child: const Text('VISA',
            style: TextStyle(
                fontSize: 9,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Colors.white)),
      );

  static Widget _mastercard() => Container(
        width: 34,
        height: 24,
        alignment: Alignment.center,
        decoration: _deco(const Color(0xFF232323)),
        child: SizedBox(
          width: 20,
          height: 12,
          child: Stack(children: [
            Positioned(
              left: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                    color: Color(0xFFEB001B), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: const Color(0xFFFF5F00).withOpacity(0.92),
                    shape: BoxShape.circle),
              ),
            ),
          ]),
        ),
      );

  static Widget _mercadoPago() => Container(
        width: 38,
        height: 28,
        alignment: Alignment.center,
        decoration: _deco(const Color(0xFF00AEEF)),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.handshake_rounded, size: 10, color: Color(0xFFFFE600)),
          Text('Mercado',
              style: TextStyle(
                  fontSize: 6,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          Text('Pago',
              style: TextStyle(
                  fontSize: 6,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ]),
      );

  static Widget _webpay() => Container(
        width: 38,
        height: 24,
        alignment: Alignment.center,
        decoration: _deco(const Color(0xFF2E3092)),
        child: const Text('webpay',
            style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
                color: Colors.white)),
      );
}

/// Políticas de un servicio: las que escribe el proveedor al publicar
/// (o editar) + las generales de OkVenta, que aplican siempre.
class PoliticasServicio {
  /// Sugerencia para el botón "Usar plantilla" del formulario.
  static const plantilla =
      '• Incluye: (describe qué incluye el servicio)\n'
      '• No incluye: materiales / repuestos, salvo que se indique en la cotización.\n'
      '• Garantía del trabajo: 30 días por la misma falla.\n'
      '• Reagendar o cancelar: avisar con al menos 24 horas.\n'
      '• Visita técnica / diagnóstico: se descuenta si contratas el trabajo.';

  static void mostrar(BuildContext context, String politicasProveedor) {
    final propias = politicasProveedor.trim();
    MediosPago.hojaInfo(context, 'Políticas del servicio', [
      Text('Del proveedor',
          style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary)),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider, width: 0.5),
        ),
        child: Text(
            propias.isEmpty
                ? 'El proveedor no agregó políticas propias. Pregúntale por '
                    'garantía, materiales y cancelación antes de aceptar la '
                    'cotización.'
                : propias,
            style: TextStyle(
                fontSize: 13.5, height: 1.45, color: colors.textPrimary)),
      ),
      const SizedBox(height: 20),
      Text('De OkVenta (siempre aplican)',
          style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary)),
      const SizedBox(height: 12),
      MediosPago.filaInfo(Icons.lock_outline_rounded, 'Pago dentro de OkVenta',
          'Pagas la cotización aceptada en la app. Nunca transfieras por fuera: perderías la protección.'),
      MediosPago.filaInfo(Icons.shield_outlined, 'Seguro Garantía',
          'Al pagar, el proveedor recibe el 80 %. El 20 % queda retenido 30 días como garantía del trabajo.'),
      MediosPago.filaInfo(Icons.timer_outlined, 'Cancelación',
          'Puedes cancelar dentro de la primera hora después de pagar y se te devuelve el total.'),
      MediosPago.filaInfo(Icons.support_agent_rounded, 'Reclamos',
          'Si el trabajo no se hizo o quedó mal, reclama la garantía desde la orden y OkVenta media con el proveedor.'),
    ]);
  }

  /// "Servicio protegido": cómo te cuida OkVenta al contratar.
  static void mostrarProteccion(BuildContext context) {
    MediosPago.hojaInfo(context, 'Servicio protegido', [
      MediosPago.filaInfo(Icons.chat_bubble_outline_rounded, '1. Cotiza por el chat',
          'Conversa con el proveedor y recibe su cotización dentro de OkVenta.'),
      MediosPago.filaInfo(Icons.credit_card_rounded, '2. Paga en la app',
          'Con tarjeta, Webpay o Mercado Pago. El pago queda registrado en tu orden.'),
      MediosPago.filaInfo(Icons.shield_outlined, '3. Garantía de 30 días',
          'El 20 % del pago queda retenido 30 días. Si hay un problema, reclamas desde la orden.'),
      MediosPago.filaInfo(Icons.star_outline_rounded, '4. Califica',
          'Al terminar, calificas al proveedor y ayudas a otros a elegir.'),
    ]);
  }
}
