import 'package:flutter/material.dart';

import '../screens/perfil_comercio_screen.dart';
import '../services/comercio_service.dart';

/// Insignia "Verificado" (comercio verificado por OkVenta): pastilla con el
/// check azul. Tocarla abre el perfil del comercio. Solo aparece si el
/// vendedor [userId] está verificado (se reconstruye sola cuando se
/// cargan los verificados).
class InsigniaComercio extends StatelessWidget {
  final dynamic userId;
  final bool grande;

  /// Espacio alrededor (solo cuando la insignia se muestra).
  final EdgeInsets margen;

  const InsigniaComercio({
    super.key,
    required this.userId,
    this.grande = false,
    this.margen = EdgeInsets.zero,
  });

  static const Color azul = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ComercioService.cambios,
      builder: (context, _, __) {
        if (!ComercioService.es(userId)) return const SizedBox.shrink();
        final id = userId is num
            ? (userId as num).toInt()
            : int.parse('$userId');
        return Padding(
          padding: margen,
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PerfilComercioScreen(userId: id)),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: grande ? 9 : 6, vertical: grande ? 4 : 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.verified_rounded, size: grande ? 16 : 13, color: azul),
              SizedBox(width: grande ? 4 : 3),
              Text('Verificado',
                  style: TextStyle(
                      fontSize: grande ? 13 : 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1C1C1E))),
            ]),
          ),
        ),
        );
      },
    );
  }
}
