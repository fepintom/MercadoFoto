import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ── Selector de tipo de publicación: "Exprés" o "Full" ──────────────────────
// Exprés: solo los datos principales (título, fotos, precio, condición).
// Full: además pide datos de inventario (SKU, stock, código universal) para
// vendedores que llevan control de stock — típicamente quienes venden varias
// unidades del mismo producto.
//
// Es un poco más grande que los demás controles del formulario (~20% más de
// padding/tipografía) porque es una decisión que afecta todo lo que viene
// después en el formulario, y conviene que se note.
class TipoPublicacionSelector extends StatelessWidget {
  final String tipo; // 'expres' | 'full'
  final ValueChanged<String> onChanged;
  final TextEditingController skuCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController codigoCtrl;

  const TipoPublicacionSelector({
    super.key,
    required this.tipo,
    required this.onChanged,
    required this.skuCtrl,
    required this.stockCtrl,
    required this.codigoCtrl,
  });

  bool get _esFull => tipo == 'full';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo de publicación',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _opcion(
                valor: 'expres',
                titulo: 'Exprés',
                subtitulo: 'Rápida: solo lo esencial',
                icono: Icons.bolt_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _opcion(
                valor: 'full',
                titulo: 'Full',
                subtitulo: 'Con SKU, stock y código',
                icono: Icons.inventory_2_rounded,
              ),
            ),
          ],
        ),
        if (_esFull) ...[
          const SizedBox(height: 16),
          const Text('Datos de inventario',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          _campo(label: 'Código universal', ctrl: codigoCtrl),
          const SizedBox(height: 10),
          _campo(label: 'SKU', ctrl: skuCtrl),
          const SizedBox(height: 10),
          _campo(
            label: 'Stock disponible',
            ctrl: stockCtrl,
            teclado: TextInputType.number,
          ),
        ],
      ],
    );
  }

  Widget _opcion({
    required String valor,
    required String titulo,
    required String subtitulo,
    required IconData icono,
  }) {
    final sel = tipo == valor;
    return GestureDetector(
      onTap: () => onChanged(valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        // ~20% más grande que los chips de condición del mismo formulario.
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary.withOpacity(0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? AppColors.primary : AppColors.divider,
            width: sel ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(icono,
                size: 19, color: sel ? AppColors.primary : AppColors.grayMid),
            const SizedBox(height: 6),
            Text(titulo,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: sel ? AppColors.primary : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5,
                    color: sel ? AppColors.primary : AppColors.grayMid)),
          ],
        ),
      ),
    );
  }

  Widget _campo({
    required String label,
    required TextEditingController ctrl,
    TextInputType teclado = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.grayMid)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: teclado,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
