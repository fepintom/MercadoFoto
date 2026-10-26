import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Tráfico de la app para los KPIs (tablero de Tableau): aperturas de la
/// app y cambios de pestaña. Sin datos personales: un id anónimo del
/// dispositivo y, si hay sesión, el id de usuario.
class EventosService {
  EventosService._();

  static String? _visitante;
  static DateTime? _ultimaApertura;

  static Future<String> _idDispositivo() async {
    if (_visitante != null) return _visitante!;
    try {
      final p = await SharedPreferences.getInstance();
      var v = p.getString('visitante_id');
      if (v == null) {
        final r = math.Random.secure();
        v = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
        await p.setString('visitante_id', v);
      }
      _visitante = v;
      return v;
    } catch (_) {
      return 'desconocido';
    }
  }

  static Future<void> registrar(String evento, {String? detalle}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final uid = p.getInt('user_id');
      await http
          .post(Uri.parse('${ApiService.baseUrl}/eventos'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'evento': evento,
                'visitante': await _idDispositivo(),
                if (uid != null) 'user_id': uid,
                'plataforma': Platform.isIOS ? 'ios' : 'android',
                if (detalle != null) 'detalle': detalle,
              }))
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Apertura de la app (al iniciar y al volver desde segundo plano, como
  /// mucho una vez cada 30 min para no inflar la cifra).
  static void appAbierta() {
    final u = _ultimaApertura;
    if (u != null && DateTime.now().difference(u).inMinutes < 30) return;
    _ultimaApertura = DateTime.now();
    registrar('app_abierta');
  }
}
