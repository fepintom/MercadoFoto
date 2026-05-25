import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'push_service.dart';
import 'session_service.dart';

/// Centraliza toda la autenticación de la app.
/// Firebase maneja identidad (token), el backend maneja user_id + lógica.
class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();

  // ── Email / Password: Login ─────────────────────────────────────────
  static Future<void> loginConEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _syncConBackend(cred.user!);
  }

  // ── Email / Password: Registro ──────────────────────────────────────
  static Future<void> registrarConEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _syncConBackend(cred.user!);
  }

  // ── Google Sign-In ──────────────────────────────────────────────────
  /// Lanza el flujo nativo de Google. Lanza [GoogleSignInCancelled] si el
  /// usuario cancela (la UI puede ignorar ese error silenciosamente).
  static Future<void> loginConGoogle() async {
    // Cerrar sesión de Google previa para forzar el selector de cuenta
    await _googleSignIn.signOut();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw const _GoogleCancelled();

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    await _syncConBackend(userCred.user!);
  }

  // ── Cerrar sesión ────────────────────────────────────────────────────
  static Future<void> cerrarSesion() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await SessionService.cerrarSesion();
  }

  // ── Usuario actual de Firebase (puede ser null si no hay sesión) ─────
  static User? get usuarioActual => _auth.currentUser;

  // ── Mensaje de error legible para el usuario ─────────────────────────
  static String mensajeError(dynamic e) {
    if (e is _GoogleCancelled) return ''; // no mostrar nada
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No existe una cuenta con ese correo';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Correo o contraseña incorrectos';
        case 'email-already-in-use':
          return 'Este correo ya está registrado';
        case 'invalid-email':
          return 'Correo electrónico inválido';
        case 'weak-password':
          return 'La contraseña es muy débil (mínimo 6 caracteres)';
        case 'network-request-failed':
          return 'Sin conexión. Verifica tu red';
        case 'too-many-requests':
          return 'Demasiados intentos. Intenta más tarde';
        default:
          return 'Error: ${e.message ?? e.code}';
      }
    }
    return 'Error de conexión. Intenta de nuevo';
  }

  // ── Reconectar sesión existente (app restart con Firebase activo) ─────
  /// Llama al backend para refrescar user_id en SharedPreferences.
  /// Silencia errores para no bloquear el arranque de la app.
  static Future<void> reconectarSesion() async {
    final user = _auth.currentUser;
    if (user == null) return;
    // Solo re-sincroniza si no tenemos user_id en local
    final local = await SessionService.obtenerUser();
    if (local != null) return; // ya tenemos sesión persistida
    try {
      await _syncConBackend(user);
    } catch (_) {}
  }

  // ── Sync con backend ─────────────────────────────────────────────────
  /// Crea o recupera el user_id del backend y persiste la sesión local.
  static Future<void> _syncConBackend(User firebaseUser) async {
    final guestId = await SessionService.obtenerGuest();

    // Separar nombre y apellido desde displayName ("Fernando Pinto" → "Fernando", "Pinto")
    final parts = (firebaseUser.displayName ?? '').trim().split(' ');
    final nombre   = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : (firebaseUser.email?.split('@').first ?? 'Usuario');
    final apellido = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final fotoUrl  = firebaseUser.photoURL ?? '';

    final res = await http.post(
      Uri.parse('${ApiService.baseUrl}/login/firebase'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'firebase_uid': firebaseUser.uid,
        'email':        firebaseUser.email ?? '',
        'nombre':       nombre,
        'apellido':     apellido,
        'foto_url':     fotoUrl,
        if (guestId != null && guestId.isNotEmpty) 'guest_id': guestId,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Error al sincronizar con backend: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await SessionService.guardarUser(data['user_id'] as int);
    await SessionService.guardarNombre(data['nombre'] as String);
    await SessionService.guardarApellido(data['apellido'] as String? ?? '');
    await SessionService.guardarFotoUrl(data['foto_url'] as String? ?? '');
    await SessionService.guardarEmail(firebaseUser.email ?? '');
    await SessionService.guardarGuest('');

    // Registrar token FCM para notificaciones push
    PushService.init().catchError((_) {});
  }
}

// ── Excepción interna para cancelación de Google ─────────────────────────
class _GoogleCancelled implements Exception {
  const _GoogleCancelled();
}
