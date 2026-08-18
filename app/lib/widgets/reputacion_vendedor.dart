import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ── Estrellas + promedio, versión compacta ─────────────────────────────────
// Para usar junto al nombre del vendedor en una publicación (detalle,
// tarjeta, etc.). No hace ninguna llamada de red: recibe el promedio y el
// total ya cargados por la pantalla que la usa.
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

  @override
  Widget build(BuildContext context) {
    if (totalReviews == 0) {
      return Text('Sin calificaciones aún',
          style: TextStyle(fontSize: size - 1, color: AppColors.grayMid));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size, color: AppColors.primary),
        const SizedBox(width: 2),
        Text(promedio.toStringAsFixed(1),
            style: TextStyle(
                fontSize: size - 1,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(width: 3),
        Text('($totalReviews)',
            style: TextStyle(fontSize: size - 2, color: AppColors.grayMid)),
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
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.star_outline_rounded,
                color: AppColors.grayMid, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Todavía no tiene calificaciones',
                  style: TextStyle(fontSize: 13, color: AppColors.grayMid)),
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
        border: Border.all(color: AppColors.divider, width: 0.5),
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
                    color: AppColors.primary);
              }),
              const SizedBox(width: 8),
              Text(promedio.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 4),
              Text('· $total ${total == 1 ? "opinión" : "opiniones"}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.grayMid)),
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
            const Text('Comentarios',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
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
                      color: AppColors.primary)),
              const SizedBox(width: 6),
              Text(nombre,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 3),
          Text(comentario,
              style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                  height: 1.4)),
        ],
      ),
    );
  }
}
