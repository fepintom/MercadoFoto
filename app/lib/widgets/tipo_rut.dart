import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/verificar_comercio_screen.dart';
import '../services/comercio_service.dart';
import '../theme/app_theme.dart';

/// "Tipo de contribuyente" (Mi OkVenta): persona natural, persona con giro
/// comercial o pyme/empresa. Con giro o empresa se ofrece la verificación
/// del comercio (formulario "Verificar mi comercio").
class TipoRut {
  TipoRut._();

  static const persona = 'persona';
  static const giro = 'giro';
  static const empresa = 'empresa';

  static const opciones = <(String, String, String, IconData)>[
    (persona, 'Persona natural', 'Vendo cosas propias, sin giro comercial.',
        Icons.person_outline_rounded),
    (giro, 'Persona con giro comercial',
        'Persona natural con inicio de actividades en el SII.',
        Icons.badge_outlined),
    (empresa, 'Pyme o empresa', 'Vendo con el RUT de mi empresa.',
        Icons.storefront_rounded),
  ];

  static String nombre(String tipo) =>
      opciones.firstWhere((o) => o.$1 == tipo, orElse: () => opciones.first).$2;

  /// Lee el tipo guardado (compatible con el antiguo 'tipo_usuario').
  static Future<String> actual() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString('tipo_rut');
    if (t != null) return t;
    return p.getString('tipo_usuario') == 'empresa' ? giro : persona;
  }

  static Future<void> guardar(String tipo) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('tipo_rut', tipo);
    await p.setString('tipo_usuario', tipo == persona ? 'persona' : 'empresa');
    final uid = p.getInt('user_id');
    if (uid != null) {
      await p.setBool('giro_preguntado_$uid', true);
      await ComercioService.guardarTipoRut(uid, tipo);
    }
  }

  /// Hoja para elegir el tipo. Devuelve el tipo elegido (o null).
  static Future<String?> abrir(BuildContext context) async {
    var sel = await actual();
    if (!context.mounted) return null;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setHoja) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
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
                const SizedBox(height: 14),
                Text('Tipo de contribuyente',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary)),
                const SizedBox(height: 4),
                Text('Cómo vendes en OkVenta según tu RUT.',
                    style: TextStyle(
                        fontSize: 13, color: colors.textSecondary)),
                const SizedBox(height: 14),
                for (final (id, titulo, detalle, icono) in opciones)
                  GestureDetector(
                    onTap: () async {
                      setHoja(() => sel = id);
                      await guardar(id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color:
                                sel == id ? colors.primary : colors.divider,
                            width: sel == id ? 2 : 0.8),
                      ),
                      child: Row(children: [
                        Icon(icono, color: colors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(titulo,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary)),
                              Text(detalle,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: colors.textSecondary)),
                            ],
                          ),
                        ),
                        Icon(
                            sel == id
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: sel == id
                                ? colors.primary
                                : colors.grayMid),
                      ]),
                    ),
                  ),
                if (sel != persona) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(ctx, sel);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VerificarComercioScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F1FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(children: [
                        Icon(Icons.verified_rounded, color: Color(0xFF1E88E5)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              'Verifica tu comercio y obtén la insignia "Verificado"',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1C1C1E))),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF1E88E5)),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, sel),
                    child: const Text('Listo'),
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
