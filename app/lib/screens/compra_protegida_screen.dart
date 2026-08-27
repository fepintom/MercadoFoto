import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Explica qué significa "Compra protegida" en OkVenta y resume, en
/// lenguaje simple, los derechos que ya te da la ley chilena (Ley N° 19.496,
/// normas SERNAC) al comprar por internet: derecho a retracto y garantía
/// legal. No reemplaza el texto legal — es un resumen orientativo.
class CompraProtegidaScreen extends StatelessWidget {
  const CompraProtegidaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 18,
              color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Compra protegida',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_rounded,
                      color: colors.primary, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tus compras en OkVenta están respaldadas por los '
                      'derechos que te da la ley del consumidor en Chile '
                      '(Ley N° 19.496) y las normas de SERNAC.',
                      style: TextStyle(
                          fontSize: 13.5,
                          color: colors.textPrimary,
                          height: 1.4,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            _seccion(
              icono: Icons.assignment_return_outlined,
              titulo: 'Derecho a retracto (10 días)',
              cuerpo:
                  'Como compraste a distancia (por internet), tienes 10 días '
                  'corridos desde que recibes el producto para arrepentirte '
                  'de la compra, sin necesidad de dar una razón, siempre que '
                  'el producto no haya sido usado. Si el vendedor no te '
                  'confirmó por escrito los detalles de la compra, este '
                  'plazo se extiende a 90 días.',
            ),
            _seccion(
              icono: Icons.local_shipping_rounded,
              titulo: 'Devolución gratis: ¿quién paga el envío?',
              cuerpo:
                  'Depende del motivo de la devolución:\n\n'
                  '• Te arrepentiste de la compra (derecho a retracto): el '
                  'envío de vuelta corre por tu cuenta, como comprador. Es '
                  'justo — el vendedor y el repartidor ya cumplieron su '
                  'parte cuando te llegó el producto en buen estado.\n\n'
                  '• El producto llegó defectuoso, incompleto o distinto a '
                  'lo publicado: el envío de vuelta lo paga el vendedor, '
                  'sin costo para ti.\n\n'
                  'En ambos casos, quien haga el viaje de devolución recibe '
                  'su pago completo — valoramos el trabajo de nuestros '
                  'repartidores, así que un viaje ejecutado siempre se paga, '
                  'nunca se descuenta de su bolsillo aunque la devolución '
                  'sea gratis para ti.',
            ),
            _seccion(
              icono: Icons.build_outlined,
              titulo: 'Garantía legal (6 meses)',
              cuerpo:
                  'Si el producto llega con fallas, piezas faltantes o no '
                  'sirve para lo que fue comprado, tienes 6 meses desde la '
                  'compra para reclamar. Puedes elegir entre 3 opciones: '
                  'que te devuelvan el dinero, que te cambien el producto, '
                  'o que te lo reparen sin costo. Esta garantía no cubre '
                  'un simple cambio de opinión ni productos de segunda '
                  'selección informados como tal al comprar.',
            ),
            _seccion(
              icono: Icons.local_shipping_outlined,
              titulo: 'Entrega protegida',
              cuerpo:
                  'El pago queda retenido hasta que confirmes que recibiste '
                  'tu pedido conforme. Si algo no llega o llega dañado, '
                  'puedes reportar el problema desde "Mis compras" y '
                  'OkVenta media la disputa antes de liberar el pago al '
                  'vendedor.',
            ),
            _seccion(
              icono: Icons.support_agent_rounded,
              titulo: '¿Cómo pido una devolución?',
              cuerpo:
                  'Ve a "Mis compras", abre la orden y usa la opción '
                  '"Tuve un problema" o contacta al vendedor por chat para '
                  'coordinar la devolución. Si no llegan a acuerdo, puedes '
                  'escalar el reclamo a OkVenta o directamente a SERNAC.',
            ),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.divider, width: 0.5),
              ),
              child: Text(
                'Este resumen es informativo y no reemplaza el texto legal. '
                'Puedes revisar el detalle completo y hacer una consulta o '
                'reclamo formal en sernac.cl.',
                style: TextStyle(
                    fontSize: 12, color: colors.grayMid, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _seccion({
    required IconData icono,
    required String titulo,
    required String cuerpo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 17, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary)),
                const SizedBox(height: 4),
                Text(cuerpo,
                    style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
