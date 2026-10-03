import 'package:flutter/material.dart';

import '../services/theme_service.dart';

/// Etiqueta "OFERTA -20%" junto al precio.
///
/// Negra en modo claro y blanca en modo oscuro (se invierte para que nunca
/// se pierda contra el fondo). No es roja a propósito: el rojo ya significa
/// acción (Publicar), filtro puesto y "Usado"; una oferta roja competiría
/// con todo eso. El negro se lee como "precio especial" (Black Friday) y
/// resalta justamente por ser el único elemento oscuro de la tarjeta.
///
/// El % viene del servidor (`descuento_pct`): se calcula con el precio que
/// tenía la publicación antes de que el vendedor lo bajara.
class EtiquetaOferta extends StatelessWidget {
  final int pct;

  /// Versión chica para las tarjetas de la grilla.
  final bool compacta;

  const EtiquetaOferta({super.key, required this.pct, this.compacta = false});

  /// % de descuento de una publicación, o 0.
  static int de(Map p) {
    final v = p['descuento_pct'];
    return v is num ? v.toInt() : 0;
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = ThemeService.isDarkMode;
    final fondo = oscuro ? Colors.white : const Color(0xFF111111);
    final texto = oscuro ? const Color(0xFF111111) : Colors.white;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compacta ? 5 : 8, vertical: compacta ? 2 : 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(compacta ? 4 : 6),
      ),
      child: Text(
        'OFERTA -$pct%',
        maxLines: 1,
        style: TextStyle(
          color: texto,
          fontSize: compacta ? 9 : 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
