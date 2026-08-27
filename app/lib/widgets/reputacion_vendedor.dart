import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ── Estrellas + promedio, versión compacta ─────────────────────────────────
// Para usar junto al nombre del vendedor en una publicación (detalle,
// tarjeta, etc.). No hace ninguna llamada de red: recibe el promedio y el
// total ya cargados por la pantalla que la usa.
//
// Siempre se muestra (con o sin evaluaciones) — es importante que el
// comprador pueda ver de un vistazo si el vendedor ya ha sido evaluado.
// Sin evaluaciones: 5 estrellas sin pintar + aviso explícito. Con
// evaluaciones: estrellas pintadas de amarillo según el promedio.
class EstrellasResumen extends StatelessWidget {
  final double promedio;
  final int totalReviews;
  final double size;

  const EstrellasResumen({
    super.key,
    required this.promedio,
    required this.totalReviews,
    this.size = 13,
  });

  static const Color _amarilloEstrella = Color(0xFFFFB800);

  @override
  Widget build(BuildContext context) {
    if (totalReviews == 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(
              5,
              (i) => Icon(Icons.star_outline_rounded,
                  size: size, color: colors.grayMid)),
          const SizedBox(width: 4),
          Flexible(
            child: Text('El vendedor aún no ha recibido valoraciones',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: size - 2, color: colors.grayMid)),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final lleno = i < promedio.round();
          return Icon(
              lleno ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: lleno ? _amarilloEstrella : colors.grayMid);
        }),
        const SizedBox(width: 4),
        Text(promedio.toStringAsFixed(1),
            style: TextStyle(
                fontSize: size - 1,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
        const SizedBox(width: 3),
        Text('($totalReviews)',
            style: TextStyle(fontSize: size - 2, color: colors.grayMid)),
      ],
    );
  }
}

// ── Tarjeta completa de reputación ──────────────────────────────────────────
// Barra de 4 tramos (malas/regular/buena/excelente) + lista de comentarios.
// Se muestra en el perfil público del vendedor.
class ReputacionCard extends StatelessWidget {
  final Map<String, dynamic> reputacion;

  const ReputacionCard({super.key, required this.reputacion});

  @override
  Widget build(BuildContext context) {
    final promedio = (reputacion['promedio'] as num?)?.toDouble() ?? 0;
    final total = (reputacion['total_reviews'] as num?)?.toInt() ?? 0;
    final dist = Map<String, dynamic>.from(
        reputacion['distribucion'] as Map? ?? {});
    final comentarios =
        List<dynamic>.from(reputacion['comentarios'] as List? ?? []);

    if (total == 0) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.star_outline_rounded,
                color: colors.grayMid, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Todavía no tiene calificaciones',
                  style: TextStyle(fontSize: 13, color: colors.grayMid)),
            ),
          ],
        ),
      );
    }

    double p(String k) => (dist[k] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (i) {
                final lleno = i < promedio.round();
                return Icon(
                    lleno ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18,
                    color: lleno
                        ? EstrellasResumen._amarilloEstrella
                        : colors.grayMid);
              }),
              const SizedBox(width: 8),
              Text(promedio.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const SizedBox(width: 4),
              Text('· $total ${total == 1 ? "opinión" : "opiniones"}',
                  style: TextStyle(
                      fontSize: 12, color: colors.grayMid)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (p('malas') > 0)
                    Expanded(
                        flex: (p('malas') * 10).round().clamp(1, 1000),
                        child: Container(color: const Color(0xFFE4574C))),
                  if (p('regular') > 0)
                    Expanded(
                        flex: (p('regular') * 10).round().clamp(1, 1000),
                        child: Container(color: const Color(0xFFF0A63B))),
                  if (p('buena') > 0)
                    Expanded(
                        flex: (p('buena') * 10).round().clamp(1, 1000),
                        child: Container(color: const Color(0xFFE9DA5A))),
                  if (p('excelente') > 0)
                    Expanded(
                        flex: (p('excelente') * 10).round().clamp(1, 1000),
                        child: Container(color: const Color(0xFF34C759))),
                ],
              ),
            ),
          ),
          if (comentarios.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 12),
            Text('Comentarios',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary)),
            const SizedBox(height: 8),
            ...comentarios.map((c) => _ComentarioTile(c: c)),
          ],
        ],
      ),
    );
  }
}

class _ComentarioTile extends StatelessWidget {
  final dynamic c;
  const _ComentarioTile({required this.c});

  @override
  Widget build(BuildContext context) {
    final estrellas = (c['estrellas'] as num?)?.toInt() ?? 0;
    final comentario = c['comentario']?.toString() ?? '';
    final nombre = c['nombre_comprador']?.toString() ?? 'Usuario';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                  5,
                  (i) => Icon(
                      i < estrellas
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 12,
                      color: i < estrellas
                          ? EstrellasResumen._amarilloEstrella
                          : colors.grayMid)),
              const SizedBox(width: 6),
              Text(nombre,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary)),
            ],
          ),
          const SizedBox(height: 3),
          Text(comentario,
              style: TextStyle(
                  fontSize: 12.5,
                  color: colors.textPrimary,
                  height: 1.4)),
        ],
      ),
    );
  }
}
