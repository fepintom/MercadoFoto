import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Políticas de uso de Comunidad: el texto completo, el aviso que hay que
/// aceptar la primera vez y el recuerdo de que ya se aceptó.
class PoliticasComunidad {
  PoliticasComunidad._();

  static const _clave = 'comunidad_politicas_v1';

  static Future<bool> aceptadas() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_clave) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _marcar() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_clave, true);
    } catch (_) {}
  }

  /// Lo esencial, para el aviso de la primera vez.
  static const resumen = [
    (Icons.sentiment_very_dissatisfied_rounded, 'Sin insultos ni groserías',
        'Trata a todos con respeto, aunque no estés de acuerdo.'),
    (Icons.gpp_bad_rounded, 'Sin amenazas',
        'Nada de amenazar, intimidar ni pedir la dirección de nadie.'),
    (Icons.do_not_disturb_on_rounded, 'Sin drogas',
        'No se habla, compra ni vende ningún tipo de droga.'),
    (Icons.smart_toy_rounded, 'El bot de OkVenta revisa el chat',
        'Los mensajes que no cumplan se censuran al instante y el equipo de '
            'OkVenta puede suspender la cuenta.'),
  ];

  /// La primera vez que se entra a Comunidad: hay que aceptar para
  /// escribir. Devuelve true si aceptó (o ya había aceptado).
  static Future<bool> pedirAceptacion(BuildContext context) async {
    if (await aceptadas()) return true;
    if (!context.mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        title: Text('Bienvenido a Comunidad',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Para participar debes aceptar las políticas de uso de '
                  'la app:',
                  style: TextStyle(
                      fontSize: 13.5, height: 1.35, color: colors.textPrimary)),
              const SizedBox(height: 12),
              for (final r in resumen) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(r.$1, size: 20, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.$2,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary)),
                        Text(r.$3,
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.3,
                                color: colors.textSecondary)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
              ],
              GestureDetector(
                onTap: () => abrir(ctx),
                child: Text('Leer las políticas de uso completas',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: colors.primary)),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Ahora no',
                style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Acepto',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok == true) await _marcar();
    return ok == true;
  }

  static Future<void> abrir(BuildContext context) => Navigator.of(context,
          rootNavigator: true)
      .push(MaterialPageRoute(builder: (_) => const PoliticasComunidadScreen()));
}

class PoliticasComunidadScreen extends StatelessWidget {
  const PoliticasComunidadScreen({super.key});

  static const _secciones = [
    (
      '1. Respeto',
      'Comunidad es un espacio para comprar, vender, preguntar y ayudarse. '
          'No se permiten insultos, groserías, burlas, discriminación ni '
          'ataques personales, ni siquiera "en broma".'
    ),
    (
      '2. Amenazas y seguridad',
      'Está prohibido amenazar, intimidar o acosar a otra persona, publicar '
          'o pedir su dirección, o insinuar que se le va a hacer daño. Para '
          'compartir dónde estás usa "Estoy por aquí", que muestra una zona '
          'aproximada y no tu dirección exacta.'
    ),
    (
      '3. Drogas y productos prohibidos',
      'No se puede hablar de comprar, vender, conseguir ni consumir drogas '
          'ni medicamentos de venta con receta, ni ofrecer productos ilegales.'
    ),
    (
      '4. Estafas y spam',
      'No publiques ofertas falsas, cadenas, enlaces engañosos ni pidas pagos '
          'por fuera de OkVenta: dentro de la app tu compra va protegida.'
    ),
    (
      '5. Cómo se revisa',
      'El bot de OkVenta revisa cada mensaje al momento de enviarlo. Si '
          'trae insultos, amenazas o habla de drogas, se censura de inmediato '
          'y nadie más lo ve: queda la marca "Censurado por políticas de '
          'uso". Además cualquier persona puede denunciar un mensaje desde su '
          'menú ⌄; el mensaje denunciado se oculta mientras el equipo de '
          'OkVenta lo revisa.'
    ),
    (
      '6. Consecuencias',
      'Los mensajes censurados quedan guardados para revisión. Quien '
          'incumpla las políticas de forma repetida o grave puede perder el '
          'acceso a Comunidad o su cuenta de OkVenta.'
    ),
    (
      '7. Tus datos',
      'Lo que escribes en Comunidad lo ven todos los usuarios. No compartas '
          'datos personales, bancarios ni claves en el chat público; para '
          'eso usa los mensajes privados o el chat de cada compra.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: const Text('Políticas de uso',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          Text('Comunidad OkVenta',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: colors.primary)),
          const SizedBox(height: 6),
          Text(
              'Al participar en Comunidad aceptas estas reglas. Están para '
              'que todos puedan comprar y vender tranquilos.',
              style: TextStyle(
                  fontSize: 14, height: 1.4, color: colors.textPrimary)),
          const SizedBox(height: 16),
          for (final s in _secciones) ...[
            Text(s.$1,
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary)),
            const SizedBox(height: 4),
            Text(s.$2,
                style: TextStyle(
                    fontSize: 14, height: 1.45, color: colors.textSecondary)),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
