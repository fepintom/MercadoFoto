import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/biometric_service.dart';
import 'services/push_service.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MercadoFotoApp());
}

class MercadoFotoApp extends StatelessWidget {
  const MercadoFotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OK Venta',
      theme: AppTheme.theme,
      home: const _AuthGate(),
    );
  }
}

// ── Auth Gate: decide la pantalla inicial ────────────────────────────────────
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    // Diferir la navegación hasta después del primer frame —
    // Navigator no existe durante initState/_firstBuild.
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    // Sesión Firebase activa → verificar biometría si está habilitada
    if (FirebaseAuth.instance.currentUser != null) {
      PushService.init().catchError((_) {});
      final biometricEnabled = await BiometricService.isEnabled();
      if (biometricEnabled) {
        final ok = await BiometricService.authenticate(
          reason: 'Verifica tu identidad para ingresar a OkVenta',
        );
        _go(ok ? const HomeScreen() : const LoginScreen());
      } else {
        _go(const HomeScreen());
      }
      return;
    }
    // Guest session activa → HomeScreen
    final guest = await SessionService.obtenerGuest();
    if (guest != null && guest.isNotEmpty) {
      PushService.init().catchError((_) {});
      _go(const HomeScreen());
      return;
    }
    // Sin sesión → LoginScreen
    _go(const LoginScreen());
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
