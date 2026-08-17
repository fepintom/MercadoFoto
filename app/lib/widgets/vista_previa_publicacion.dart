import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

// ── Vista previa de la publicación (antes de publicar) ─────────────────────
// Reproduce visualmente cómo se verá el producto para otros usuarios, usando
// las fotos e info que el vendedor ya cargó en el formulario. No es
// interactiva (no hay chat, ofertas ni edición): es solo una previsualización
// de solo lectura.
class VistaPreviaPublicacion extends StatelessWidget {
  final List<File> imagenes;
  final String titulo;
  final String descripcion;
  final double precio;
  final String categoria;
  final String subcategoria;
  final String condicion;

  const VistaPreviaPublicacion({
    required this.imagenes,
    required this.titulo,
    required this.descripcion,
    required this.precio,
    required this.categoria,
    required this.subcategoria,
    required this.condicion,
  });

  @override
  Widget build(BuildContext context) {
    final bool esNuevo = condicion == 'nuevo';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                    bottom: BorderSide(color: AppColors.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        size: 22, color: AppColors.carbon),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('Vista previa',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.grayMid.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Así lo verán los demás',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.grayMid,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Carrusel de fotos locales
                  AspectRatio(
                    aspectRatio: 1,
                    child: imagenes.isEmpty
                        ? Container(
                            color: AppColors.surface,
                            child: const Icon(Icons.image_outlined,
                                size: 48, color: AppColors.grayMid),
                          )
                        : PageView.builder(
                            itemCount: imagenes.length,
                            itemBuilder: (_, i) => Image.file(
                              imagenes[i],
                              fit: BoxFit.contain,
                              width: double.infinity,
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badges: condición + categoría
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (esNuevo
                                        ? const Color(0xFF34C759)
                                        : Colors.orange)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(esNuevo ? 'Nuevo' : 'Usado',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: esNuevo
                                          ? const Color(0xFF34C759)
                                          : Colors.orange)),
                            ),
                            if (categoria.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                    subcategoria.isNotEmpty
                                        ? '$categoria · $subcategoria'
                                        : categoria,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(titulo,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.divider, width: 0.5),
                          ),
                          child: Text(formatPrecio(precio),
                              style: const TextStyle(
                                  fontSize: 28,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 16),
                        Text(
                          descripcion.isEmpty
                              ? 'Sin descripción'
                              : descripcion,
                          style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
