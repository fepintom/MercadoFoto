import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/ok_delivery_stamp.dart';

/// Reemplaza temporalmente el acceso a DeliveryRegistroScreen mientras
/// OkVenta Delivery está en pausa (sin equipo de repartidores propio).
/// No permite continuar al formulario de registro real — ese código queda
/// intacto en delivery_registro_screen.dart para cuando se reactive.
class DeliveryProximamenteScreen extends StatelessWidget {
  const DeliveryProximamenteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text('OkVenta Delivery',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const OkDeliveryStamp(size: 220),
                const SizedBox(height: 32),
                Text(
                  'Próximamente',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary),
                ),
                const SizedBox(height: 12),
                Text(
                  'Reclutaremos al mejor equipo de delivery de cada región '
                  'y te entregaremos tus productos en 24 horas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14.5,
                      color: colors.grayMid,
                      height: 1.5),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(
                          color: colors.primary.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Volver',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
