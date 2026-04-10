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

  static void clear() {
    cartNotifier.value = [];
  }
}
