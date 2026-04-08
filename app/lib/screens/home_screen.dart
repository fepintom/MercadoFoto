import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

import 'vender_screen.dart' as vender;
import 'marketplace_screen.dart';
import 'mi_cuenta_screen.dart';
import '../widgets/registro_form_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? userId;
  String nombreUsuario = "Usuario invitado";

  @override
  void initState() {
    super.initState();
    inicializarHome();
  }

  Future<void> inicializarHome() async {
    await iniciarSesion();
    await cargarUsuario();
  }

  Future<void> iniciarSesion() async {
    final usuarioRegistrado = await SessionService.obtenerUser();
    if (usuarioRegistrado != null) return;

    final guest = await SessionService.obtenerGuest();
    if (guest != null && guest.toString().isNotEmpty) return;

    final response = await http.get(Uri.parse("${ApiService.baseUrl}/guest"));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final guestId = data["guest_id"]?.toString();
      if (guestId != null && guestId.isNotEmpty) {
        await SessionService.guardarGuest(guestId);
      }
    }
  }

  Future<void> cargarUsuario() async {
    final id = await SessionService.obtenerUser();
    final nombre = await SessionService.obtenerNombre();
    if (!mounted) return;
    setState(() {
      userId = id;
      nombreUsuario = nombre ?? "Usuario invitado";
    });
  }

  Future<void> abrirRegistroModal() async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => _buildModal(
        isLogin: false,
        onSubmit: (email, password) async {
          final guestId = await SessionService.obtenerGuest();
          final response = await http.post(
            Uri.parse("${ApiService.baseUrl}/registro"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": email,
              "password": password,
              "guest_id": guestId,
            }),
          );
          final data = jsonDecode(response.body);
          if (response.statusCode == 200) {
            await SessionService.guardarUser(data["user_id"]);
            await SessionService.guardarNombre(data["nombre"]);
            await SessionService.guardarGuest("");
            Navigator.pop(context);
            await inicializarHome();
            setState(() {});
          } else {
            _mostrarError(data["detail"]);
          }
        },
      ),
    );
  }

  Future<void> abrirLoginModal() async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => _buildModal(
        isLogin: true,
        onSubmit: (email, password) async {
          final response = await http.post(
            Uri.parse("${ApiService.baseUrl}/login"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": email,
              "password": password,
            }),
          );
          final data = jsonDecode(response.body);
          if (response.statusCode == 200) {
            await SessionService.guardarUser(data["user_id"]);
            await SessionService.guardarNombre(data["nombre"]);
            Navigator.pop(context);
            await inicializarHome();
            setState(() {});
          } else {
            _mostrarError(data["detail"]);
          }
        },
      ),
    );
  }

  Widget _buildModal({
    required Function(String, String) onSubmit,
    bool isLogin = false,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: RegistroFormWidget(
                onSubmit: onSubmit,
                isLogin: isLogin,
                onToggle: () {
                  Navigator.pop(context);
                  if (isLogin) {
                    abrirRegistroModal();
                  } else {
                    abrirLoginModal();
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarError(String? msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg ?? "Error"),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.divider,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', height: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: AppColors.divider,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              color: AppColors.grayMid, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                hintText: "Buscar productos...",
                                hintStyle: TextStyle(
                                  color: AppColors.grayMid,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  userId == null
                      ? OutlinedButton(
                          onPressed: abrirRegistroModal,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                              color: AppColors.primary,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text("Registrarse"),
                        )
                      : GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MiCuentaScreen(),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  color: AppColors.background,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: AppColors.carbon,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  nombreUsuario,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),

            // ── CONTENIDO SCROLLABLE ─────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Banner
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      height: 130,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: AppColors.carbon,
                        image: const DecorationImage(
                          image:
                              AssetImage("assets/images/banner_publicidad.jpg"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Marketplace como contenido puro
                    const MarketplaceScreen(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── FOOTER FIJO ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(
                    color: AppColors.divider,
                    width: 0.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: userId == null
                          ? OutlinedButton(
                              onPressed: abrirLoginModal,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.carbon,
                                side: const BorderSide(
                                  color: AppColors.carbon,
                                  width: 1,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text("Ingresar"),
                            )
                          : OutlinedButton(
                              onPressed: () async {
                                await SessionService.cerrarSesion();
                                await inicializarHome();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.grayMid,
                                side: const BorderSide(
                                  color: AppColors.divider,
                                  width: 1,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text("Cerrar sesión"),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const vender.VenderScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text("Vender"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
