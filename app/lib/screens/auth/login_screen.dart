import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../theme/app_theme.dart';
import '../home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;

  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool _loading       = false;
  bool _loadingGoogle = false;
  bool _obscurePass   = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Email / Password ────────────────────────────────────────────────────
  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text.trim();

    if (!email.contains('@')) { _snack('Ingresa un correo válido'); return; }
    if (pass.length < 6)      { _snack('Mínimo 6 caracteres');     return; }

    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await AuthService.loginConEmail(email, pass);
      } else {
        await AuthService.registrarConEmail(email, pass);
      }
      await _ofrecerFaceId();
    } catch (e) {
      final msg = AuthService.mensajeError(e);
      if (msg.isNotEmpty) _snack(msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google ──────────────────────────────────────────────────────────────
  Future<void> _google() async {
    setState(() => _loadingGoogle = true);
    try {
      await AuthService.loginConGoogle();
      await _ofrecerFaceId();
    } catch (e) {
      final msg = AuthService.mensajeError(e);
      if (msg.isNotEmpty) _snack(msg);
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  // ── Face ID: ofrecer activación tras primer login ────────────────────────
  Future<void> _ofrecerFaceId() async {
    if (!mounted) return;

    // Solo ofrecer si el dispositivo tiene biometría Y el usuario no lo activó aún
    final disponible = await BiometricService.isAvailable();
    final yaActivado = await BiometricService.isEnabled();

    if (!disponible || yaActivado) {
      _irAHome();
      return;
    }

    // Mostrar bottom sheet de activación
    if (!mounted) return;
    final activar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SheetFaceId(),
    );

    if (activar == true) {
      // Verificar que funciona antes de guardar preferencia
      final ok = await BiometricService.authenticate(
        reason: 'Confirma tu Face ID para activarlo en OkVenta',
      );
      if (ok) {
        await BiometricService.setEnabled(true);
        if (mounted) _snack('Face ID activado correctamente');
      }
    }

    _irAHome();
  }

  // ── Navegación ───────────────────────────────────────────────────────────
  Future<void> _solicitarReset() async {
    final emailCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restablecer contraseña'),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Tu correo electrónico',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            child: const Text('Enviar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final email = emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Ingresa un correo válido');
      return;
    }

    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/solicitar_reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
    } catch (_) {
      _snack('Sin conexión al servidor');
      return;
    }
    if (!mounted) return;
    Navigator.pop(context); // cierra el diálogo del correo
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Revisa tu correo'),
        content: const Text(
          'Si el correo está registrado, recibirás un enlace para crear una nueva contraseña.\n\nRevisa también la carpeta de spam.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _irAHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.carbon,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Image.asset('assets/images/logo.png', height: 44),
              const SizedBox(height: 36),

              // Headline
              Text(
                _isLogin ? 'Bienvenido' : 'Crear cuenta',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isLogin
                    ? 'Ingresa a tu cuenta OkVenta'
                    : 'Únete y empieza a vender hoy',
                style: const TextStyle(fontSize: 15, color: AppColors.grayMid),
              ),
              const SizedBox(height: 36),

              // ── Botón Google ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _loadingGoogle ? null : _google,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loadingGoogle
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://developers.google.com/identity/images/g-logo.png',
                              height: 20,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.g_mobiledata_rounded,
                                size: 24,
                                color: AppColors.carbon,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Continuar con Google',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Divisor "o" ───────────────────────────────────────────────
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'o',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.grayMid,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.divider)),
                ],
              ),

              const SizedBox(height: 20),

              // ── Email ─────────────────────────────────────────────────────
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined,
                      color: AppColors.grayMid, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // ── Password ──────────────────────────────────────────────────
              TextField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.grayMid, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.grayMid,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),
              // ── Olvidé mi contraseña ──────────────────────────────────────
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _solicitarReset,
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(
                        color: AppColors.grayMid,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // ── Botón principal ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: AppColors.surface, strokeWidth: 2.5),
                        )
                      : Text(
                          _isLogin ? 'Ingresar' : 'Crear cuenta',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Toggle login ↔ registro ───────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _isLogin = !_isLogin;
                    _emailCtrl.clear();
                    _passCtrl.clear();
                  }),
                  child: Text(
                    _isLogin
                        ? '¿No tienes cuenta? Regístrate gratis'
                        : '¿Ya tienes cuenta? Ingresa',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // ── Explorar sin cuenta ───────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: _irAHome,
                  child: const Text(
                    'Explorar sin cuenta →',
                    style: TextStyle(
                        color: AppColors.grayMid, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet: activar Face ID ────────────────────────────────────────────
class _SheetFaceId extends StatelessWidget {
  const _SheetFaceId();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Ícono
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.face_retouching_natural_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Activa Face ID',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ingresa más rápido la próxima vez.\nSolo miras y listo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.grayMid,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Botón activar
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Activar Face ID',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Botón omitir
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Ahora no',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.grayMid,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
