import 'package:flutter/material.dart';

/// Pastillas de "Nuevo / Usado" y de categoría, iguales en toda la app.
///
/// Colores sólidos y claros con texto oscuro (se leen igual en modo claro y
/// oscuro): Usado en rojo claro (antes naranjo), Nuevo en verde claro y la
/// categoría en gris.
class PastillaEtiqueta extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final Color fondo;
  final bool grande;

  static const Color rojoUsado = Color(0xFFF6A6A4);
  static const Color verdeNuevo = Color(0xFFA9E4B8);
  static const Color grisCategoria = Color(0xFFD5D5DA);
  static const Color _texto = Color(0xFF1C1C1E);

  const PastillaEtiqueta({
    super.key,
    required this.texto,
    required this.fondo,
    this.icono,
    this.grande = false,
  });

  /// Nuevo (verde) / Usado (rojo).
  factory PastillaEtiqueta.condicion(bool esNuevo,
          {bool grande = false, bool conIcono = true}) =>
      PastillaEtiqueta(
        texto: esNuevo ? 'Nuevo' : 'Usado',
        fondo: esNuevo ? verdeNuevo : rojoUsado,
        icono: conIcono
            ? (esNuevo ? Icons.auto_awesome_outlined : Icons.recycling_rounded)
            : null,
        grande: grande,
      );

  /// Categoría (gris).
  factory PastillaEtiqueta.categoria(String texto,
          {bool grande = false, bool conIcono = true}) =>
      PastillaEtiqueta(
        texto: texto,
        fondo: grisCategoria,
        icono: conIcono ? Icons.grid_view_rounded : null,
        grande: grande,
      );

  @override
  Widget build(BuildContext context) {
    final fs = grande ? 13.0 : 10.0;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: grande ? 11 : 5, vertical: grande ? 6 : 1.5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(grande ? 9 : 4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: fs + 2, color: _texto),
            SizedBox(width: grande ? 5 : 3),
          ],
          Flexible(
            child: Text(texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                    fontSize: fs,
                    fontWeight: grande ? FontWeight.w700 : FontWeight.w600,
                    color: _texto)),
          ),
        ],
      ),
    );
  }
}
