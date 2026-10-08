import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../screens/historia_viewer_screen.dart';
import 'api_service.dart';
import 'session_service.dart';

/// Historias (24 h) y destacadas.
///
/// [activos] es el conjunto de usuarios con historia vigente: las tarjetas y
/// avatares lo escuchan para encender el anillo de colores. Se recarga al
/// abrir OkMarket/OkServicios y después de publicar.
class HistoriasService {
  HistoriasService._();

  static final ValueNotifier<Set<int>> activos = ValueNotifier<Set<int>>({});

  static bool tiene(int? userId) =>
      userId != null && activos.value.contains(userId);

  static Future<void> cargarActivos() async {
    try {
      final r = await http
          .get(Uri.parse('${ApiService.baseUrl}/historias/activos'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return;
      final l = jsonDecode(utf8.decode(r.bodyBytes));
      if (l is List) {
        activos.value = {for (final x in l) if (x is num) x.toInt()};
      }
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> _lista(String ruta) async {
    try {
      final r = await http
          .get(Uri.parse('${ApiService.baseUrl}$ruta'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return [];
      return List<Map<String, dynamic>>.from(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> deUsuario(int userId) =>
      _lista('/historias/usuario/$userId');

  static Future<List<Map<String, dynamic>>> destacadas(int userId) =>
      _lista('/historias/destacadas/$userId');

  /// Publica una historia. Devuelve un mensaje de error o null si salió bien.
  static Future<String?> subir(int userId, File foto, String texto) async {
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('${ApiService.baseUrl}/historias'))
        ..fields['user_id'] = '$userId'
        ..fields['texto'] = texto
        ..files.add(await http.MultipartFile.fromPath('archivo', foto.path));
      final res = await http.Response.fromStream(
          await req.send().timeout(const Duration(seconds: 60)));
      if (res.statusCode == 200) {
        activos.value = {...activos.value, userId};
        return null;
      }
      try {
        return (jsonDecode(utf8.decode(res.bodyBytes))['detail'] ?? 'Error')
            .toString();
      } catch (_) {
        return 'No se pudo publicar (${res.statusCode})';
      }
    } catch (_) {
      return 'No se pudo conectar con el servidor';
    }
  }

  static Future<bool> destacar(int historiaId, int userId, bool destacada) async {
    try {
      final r = await http.post(Uri.parse(
          '${ApiService.baseUrl}/historias/$historiaId/destacar?user_id=$userId&destacada=$destacada'));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> borrar(int historiaId, int userId) async {
    try {
      final r = await http.delete(Uri.parse(
          '${ApiService.baseUrl}/historias/$historiaId?user_id=$userId'));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static void contarVista(int historiaId) {
    http
        .post(Uri.parse('${ApiService.baseUrl}/historias/$historiaId/vista'))
        .catchError((_) => http.Response('', 500));
  }

  /// Abre las historias vigentes (o las destacadas) de un usuario.
  /// Devuelve false si no había nada que mostrar.
  static Future<bool> abrir(
    BuildContext context, {
    required int userId,
    required String nombre,
    String? fotoUrl,
    bool soloDestacadas = false,
    List<Map<String, dynamic>>? historias,
    int inicio = 0,
  }) async {
    final lista = historias ??
        (soloDestacadas ? await destacadas(userId) : await deUsuario(userId));
    if (lista.isEmpty || !context.mounted) {
      if (!soloDestacadas) await cargarActivos();
      return false;
    }
    final yo = await SessionService.obtenerUser();
    if (!context.mounted) return false;
    await Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => HistoriaViewerScreen(
        historias: lista,
        nombre: nombre,
        fotoUrl: fotoUrl,
        esMio: yo != null && yo == userId,
        miUserId: yo,
        inicio: inicio,
      ),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    ));
    return true;
  }
}
