import 'package:flutter/material.dart';

import '../screens/agregar_servicio_screen.dart';
import '../theme/app_theme.dart';

/// De qué categoría de servicio es la instalación de un producto.
///
/// Las dos mitades de la app tienen listas de categorías distintas —los
/// productos hablan de "Automotriz" u "Hogar"; los servicios, de
/// "Transporte" o "Electrodomésticos"— así que hay que traducir. Cuando no
/// hay una equivalencia clara queda "Otros", que es honesto: es mejor que
/// el proveedor la corrija a que la app invente una categoría.
String categoriaServicioParaProducto(String categoriaProducto,
    [String subcategoria = '']) {
  final c = categoriaProducto.trim().toLowerCase();
  final sub = subcategoria.trim().toLowerCase();

  if (sub.contains('electrodom')) return 'Electrodomésticos';
  switch (c) {
    case 'construcción':
    case 'construccion':
      return 'Construcción';
    case 'automotriz':
      return 'Transporte';
    case 'electrónica':
    case 'electronica':
    case 'computación':
    case 'computacion':
      return 'Computación';
    case 'hogar':
      return 'Electrodomésticos';
    case 'salud':
      return 'Salud';
    case 'negocios':
      return 'Profesional';
    default:
      return 'Otros';
  }
}

/// Invita al vendedor a publicar en Servicios la instalación que acaba de
/// declarar que hace.
///
/// Se muestra justo después de publicar el producto y no antes: en ese
/// momento el vendedor ya terminó lo que vino a hacer, así que ofrecerle
/// algo más no le interrumpe la tarea. Y es una oferta, no un paso
/// obligatorio: "Ahora no" cierra y sigue.
///
/// Por qué importa: cada producto que necesita instalación crea demanda de
/// un servicio. Si el vendedor que ya sabe instalarlo no lo publica, esa
/// demanda no encuentra a nadie del otro lado. Esto es lo que convierte una
/// venta suelta en dos publicaciones que se alimentan entre sí.
Future<void> ofrecerPublicarInstalacion(
  BuildContext context, {
  required String tituloProducto,
  required String categoriaProducto,
  String subcategoriaProducto = '',
}) async {
  final quiere = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.handyman_rounded,
                    size: 20, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('¡Producto publicado!',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Dijiste que tú haces la instalación. ¿Quieres publicarla '
            'también en Servicios?',
            style: TextStyle(
                fontSize: 14.5, color: colors.textPrimary, height: 1.45),
          ),
          const SizedBox(height: 8),
          Text(
            'Así te pueden contratar aunque el producto lo hayan comprado en '
            'otra parte. Te dejamos el formulario casi listo.',
            style: TextStyle(
                fontSize: 12.5, color: colors.grayMid, height: 1.4),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Publicar mi servicio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Ahora no',
                  style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    ),
  );

  if (quiere != true || !context.mounted) return;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AgregarServicioScreen(
        // El formulario llega escrito, pero editable: el vendedor sabe
        // mejor que nosotros cómo se llama su trabajo.
        tituloInicial: 'Instalación de $tituloProducto',
        descripcionInicial:
            'Instalo $tituloProducto. Cuéntame qué necesitas y te '
            'cotizo el trabajo.',
        categoriaInicial: categoriaServicioParaProducto(
            categoriaProducto, subcategoriaProducto),
      ),
    ),
  );
}
