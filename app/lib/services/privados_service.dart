import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Mensajes privados entre usuarios (se abren tocando a alguien en
/// Comunidad o desde Mensajes → Privados).
class PrivadosService {
  PrivadosService._();

  static Future<Map<String, dynamic>?> enviar({
    required int deId,
    required int paraId,
    String texto = '',
    double? lat,
    double? lng,
  }) async {
    try {
      final r = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/privados/enviar'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'de_id': deId,
              'para_id': paraId,
              'texto': texto,
              if (lat != null && lng != null) ...{'lat': lat, 'lng': lng},
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(r.bodyBytes)) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _lista(String ruta) async {
    try {
      final r = await http
          .get(Uri.parse('${ApiService.baseUrl}$ruta'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return [];
      return (jsonDecode(utf8.decode(r.bodyBytes)) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> conversacion(int yo, int otro,
          {int despuesDe = 0}) =>
      _lista('/privados/$yo/con/$otro?despues_de=$despuesDe');

  static Future<List<Map<String, dynamic>>> conversaciones(int yo) =>
      _lista('/privados/$yo/conversaciones');
}
