import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/comercio_service.dart';
import '../theme/app_theme.dart';
import 'verificar_comercio_screen.dart';

/// Pregunta (una vez, al crear el perfil) si el usuario vende como persona
/// o con giro comercial. Con giro, ofrece verificar el comercio.
class TipoCuentaScreen extends StatefulWidget {
  final int userId;
  const TipoCuentaScreen({super.key, required this.userId});

  static String clave(int uid) => 'giro_preguntado_$uid';

  /// Muestra la pregunta si aún no se respondió en este teléfono.
  static Future<void> preguntarSiFalta(BuildContext context, int uid) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(clave(uid)) == true) return;
      // Si ya tiene una verificación o giro en el servidor, no se pregunta.
      final e = await ComercioService.estado(uid);
      if (e != null && (e['tiene_giro'] == true || e['estado'] != 'ninguna')) {
        await p.setBool(clave(uid), true);
        await p.setString('tipo_usuario', 'empresa');
        return;
      }
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => TipoCuentaScreen(userId: uid)),
      );
    } catch (_) {}
  }

  @override
  State<TipoCuentaScreen> createState() => _TipoCuentaScreenState();
}

class _TipoCuentaScreenState extends State<TipoCuentaScreen> {
  bool? _conGiro;

  Future<void> _guardar(bool conGiro) async {
    setState(() => _conGiro = conGiro);
    final p = await SharedPreferences.getInstance();
    await p.setBool(TipoCuentaScreen.clave(widget.userId), true);
    await p.setString('tipo_usuario', conGiro ? 'empresa' : 'persona');
    await ComercioService.guardarGiro(widget.userId, conGiro);
    if (!mounted) return;
    if (!conGiro) Navigator.pop(context);
  }

  Widget _opcion(IconData i, String t, String d, bool conGiro) {
    final sel = _conGiro == conGiro;
    return GestureDetector(
      onTap: () => _guardar(conGiro),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: sel ? colors.primary : colors.divider,
              width: sel ? 2 : 0.8),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Icon(i, color: colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary)),
                const SizedBox(height: 2),
                Text(d,
                    style: TextStyle(
                        fontSize: 13, color: colors.textSecondary)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Ahora no',
                style: TextStyle(color: colors.textSecondary)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text('¿Cómo vendes en OkVenta?',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary)),
            const SizedBox(height: 6),
            Text('Así mostramos tu perfil como corresponde.',
                style: TextStyle(fontSize: 14.5, color: colors.textSecondary)),
            const SizedBox(height: 22),
            _opcion(Icons.person_outline_rounded, 'Como persona',
                'Vendo cosas propias, sin giro comercial.', false),
            _opcion(Icons.storefront_rounded, 'Con giro comercial',
                'Soy pyme o empresa (tengo RUT de empresa o inicio de actividades).',
                true),
            if (_conGiro == true) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FD),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.verified_rounded, color: Color(0xFF1E88E5)),
                      SizedBox(width: 8),
                      Text('Verifica tu comercio',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1C1C1E))),
                    ]),
                    const SizedBox(height: 6),
                    const Text(
                        'Obtén la insignia "Verificado": tus compradores sabrán '
                        'que eres un comercio real y que su compra está segura.',
                        style: TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            color: Color(0xFF3A3A3C))),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const VerificarComercioScreen()),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Verificar ahora'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Más tarde'),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
