import 'dart:convert';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ItemProductoWidget extends StatelessWidget {
  final Map producto;
  final Function(String action) onAction;

  const ItemProductoWidget({
    super.key,
    required this.producto,
    required this.onAction,
  });

  String safeDecode(String text) {
    try {
      return utf8.decode(text.codeUnits);
    } catch (_) {
      return text;
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case "vendido":
        return AppColors.primary;
      case "reservado":
        return const Color(0xFFE07B00);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  Widget _badgeEstado(String estado) {
    final color = _colorEstado(estado);
    final label = estado.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagen = "${ApiService.baseUrl}${producto["imagen_url"]}";
    final titulo = safeDecode(producto["titulo"] ?? "");
    final precio = producto["precio"] ?? 0;
    final estado = producto["estado"] ?? "disponible";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Imagen
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imagen,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: AppColors.background,
                  child: const Icon(Icons.image_not_supported,
                      color: AppColors.grayMid),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "\$$precio",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _badgeEstado(estado),
                ],
              ),
            ),

            // Acciones
            PopupMenuButton<String>(
              onSelected: onAction,
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppColors.grayMid),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: "vendido",
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 18, color: AppColors.grayMid),
                      SizedBox(width: 8),
                      Text("Marcar vendido"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: "activar",
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 18, color: AppColors.grayMid),
                      SizedBox(width: 8),
                      Text("Reactivar"),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
