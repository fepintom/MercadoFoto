import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lo que el usuario pidió no ver: publicaciones marcadas "No me interesa"
/// y vendedores bloqueados. Se guarda en el teléfono.
///
/// Es un primer paso: bloquear aquí esconde sus publicaciones en este
/// dispositivo. Un bloqueo "de verdad" (que tampoco pueda escribirte por
/// chat) necesita guardarse en el servidor; queda para cuando lo pidamos.
class ContenidoOcultoService {
  ContenidoOcultoService._();

  static const _kOcultas = 'oculto_publicaciones';
  static const _kBloqueados = 'oculto_vendedores';

  static final ValueNotifier<Set<int>> publicaciones = ValueNotifier({});
  static final ValueNotifier<Set<int>> vendedores = ValueNotifier({});
  static bool _cargado = false;

  static Future<void> cargar() async {
    if (_cargado) return;
    try {
      final p = await SharedPreferences.getInstance();
      publicaciones.value = _leer(p, _kOcultas);
      vendedores.value = _leer(p, _kBloqueados);
      _cargado = true;
    } catch (_) {}
  }

  static Set<int> _leer(SharedPreferences p, String k) =>
      (p.getStringList(k) ?? const []).map(int.tryParse).whereType<int>().toSet();

  static bool oculta(Map item) {
    final id = item['id'], vend = item['user_id'];
    return (id is int && publicaciones.value.contains(id)) ||
        (vend is int && vendedores.value.contains(vend));
  }

  static Future<void> ocultarPublicacion(int id) =>
      _agregar(publicaciones, _kOcultas, id);
  static Future<void> bloquearVendedor(int id) =>
      _agregar(vendedores, _kBloqueados, id);
  static Future<void> desbloquearVendedor(int id) =>
      _quitar(vendedores, _kBloqueados, id);
  static Future<void> mostrarPublicacion(int id) =>
      _quitar(publicaciones, _kOcultas, id);

  static Future<void> _agregar(
      ValueNotifier<Set<int>> n, String k, int id) async {
    n.value = {...n.value, id};
    await _guardar(n, k);
  }

  static Future<void> _quitar(
      ValueNotifier<Set<int>> n, String k, int id) async {
    n.value = {...n.value}..remove(id);
    await _guardar(n, k);
  }

  static Future<void> _guardar(ValueNotifier<Set<int>> n, String k) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(k, n.value.map((e) => '$e').toList());
    } catch (_) {}
  }
}
