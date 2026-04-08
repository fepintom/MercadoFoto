import 'dart:convert';
import 'package:flutter/material.dart';

import '../services/api_service.dart';

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

  Widget badgeEstado(String estado) {
    Color color = Colors.green;

    if (estado == "vendido") color = Colors.red;
    if (estado == "reservado") color = Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagen = "${ApiService.baseUrl}${producto["imagen_url"]}";
    final estado = producto["estado"] ?? "disponible";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          /// IMAGEN
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imagen,
              width: 85,
              height: 85,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(width: 12),

          /// INFO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safeDecode(producto["titulo"]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text("\$${producto["precio"]}"),
                const SizedBox(height: 6),
                badgeEstado(estado),
              ],
            ),
          ),

          /// ACCIONES
          PopupMenuButton<String>(
            onSelected: onAction,
            itemBuilder: (_) => const [
              PopupMenuItem(value: "vendido", child: Text("Marcar vendido")),
              PopupMenuItem(value: "activar", child: Text("Reactivar")),
            ],
          ),
        ],
      ),
    );
  }
}
