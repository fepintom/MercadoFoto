import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'api_service.dart';
import 'session_service.dart';

/// Maneja permisos, token FCM y recepción de notificaciones push.
class PushService {
  static final _messaging = FirebaseMessaging.instance;

  /// Inicializar: pedir permiso, obtener token y enviarlo al backend.
  static Future<void> init() async {
    // 1. Solicitar permiso (iOS muestra el diálogo nativo)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('PushService: authorizationStatus=${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // 2. En iOS: esperar a que APNs entregue su token antes de pedir el FCM token
    if (Platform.isIOS) {
      String? apnsToken;
      // Reintentar hasta 5 veces con espera de 1 segundo
      for (int i = 0; i < 5; i++) {
        apnsToken = await _messaging.getAPNSToken();
        debugPrint('PushService: APNs token intento $i: $apnsToken');
        if (apnsToken != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }
      if (apnsToken == null) {
        debugPrint('PushService: APNs token no disponible, abortando');
        return;
      }
    }

    // 3. Obtener token FCM
    final token = await _messaging.getToken();
    debugPrint('PushService: FCM token: $token');
    if (token != null) {
      await _enviarTokenAlBackend(token);
    }

    // 4. Si el token se renueva, reenviarlo
    _messaging.onTokenRefresh.listen(_enviarTokenAlBackend);

    // 5. Manejar notificaciones en foreground (app abierta)
    FirebaseMessaging.onMessage.listen(_manejarMensajeForeground);
  }

  /// Envía el FCM token al backend para que pueda mandar notificaciones.
  static Future<void> _enviarTokenAlBackend(String token) async {
    try {
      final userId = await SessionService.obtenerUser();
      if (userId == null) {
        debugPrint('PushService: userId null, no se envía token');
        return;
      }

      debugPrint('PushService: enviando token a backend para user $userId');
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/usuarios/$userId/fcm_token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );
      debugPrint('PushService: backend respondió ${res.statusCode}');
    } catch (e) {
      debugPrint('PushService: error enviando token: $e');
    }
  }

  /// Cuando llega una notificación con la app abierta, mostrar un banner.
  static void _manejarMensajeForeground(RemoteMessage message) {
    debugPrint('Push foreground: ${message.notification?.title}');
  }

  /// Stream para que la UI pueda mostrar un banner cuando la app está abierta.
  static Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;
}
