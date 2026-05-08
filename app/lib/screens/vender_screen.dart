import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/space_invaders_widget.dart';
import 'confirmacion_screen.dart';
import 'venta_manual_screen.dart';

class VenderScreen extends StatefulWidget {
  const VenderScreen({super.key});

  @override
  State<VenderScreen> createState() => _VenderScreenState();
}

class _VenderScreenState extends State<VenderScreen> {
  final ImagePicker _picker = ImagePicker();

  // 'selector' | 'automatica'
  String _estado = 'selector';
  bool _loading = false;
  String _loadingMsg = "Analizando imagen con IA...";
  bool _usuarioRegistrado = false;

  @override
  void initState() {
    super.initState();
    _verificarRegistro();
  }

  Future<void> _verificarRegistro() async {
    final userId = await SessionService.obtenerUser();
    if (mounted) setState(() => _usuarioRegistrado = userId != null);
  }

  // ── Análisis de imagen ────────────────────────────────────────────────
  Future<void> _analizarImagen(File imagen) async {
    setState(() {
      _loading = true;
      _loadingMsg = "Analizando imagen con IA...";
    });

    try {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("${ApiService.baseUrl}/analizar"),
      );
      request.files
          .add(await http.MultipartFile.fromPath("file", imagen.path));

      // Actualizar mensaje mientras espera
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _loading) {
          setState(() => _loadingMsg = "Generando título y descripción...");
        }
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _loading) {
          setState(() => _loadingMsg = "Casi listo...");
        }
      });

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (!mounted) return;
      setState(() => _loading = false);

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ConfirmacionScreen(data: respStr, imagen: imagen),
          ),
        );
      } else {
        _mostrarError("No se pudo analizar la imagen. Intenta de nuevo.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _mostrarError("Error de conexión. Verifica tu red.");
    }
  }

  Future<void> _abrirCamara() async {
    final XFile? foto = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (foto != null) _analizarImagen(File(foto.path));
  }

  Future<void> _abrirGaleria() async {
    final XFile? foto = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (foto != null) _analizarImagen(File(foto.path));
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 36),
        centerTitle: false,
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.carbon),
        // Botón volver al selector si estamos en modo automático
        leading: _estado == 'automatica' && !_loading
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: AppColors.carbon, size: 20),
                onPressed: () => setState(() => _estado = 'selector'),
              )
            : null,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppColors.divider, height: 0.5),
        ),
      ),
      body: _loading
          ? _buildLoadingConJuego()
          : _estado == 'selector'
              ? _buildModoSelector()
              : _buildAutoSelector(),
    );
  }

  // ── PANTALLA DE CARGA CON SPACE INVADERS ─────────────────────────────
  Widget _buildLoadingConJuego() {
    return Column(
      children: [
        // Header de carga
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loadingMsg,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Esto puede tardar unos segundos · ¡Juega mientras!",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.grayMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5),

        // Juego Space Invaders
        const Expanded(child: SpaceInvadersWidget()),

        // Badge IA
        Container(
          color: AppColors.surface,
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 13, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                "Impulsado por IA — GPT-4o Vision",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── SELECTOR DE MODO ──────────────────────────────────────────────────
  Widget _buildModoSelector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          const Text(
            "¿Cómo quieres\npublicar?",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Elige el método que más te acomode.",
            style: TextStyle(
              fontSize: 15,
              color: AppColors.grayMid,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // ── VENTA AUTOMÁTICA ─────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _estado = 'automatica'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.carbon,
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.carbon,
                    AppColors.carbon.withOpacity(0.88),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "VENTA AUTOMÁTICA",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Saca una foto",
                            style: TextStyle(
                              color: AppColors.surface,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "La IA analiza tu imagen y genera automáticamente el título, descripción y categoría. ¡Listo en segundos!",
                    style: TextStyle(
                      color: AppColors.surface.withOpacity(0.75),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _tagChip(Icons.camera_alt_rounded, "Foto → IA → Publicar"),
                      const SizedBox(width: 8),
                      _tagChip(Icons.timer_rounded, "~10 seg"),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── VENTA MANUAL ─────────────────────────────────────────
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VentaManualScreen(),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: AppColors.carbon, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "VENTA MANUAL",
                            style: TextStyle(
                              color: AppColors.grayMid,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Control total",
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Ingresa tú mismo el título, descripción, precio y categoría. Ideal si ya sabes exactamente qué quieres publicar.",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _tagChipDark(Icons.edit_outlined, "Formulario completo"),
                      const SizedBox(width: 8),
                      _tagChipDark(Icons.photo_library_outlined, "Hasta 4 fotos"),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── CARGA MASIVA (solo usuarios registrados) ──────────────
          if (_usuarioRegistrado) GestureDetector(
            onTap: _mostrarDialogoCargaMasiva,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.table_rows_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CARGA MASIVA",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Múltiples productos",
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Carga productos simultáneamente llenando la planilla de carga masiva.",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _tagChipDark(Icons.file_download_outlined, "Planilla Excel"),
                      const SizedBox(width: 8),
                      _tagChipDark(Icons.bolt_rounded, "Publicación automática"),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Tip
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.15), width: 0.5),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Para mejores resultados en Automática: buena iluminación, fondo liso y producto centrado.",
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── CARGA MASIVA — bottom sheet ───────────────────────────────────────
  Future<void> _mostrarDialogoCargaMasiva() async {
    final emailGuardado = await SessionService.obtenerEmail() ?? '';
    final emailCtrl = TextEditingController(text: emailGuardado);
    bool enviando = false;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Icono + título
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.table_rows_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Carga masiva",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        "Te enviamos la planilla por correo",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.grayMid,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Instrucción
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.15), width: 0.5),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 15, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Recibirás un Excel con las instrucciones. Llénalo y reenvíalo con las fotos adjuntas. Tus productos se publican automáticamente.",
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Campo email
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: emailGuardado.isEmpty,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: "Correo electrónico",
                  labelStyle:
                      const TextStyle(color: AppColors.grayMid, fontSize: 14),
                  prefixIcon: const Icon(Icons.mail_outline_rounded,
                      color: AppColors.grayMid, size: 20),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.divider, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.divider, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Botón enviar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: enviando
                      ? null
                      : () async {
                          final email = emailCtrl.text.trim();
                          if (email.isEmpty || !email.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Ingresa un correo válido"),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          setSheetState(() => enviando = true);
                          try {
                            await ApiService.enviarPlantilla(email);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("✓ Planilla enviada a $email"),
                                  backgroundColor: AppColors.carbon,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          } catch (e) {
                            setSheetState(() => enviando = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error: $e"),
                                  backgroundColor: AppColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: enviando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          "Enviar planilla",
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tagChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.surface, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: AppColors.surface.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChipDark(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.grayMid, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.grayMid,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── SELECTOR AUTOMÁTICO (cámara / galería) ────────────────────────────
  Widget _buildAutoSelector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          const Text(
            "Saca o elige\ntu foto",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "La IA genera el título, descripción y categoría automáticamente.",
            style: TextStyle(
              fontSize: 15,
              color: AppColors.grayMid,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Card cámara
          GestureDetector(
            onTap: _abrirCamara,
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.carbon,
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.carbon,
                    AppColors.carbon.withOpacity(0.85),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: AppColors.surface, size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Abrir cámara",
                    style: TextStyle(
                      color: AppColors.surface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Toca para tomar una foto",
                    style: TextStyle(
                      color: AppColors.surface.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Galería
          GestureDetector(
            onTap: _abrirGaleria,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library_outlined,
                        color: AppColors.carbon, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Elegir de galería",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Selecciona una imagen existente",
                        style: TextStyle(
                            fontSize: 12, color: AppColors.grayMid),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: AppColors.grayMid),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.2), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text(
                      "Consejos para mejores resultados",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...[
                  "Buena iluminación — evita sombras",
                  "Fondo liso o neutro",
                  "Producto centrado y visible",
                  "Foto nítida, sin movimiento",
                ].map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          tip,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
