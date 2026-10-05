import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Los favoritos del usuario, en memoria y compartidos por toda la app.
///
/// El corazón está en cada tarjeta de OkMarket: preguntar al servidor
/// "¿es favorito?" por cada una serían decenas de consultas. En cambio se
/// trae la lista de ids una vez (GET /favoritos/{user_id}) y las tarjetas
/// escuchan [ids]. Al tocar un corazón se cambia al instante y, si el
/// servidor falla, se revierte.
class FavoritosService {
  FavoritosService._();

  static final ValueNotifier<Set<int>> ids = ValueNotifier<Set<int>>({});
  static int? _cargadoPara;

  static bool es(int? publicacionId) =>
      publicacionId != null && ids.value.contains(publicacionId);

  static Future<void> cargar(int userId, {bool forzar = false}) async {
    if (!forzar && _cargadoPara == userId) return;
    try {
      final r = await http
          .get(Uri.parse('${ApiService.baseUrl}/favoritos/$userId'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return;
      final lista = jsonDecode(utf8.decode(r.bodyBytes));
      if (lista is List) {
        ids.value = {for (final x in lista) if (x is num) x.toInt()};
        _cargadoPara = userId;
      }
    } catch (_) {}
  }

  /// Marca o desmarca. Devuelve el estado final (true = es favorito).
  static Future<bool> alternar(int userId, int publicacionId) async {
    final antes = es(publicacionId);
    _poner(publicacionId, !antes);
    try {
      if (antes) {
        await ApiService.quitarFavorito(userId, publicacionId);
      } else {
        await ApiService.guardarFavorito(userId, publicacionId);
      }
      return !antes;
    } catch (_) {
      _poner(publicacionId, antes);
      return antes;
    }
  }

  /// Para que otra pantalla (el detalle) avise un cambio que ya hizo.
  static void marcar(int publicacionId, bool favorito) =>
      _poner(publicacionId, favorito);

  static void _poner(int id, bool fav) {
    final s = Set<int>.from(ids.value);
    fav ? s.add(id) : s.remove(id);
    ids.value = s;
  }
}
