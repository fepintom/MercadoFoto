import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'session_service.dart';

/// Visualizaciones (👁) de productos y servicios.
///
/// Se cuenta una vista al abrir el detalle. El servidor cuenta como máximo
/// una por persona y por día y no cuenta al dueño. Quien no ha iniciado
/// sesión se identifica con un id anónimo guardado en el teléfono.
class VistasService {
  VistasService._();

  static const _kAnonimo = 'vistas_anonimo';

  static Future<String> _visitante() async {
    final uid = await SessionService.obtenerUser();
    if (uid != null) return '$uid';
    final prefs = await SharedPreferences.getInstance();
    var anon = prefs.getString(_kAnonimo);
    if (anon == null) {
      final r = Random.secure();
      anon = 'anon-${List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join()}';
      await prefs.setString(_kAnonimo, anon);
    }
    return anon;
  }

  /// Cuenta la vista y devuelve el total (null si falló).
  static Future<int?> contar(String tipo, int? itemId) async {
    if (itemId == null) return null;
    try {
      final v = await _visitante();
      final r = await http
          .post(Uri.parse('${ApiService.baseUrl}/vistas'
              '?tipo=$tipo&item_id=$itemId&visitante=${Uri.encodeQueryComponent(v)}'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      return (jsonDecode(r.body)['vistas'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// Los productos más vistos (para Comunidad).
  static Future<List<Map<String, dynamic>>> topProductos({int limite = 5}) async {
    try {
      final r = await http
          .get(Uri.parse(
              '${ApiService.baseUrl}/vistas/top_productos?limite=$limite'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      return (jsonDecode(r.body) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// "1,2 mil" en vez de 1200, para que quepa en la tarjeta.
  static String formato(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k < 10 ? 1 : 0).replaceAll('.', ',')} mil';
    }
    final m = n / 1000000;
    return '${m.toStringAsFixed(1).replaceAll('.', ',')} M';
  }
}

/// Pastilla "👁 123" para poner sobre una foto.
class EtiquetaVistas extends StatelessWidget {
  final int vistas;
  final double tam;
  const EtiquetaVistas({super.key, required this.vistas, this.tam = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.visibility_outlined, size: tam + 1, color: Colors.white),
        const SizedBox(width: 3),
        Text(VistasService.formato(vistas),
            style: TextStyle(
                fontSize: tam,
                color: Colors.white,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
