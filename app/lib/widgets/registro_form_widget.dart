import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class RegistroFormWidget extends StatefulWidget {
  final Future<void> Function(String email, String password) onSubmit;
  final Future<void> Function()? onGoogleSignIn;
  final bool isLogin;
  final VoidCallback? onToggle;

  const RegistroFormWidget({
    super.key,
    required this.onSubmit,
    this.onGoogleSignIn,
    this.isLogin = false,
    this.onToggle,
  });

  @override
  State<RegistroFormWidget> createState() => _RegistroFormWidgetState();
}

class _RegistroFormWidgetState extends State<RegistroFormWidget> {
  final emailCtrl = TextEditingController();
  final passCtrl  = TextEditingController();

  bool _loading       = false;
  bool _loadingGoogle = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  // ── Email/Password submit ─────────────────────────────────────────────
  Future<void> _submit() async {
    final email    = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    if (!email.contains("@")) {
      _snack("Ingresa un correo válido");
      return;
    }
    if (password.length < 6) {
      _snack("La contraseña debe tener al menos 6 caracteres");
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.onSubmit(email, password);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Google submit ─────────────────────────────────────────────────────
  Future<void> _submitGoogle() async {
    if (widget.onGoogleSignIn == null) return;
    setState(() => _loadingGoogle = true);
    try {
      await widget.onGoogleSignIn!();
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  Future<void> _solicitarReset() async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Ingresa tu correo primero');
      return;
    }
    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/solicitar_reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      _snack('Si el correo está registrado, recibirás un enlace para restablecer tu contraseña');
    } catch (_) {
      _snack('Sin conexión al servidor');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.carbon,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final titulo     = widget.isLogin ? "Ingresar" : "Crear cuenta";
    final textoBoton = widget.isLogin ? "Ingresar" : "Registrarse";

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),

        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Header
        Row(
          children: [
            Image.asset('assets/images/logo.png', height: 30),
            Expanded(
              child: Center(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 30),
          ],
        ),

        const SizedBox(height: 20),

        // Email
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(
              fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: "Correo electrónico",
            labelStyle: const TextStyle(
                color: AppColors.grayMid, fontSize: 14),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.divider, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.divider, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Password
        TextField(
          controller: passCtrl,
          obscureText: true,
          style: const TextStyle(
              fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: "Contraseña",
            labelStyle: const TextStyle(
                color: AppColors.grayMid, fontSize: 14),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.divider, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.divider, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),

        // ¿Olvidaste tu contraseña?
        if (widget.isLogin)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _solicitarReset,
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(color: AppColors.grayMid, fontSize: 13),
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Botón email/pass
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: AppColors.surface, strokeWidth: 2.5),
                  )
                : Text(
                    textoBoton,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),

        const SizedBox(height: 10),

        // Toggle login ↔ registro
        Center(
          child: TextButton(
            onPressed: widget.onToggle,
            child: Text(
              widget.isLogin
                  ? "¿No tienes cuenta? Regístrate"
                  : "¿Ya tienes cuenta? Ingresa",
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
        ),

        // Divisor
        Row(
          children: [
            Expanded(
                child: Divider(
                    color: AppColors.divider.withOpacity(0.8))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "o",
                style: TextStyle(
                    color: AppColors.grayMid, fontSize: 13),
              ),
            ),
            Expanded(
                child: Divider(
                    color: AppColors.divider.withOpacity(0.8))),
          ],
        ),

        const SizedBox(height: 12),

        // Botón Google
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: (_loadingGoogle || widget.onGoogleSignIn == null)
                ? null
                : _submitGoogle,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: AppColors.surface,
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
                        "https://developers.google.com/identity/images/g-logo.png",
                        height: 20,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.g_mobiledata_rounded,
                          color: AppColors.carbon,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Continuar con Google",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}
