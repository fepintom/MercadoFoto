import 'package:flutter/foundation.dart';

class CartService {
  static final ValueNotifier<List<Map<String, dynamic>>> cartNotifier =
      ValueNotifier([]);

  static List<Map<String, dynamic>> get items => cartNotifier.value;
  static int get count => cartNotifier.value.length;

  static void addOffer(Map<String, dynamic> producto, double oferta) {
    final updated = List<Map<String, dynamic>>.from(cartNotifier.value);
    updated.add({...producto, 'oferta': oferta});
    cartNotifier.value = updated;
  }

  /// Agrega un producto al carro (guardado para comprar). Evita duplicados
  /// por id de publicación — si ya estaba, no lo agrega de nuevo.
  static bool addProducto(Map<String, dynamic> producto) {
    final id = producto['id'];
    if (id != null && cartNotifier.value.any((p) => p['id'] == id)) {
      return false;
    }
    final updated = List<Map<String, dynamic>>.from(cartNotifier.value);
    updated.add(producto);
    cartNotifier.value = updated;
    return true;
  }

  static bool contiene(int? publicacionId) {
    if (publicacionId == null) return false;
    return cartNotifier.value.any((p) => p['id'] == publicacionId);
  }

  static void quitarEn(int index) {
    final updated = List<Map<String, dynamic>>.from(cartNotifier.value);
    if (index >= 0 && index < updated.length) {
      updated.removeAt(index);
      cartNotifier.value = updated;
    }
  }

  static void clear() {
    cartNotifier.value = [];
  }
}
