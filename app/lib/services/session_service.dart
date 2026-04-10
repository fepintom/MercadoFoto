import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _guestKey   = "guest_id";
  static const _userKey    = "user_id";
  static const _nombreKey  = "nombre";
  static const _emailKey   = "email";

  // ── GUEST ─────────────────────────────────────────────────────────────
  static Future<void> guardarGuest(String guestId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guestKey, guestId);
  }

  static Future<String?> obtenerGuest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_guestKey);
  }

  // ── USER ID ───────────────────────────────────────────────────────────
  static Future<void> guardarUser(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userKey, userId);
  }

  static Future<int?> obtenerUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userKey);
  }

  // ── NOMBRE ────────────────────────────────────────────────────────────
  static Future<void> guardarNombre(String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nombreKey, nombre);
  }

  static Future<String?> obtenerNombre() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nombreKey);
  }

  // ── EMAIL ─────────────────────────────────────────────────────────────
  static Future<void> guardarEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  static Future<String?> obtenerEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  // ── SESIÓN COMPLETA ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> obtenerSesion() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "user_id": prefs.getInt(_userKey),
      "guest_id": prefs.getString(_guestKey),
      "nombre": prefs.getString(_nombreKey),
      "email": prefs.getString(_emailKey),
    };
  }

  // ── LOGOUT ────────────────────────────────────────────────────────────
  static Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_nombreKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_guestKey);
  }
}
