import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ¿El producto necesita instalación, y quién la hace?
///
/// Es la bisagra entre las dos mitades de la app. Un producto que necesita
/// instalación crea una necesidad de servicio en el mismo momento de la
/// compra: si el vendedor la ofrece, la venta crece sola; si no, el
/// comprador tiene que encontrar a alguien, y eso es exactamente lo que hay
/// al otro lado, en Servicios.
///
/// Se guardan dos datos y no uno ("requiere" y "la hace el vendedor") porque
/// responden preguntas distintas: el primero le sirve al comprador para
/// saber que hay un trabajo pendiente; el segundo, para saber si ya lo tiene
/// resuelto.
class SelectorInstalacion extends StatelessWidget {
  final bool requiere;
  final bool laHaceVendedor;

  /// Devuelve los dos valores juntos: no pueden quedar en un estado
  /// imposible como "no requiere, pero yo la hago".
  final void Function(bool requiere, bool laHaceVendedor) onChanged;

  const SelectorInstalacion({
    super.key,
    required this.requiere,
    required this.laHaceVendedor,
    required this.onChanged,
  });

  Widget _opcion({
    required bool seleccionado,
    required String texto,
    required IconData icono,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          decoration: BoxDecoration(
            color: seleccionado
                ? colors.primary.withValues(alpha: 0.08)
                : colors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: seleccionado ? colors.primary : colors.divider,
              width: seleccionado ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono,
                  size: 17,
                  color: seleccionado ? colors.primary : colors.grayMid),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  texto,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: seleccionado ? colors.primary : colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Requiere instalación?',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary)),
        const SizedBox(height: 4),
        Text(
          'Por ejemplo un aire acondicionado, un calefont o un mueble que '
          'llega desarmado.',
          style: TextStyle(fontSize: 12, color: colors.grayMid),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _opcion(
              seleccionado: !requiere,
              texto: 'No',
              icono: Icons.check_circle_outline_rounded,
              onTap: () => onChanged(false, false),
            ),
            const SizedBox(width: 10),
            _opcion(
              seleccionado: requiere,
              texto: 'Sí',
              icono: Icons.handyman_outlined,
              onTap: () => onChanged(true, laHaceVendedor),
            ),
          ],
        ),

        // La segunda pregunta solo aparece si la primera es "sí": preguntar
        // quién instala algo que no se instala no tiene sentido.
        if (requiere) ...[
          const SizedBox(height: 16),
          Text('¿La haces tú?',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary)),
          const SizedBox(height: 10),
          Row(
            children: [
              _opcion(
                seleccionado: laHaceVendedor,
                texto: 'Sí, yo instalo',
                icono: Icons.build_circle_outlined,
                onTap: () => onChanged(true, true),
              ),
              const SizedBox(width: 10),
              _opcion(
                seleccionado: !laHaceVendedor,
                texto: 'No, la hace otro',
                icono: Icons.person_search_outlined,
                onTap: () => onChanged(true, false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 15, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    laHaceVendedor
                        ? 'Tu publicación dirá que tú también lo instalas. '
                            'Puedes publicar ese trabajo en Servicios para '
                            'que te contraten aunque el producto lo compren '
                            'en otra parte.'
                        : 'Tu publicación avisará que necesita instalación, '
                            'y el comprador podrá buscar quién se la haga en '
                            'Servicios.',
                    style: TextStyle(
                        fontSize: 11.5, color: colors.textSecondary, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
