import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/net_image.dart';

// ── Vista previa de la publicación (antes de publicar / al editar) ─────────
// Reproduce visualmente cómo se verá el producto para otros usuarios, usando
// las fotos e info que el vendedor ya cargó en el formulario. No es
// interactiva (no hay chat, ofertas ni edición): es solo una previsualización
// de solo lectura.
//
// Admite dos tipos de fotos a la vez: locales recién tomadas (`imagenes`,
// archivos en el dispositivo) y ya existentes en el servidor (`imagenesUrl`,
// rutas relativas resueltas con `baseUrl`) — esto último es lo que necesita
// la pantalla de edición, donde la mayoría de las fotos ya están subidas y
// solo algunas pueden ser nuevas.
class VistaPreviaPublicacion extends StatelessWidget {
  final List<File> imagenes;
  final List<String> imagenesUrl;
  final String? baseUrl;
  final String titulo;
  final String descripcion;
  final double precio;
  final String categoria;
  final String subcategoria;
  final String condicion;

  const VistaPreviaPublicacion({
    this.imagenes = const [],
    this.imagenesUrl = const [],
    this.baseUrl,
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
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                    bottom: BorderSide(color: colors.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded,
                        size: 22, color: colors.textPrimary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('Vista previa',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.grayMid.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Así lo verán los demás',
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.grayMid,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Carrusel de fotos (existentes en el servidor + locales nuevas)
                  AspectRatio(
                    aspectRatio: 1,
                    child: (imagenesUrl.isEmpty && imagenes.isEmpty)
                        ? Container(
                            color: colors.surface,
                            child: Icon(Icons.image_outlined,
                                size: 48, color: colors.grayMid),
                          )
                        : PageView.builder(
                            itemCount: imagenesUrl.length + imagenes.length,
                            itemBuilder: (_, i) {
                              if (i < imagenesUrl.length) {
                                return NetImage(
                                  "${baseUrl ?? ''}${imagenesUrl[i]}",
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                );
                              }
                              return Image.file(
                                imagenes[i - imagenesUrl.length],
                                fit: BoxFit.contain,
                                width: double.infinity,
                              );
                            },
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
                                        ? colors.success
                                        : colors.warning)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(esNuevo ? 'Nuevo' : 'Usado',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: esNuevo
                                          ? colors.success
                                          : colors.warning,
                                      shadows: const [
                                        Shadow(
                                            color: Colors.black26,
                                            blurRadius: 1.5,
                                            offset: Offset(0, 0.4)),
                                      ])),
                            ),
                            if (categoria.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                    subcategoria.isNotEmpty
                                        ? '$categoria · $subcategoria'
                                        : categoria,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colors.primary,
                                        fontWeight: FontWeight.w500,
                                        shadows: [
                                          Shadow(
                                              color: Colors.black26,
                                              blurRadius: 1.5,
                                              offset: Offset(0, 0.4)),
                                        ])),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(titulo,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: colors.divider, width: 0.5),
                          ),
                          child: Text(formatPrecio(precio),
                              style: TextStyle(
                                  fontSize: 28,
                                  color: colors.primary,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1, thickness: 0.5),
                        const SizedBox(height: 16),
                        Text(
                          descripcion.isEmpty
                              ? 'Sin descripción'
                              : descripcion,
                          style: TextStyle(
                              fontSize: 15,
                              color: colors.textSecondary,
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
