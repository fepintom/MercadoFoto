import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class EditarPublicacionScreen extends StatefulWidget {
  final Map<String, dynamic> producto;

  const EditarPublicacionScreen({super.key, required this.producto});

  @override
  State<EditarPublicacionScreen> createState() =>
      _EditarPublicacionScreenState();
}

class _EditarPublicacionScreenState extends State<EditarPublicacionScreen> {
  final _formKey        = GlobalKey<FormState>();
  late TextEditingController _tituloCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _precioCtrl;
  bool _guardando       = false;
  final _picker         = ImagePicker();

  // ── Fotos ─────────────────────────────────────────────────────────────────
  /// URLs de fotos existentes que se van a conservar
  late List<String> _fotosExistentes;
  /// Archivos locales nuevos por agregar
  final List<File> _fotosNuevas = [];
  int  _paginaActual    = 0;
  late PageController  _pageCtrl;

  // Todas las fotos juntas para el PageView
  List<dynamic> get _todas => [..._fotosExistentes, ..._fotosNuevas];

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tituloCtrl = TextEditingController(text: widget.producto['titulo']?.toString() ?? '');
    _descCtrl   = TextEditingController(text: widget.producto['descripcion']?.toString() ?? '');
    _precioCtrl = TextEditingController(text: widget.producto['precio']?.toString() ?? '');
    _pageCtrl   = PageController();

    // Construir lista de fotos existentes: principal + extras
    _fotosExistentes = [];
    final main = widget.producto['imagen_url'] as String?;
    if (main != null && main.isNotEmpty) _fotosExistentes.add(main);

    final extras = widget.producto['imagenes_extra'];
    if (extras != null && extras.toString().isNotEmpty) {
      try {
        final lista = jsonDecode(extras.toString()) as List;
        _fotosExistentes.addAll(lista.map((e) => e.toString()));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _precioCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Fuente de imagen ──────────────────────────────────────────────────────

  Future<ImageSource?> _elegirFuente() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.carbon),
              title: const Text('Cámara',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.carbon),
              title: const Text('Galería',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _agregarFoto() async {
    if (_todas.length >= 4) return;
    final source = await _elegirFuente();
    if (source == null || !mounted) return;
    final foto = await _picker.pickImage(source: source, imageQuality: 85);
    if (foto == null) return;
    setState(() => _fotosNuevas.add(File(foto.path)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageCtrl.hasClients && _todas.length > 1) {
        _pageCtrl.animateToPage(
          _todas.length - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _quitarFoto(int index) {
    if (_todas.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Debe quedar al menos una foto"),
        backgroundColor: AppColors.carbon,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() {
      if (index < _fotosExistentes.length) {
        _fotosExistentes.removeAt(index);
      } else {
        _fotosNuevas.removeAt(index - _fotosExistentes.length);
      }
      if (_paginaActual >= _todas.length) {
        _paginaActual = _todas.length - 1;
      }
    });
  }

  // ── Guardar ───────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      await ApiService.editarPublicacion(
        id: widget.producto['id'] as int,
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descCtrl.text.trim(),
        precio: double.parse(_precioCtrl.text.trim()),
        fotosMantener: _fotosExistentes,
        fotosNuevas: _fotosNuevas,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Publicación actualizada"),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.carbon),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Galería PageView ──────────────────────────────────────────────────────

  Widget _buildGaleria() {
    final total    = _todas.length;
    final puedeMas = total < 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            children: [
              const Text("Fotos",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(width: 6),
              Text("($total/4)",
                  style: const TextStyle(fontSize: 12, color: AppColors.grayMid)),
              const Spacer(),
              if (puedeMas)
                GestureDetector(
                  onTap: _agregarFoto,
                  child: Row(
                    children: const [
                      Icon(Icons.add_photo_alternate_outlined, size: 16, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text("Agregar", style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // PageView de fotos
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _paginaActual = i),
                itemCount: total + (puedeMas ? 1 : 0),
                itemBuilder: (_, i) {
                  // Slot "+" al final
                  if (i == total) {
                    return GestureDetector(
                      onTap: _agregarFoto,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider, width: 1.5,
                              style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_photo_alternate_outlined,
                                  color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(height: 10),
                            const Text("Agregar foto",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            const SizedBox(height: 4),
                            const Text("Cámara o galería",
                                style: TextStyle(fontSize: 11, color: AppColors.grayMid)),
                          ],
                        ),
                      ),
                    );
                  }

                  // Foto existente (red) o nueva (local)
                  final isExistente = i < _fotosExistentes.length;
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: AppColors.background,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: isExistente
                              ? Image.network(
                                  "${ApiService.baseUrl}${_fotosExistentes[i]}",
                                  width: double.infinity, height: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image_outlined, color: AppColors.grayMid, size: 40),
                                )
                              : Image.file(
                                  _fotosNuevas[i - _fotosExistentes.length],
                                  width: double.infinity, height: 220,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),

                      // Badge "Principal"
                      if (i == 0)
                        Positioned(
                          top: 10, left: 28,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.carbon.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text("Principal",
                                style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ),

                      // Badge "Nueva" para fotos recién agregadas
                      if (!isExistente)
                        Positioned(
                          top: 10, left: 28,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text("Nueva",
                                style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ),

                      // Botón quitar
                      Positioned(
                        top: 10, right: 28,
                        child: GestureDetector(
                          onTap: () => _quitarFoto(i),
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.carbon.withValues(alpha: 0.78),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        // Dots de paginación
        if (total > 1 || puedeMas)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                total + (puedeMas ? 1 : 0),
                (i) {
                  final isPlus   = i == total;
                  final isActive = i == _paginaActual;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isPlus
                          ? AppColors.divider
                          : isActive
                              ? AppColors.primary
                              : AppColors.grayMid.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Editar publicación",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.divider),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            // ── Galería multi-foto ──────────────────────────────────────────
            Container(
              color: AppColors.surface,
              child: _buildGaleria(),
            ),

            const SizedBox(height: 12),

            // ── Formulario ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  _campo(
                    label: "Título",
                    ctrl: _tituloCtrl,
                    maxLength: 80,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? "El título es obligatorio" : null,
                  ),
                  const SizedBox(height: 16),
                  _campo(
                    label: "Descripción",
                    ctrl: _descCtrl,
                    maxLines: 4,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 16),
                  _campo(
                    label: "Precio (CLP)",
                    ctrl: _precioCtrl,
                    teclado: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return "El precio es obligatorio";
                      if (double.tryParse(v.trim()) == null) return "Precio inválido";
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Botón guardar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.grayMid,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("Guardar cambios",
                              style: TextStyle(
                                  color: AppColors.textOnPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Campo de texto ────────────────────────────────────────────────────────

  Widget _campo({
    required String label,
    required TextEditingController ctrl,
    int maxLines = 1,
    int? maxLength,
    TextInputType teclado = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: teclado,
          textCapitalization: TextCapitalization.sentences,
          validator: validator,
          decoration: InputDecoration(
            counterStyle: const TextStyle(color: AppColors.grayMid, fontSize: 11),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
