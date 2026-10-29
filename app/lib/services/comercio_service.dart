import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Verificación de comercios (pymes y empresas con giro comercial).
///
/// - [verificados]: ids de vendedores con la insignia "Comercio
///   verificado". Se carga al abrir la app y se refresca cada 10 min; las
///   tarjetas preguntan [es] para pintar la insignia (sin tocar cada
///   endpoint de productos).
/// - [estado] / [enviar] / [guardarGiro]: el formulario "Verificar mi
///   comercio".
/// - [perfil]: perfil público del comercio (al tocar la insignia).
class ComercioService {
  ComercioService._();

  static Set<int> verificados = {};
  static final ValueNotifier<int> cambios = ValueNotifier<int>(0);
  static DateTime? _ultimaCarga;

  static bool es(dynamic userId) {
    final id = userId is num ? userId.toInt() : int.tryParse('$userId');
    return id != null && verificados.contains(id);
  }

  static Future<void> cargarVerificados({bool forzar = false}) async {
    final u = _ultimaCarga;
    if (!forzar &&
        u != null &&
        DateTime.now().difference(u) < const Duration(minutes: 10)) {
      return;
    }
    try {
      final r = await http
          .get(Uri.parse('${ApiService.baseUrl}/comercios/verificados'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return;
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      verificados = {
        for (final x in (d['ids'] as List? ?? [])) (x as num).toInt()
      };
      _ultimaCarga = DateTime.now();
      cambios.value++;
    } catch (_) {}
  }

  static Future<void> guardarGiro(int userId, bool tieneGiro) async {
    try {
      await http.put(
        Uri.parse('${ApiService.baseUrl}/usuarios/$userId/giro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tiene_giro': tieneGiro}),
      );
    } catch (_) {}
  }

  /// Tipo de contribuyente: 'persona' | 'giro' | 'empresa'.
  static Future<void> guardarTipoRut(int userId, String tipo) async {
    try {
      await http.put(
        Uri.parse('${ApiService.baseUrl}/usuarios/$userId/giro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tipo_rut': tipo}),
      );
    } catch (_) {}
  }

  /// {tiene_giro, verificado, estado: ninguna|pendiente|aprobada|rechazada,
  ///  motivo_rechazo, datos}
  static Future<Map<String, dynamic>?> estado(int userId) async {
    try {
      final r = await http.get(
          Uri.parse('${ApiService.baseUrl}/comercio/verificacion/$userId'));
      if (r.statusCode != 200) return null;
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> perfil(int userId) async {
    try {
      final r = await http.get(
          Uri.parse('${ApiService.baseUrl}/comercios/$userId/perfil'));
      if (r.statusCode != 200) return null;
      return Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {
      return null;
    }
  }

  /// Envía el formulario. Lanza Exception con el mensaje del servidor.
  static Future<void> enviar({
    required int userId,
    required String rut,
    required String razonSocial,
    required String nombreComercial,
    required String direccion,
    String comuna = '',
    double? lat,
    double? lng,
    required File docIdentidad,
    required File docPoderes,
    required File fotoFachada,
    required File fotoLetrero,
    required File fotoInterior,
  }) async {
    final req = http.MultipartRequest(
        'POST', Uri.parse('${ApiService.baseUrl}/comercio/verificacion'));
    req.fields.addAll({
      'user_id': '$userId',
      'rut': rut,
      'razon_social': razonSocial,
      'nombre_comercial': nombreComercial,
      'direccion': direccion,
      'comuna': comuna,
      if (lat != null) 'lat': '$lat',
      if (lng != null) 'lng': '$lng',
    });
    for (final (campo, f) in [
      ('doc_identidad', docIdentidad),
      ('doc_poderes', docPoderes),
      ('foto_fachada', fotoFachada),
      ('foto_letrero', fotoLetrero),
      ('foto_interior', fotoInterior),
    ]) {
      req.files.add(await http.MultipartFile.fromPath(campo, f.path));
    }
    final res = await http.Response.fromStream(
        await req.send().timeout(const Duration(minutes: 3)));
    if (res.statusCode != 200) {
      var msg = 'No se pudo enviar (${res.statusCode})';
      try {
        final d = jsonDecode(utf8.decode(res.bodyBytes));
        if (d is Map && d['detail'] is String) msg = d['detail'] as String;
      } catch (_) {}
      throw Exception(msg);
    }
  }

  // ── RUT ──────────────────────────────────────────────────────────────────

  /// true si el dígito verificador calza.
  static bool rutValido(String rut) {
    final l = rut.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();
    if (l.length < 8 || l.length > 9) return false;
    final cuerpo = l.substring(0, l.length - 1);
    final dv = l[l.length - 1];
    if (int.tryParse(cuerpo) == null) return false;
    var suma = 0, factor = 2;
    for (final ch in cuerpo.split('').reversed) {
      suma += int.parse(ch) * factor;
      factor = factor == 7 ? 2 : factor + 1;
    }
    final resto = 11 - (suma % 11);
    final esperado = resto == 11
        ? '0'
        : resto == 10
            ? 'K'
            : '$resto';
    return dv == esperado;
  }

  /// "761234565" → "76.123.456-5" (mientras se escribe).
  static String formatearRut(String t) {
    final l = t.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();
    if (l.length < 2) return l;
    final cuerpo = l.substring(0, l.length - 1);
    final dv = l[l.length - 1];
    final b = StringBuffer();
    for (var i = 0; i < cuerpo.length; i++) {
      if (i > 0 && (cuerpo.length - i) % 3 == 0) b.write('.');
      b.write(cuerpo[i]);
    }
    return '$b-$dv';
  }
}
