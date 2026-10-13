import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/vistas_service.dart';
import '../theme/app_theme.dart';
import 'net_image.dart';
import 'pastilla_etiqueta.dart';

/// Una publicación como fila (foto a la izquierda, texto a la derecha).
/// Se usa cuando el usuario busca por texto: así el nombre se lee completo
/// y se comparan resultados fácil, como en cualquier buscador.
class FilaResultado extends StatelessWidget {
  final String? imagenUrl;
  final IconData iconoSinFoto;
  final String titulo;
  final String precio;
  final Color colorPrecio;
  final bool? esNuevo; // null = no aplica (servicios)
  final String? categoria;
  final String? lugar;
  final int vistas;
  final VoidCallback onTap;
  final Widget? accion;

  /// Botones redondos (corazón, carro, instalación…) bajo la categoría y
  /// la ubicación, como en la tarjeta de la grilla.
  final List<Widget> iconos;

  const FilaResultado({
    super.key,
    required this.imagenUrl,
    required this.titulo,
    required this.precio,
    required this.colorPrecio,
    required this.onTap,
    this.iconoSinFoto = Icons.image_outlined,
    this.esNuevo,
    this.categoria,
    this.lugar,
    this.vistas = 0,
    this.accion,
    this.iconos = const [],
  });

  /// Botón redondo blanco (o de color) para la fila de [iconos].
  static Widget circulo({
    required IconData icono,
    required VoidCallback onTap,
    double tam = 32,
    Color? fondo,
    Color? color,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: tam,
        height: tam,
        decoration: BoxDecoration(
          color: fondo ?? Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 3,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Icon(icono,
            size: tam * 0.55, color: color ?? const Color(0xFF1B2A41)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = (imagenUrl ?? '').trim();
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.divider, width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: url.isEmpty
                      ? Container(
                          color: colors.primary.withValues(alpha: 0.08),
                          child: Icon(iconoSinFoto,
                              color: colors.primary.withValues(alpha: 0.6)),
                        )
                      : NetImage(
                          url.startsWith('http')
                              ? url
                              : '${ApiService.baseUrl}$url',
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título completo (hasta 3 líneas)
                    Text(titulo,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14.5,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(precio,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: colorPrecio)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (esNuevo != null)
                          PastillaEtiqueta.condicion(esNuevo!, conIcono: false),
                        if ((categoria ?? '').isNotEmpty)
                          PastillaEtiqueta.categoria(categoria!,
                              conIcono: false),
                        if ((lugar ?? '').isNotEmpty)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.place_outlined,
                                size: 13, color: colors.textPrimary),
                            const SizedBox(width: 2),
                            Text(lugar!,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: colors.textPrimary)),
                          ]),
                        if (vistas > 0)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.visibility_outlined,
                                size: 13, color: colors.textPrimary),
                            const SizedBox(width: 2),
                            Text(VistasService.formato(vistas),
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: colors.textPrimary)),
                          ]),
                      ],
                    ),
                    if (iconos.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Row(children: [
                        for (var i = 0; i < iconos.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          iconos[i],
                        ],
                      ]),
                    ],
                  ],
                ),
              ),
              if (accion != null) ...[
                const SizedBox(width: 4),
                accion!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
