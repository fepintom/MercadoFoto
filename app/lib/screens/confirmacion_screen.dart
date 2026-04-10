import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'mis_publicaciones_screen.dart';

// ── Modelo Talla de envío ─────────────────────────────────────────────────
class _Talla {
  final String id;
  final String titulo;
  final String descripcion;

  const _Talla(this.id, this.titulo, this.descripcion);
}

const _tallas = [
  _Talla('XS', 'Talla XS', 'Sobres acolchados o cajas chicas hasta 0,5 Kg'),
  _Talla('S',  'Talla S',  'Hasta 3 Kg o 20 × 20 × 30 cms'),
  _Talla('M',  'Talla M',  'Hasta 6 Kg o 30 × 30 × 25 cms'),
  _Talla('L',  'Talla L',  'Hasta 20 Kg o 70 × 70 × 70 cms'),
  _Talla('manual', 'Prefiero ingresar las medidas', 'Alto × largo × ancho y peso'),
];

// ── Utilidad: detectar talla desde string de IA ───────────────────────────
String _detectarTallaDesdeIA(String dimStr) {
  if (dimStr.isEmpty || dimStr.toLowerCase().contains('no determin')) {
    return 'S';
  }
  final d = dimStr.toLowerCase();

  // Extraer kg
  double kg = 0;
  final kgMatch = RegExp(r'(\d+[,.]?\d*)\s*kg').firstMatch(d);
  if (kgMatch != null) {
    kg = double.tryParse(kgMatch.group(1)!.replaceAll(',', '.')) ?? 0;
  }
  // Convertir gramos
  final gMatch = RegExp(r'(\d+)\s*g(?![a-z])').firstMatch(d);
  if (gMatch != null && kg == 0) {
    kg = (int.tryParse(gMatch.group(1)!) ?? 0) / 1000.0;
  }

  // Extraer cm (números antes de "x", "×", "cm")
  final cmMatches =
      RegExp(r'(\d+)\s*(?:x|×|cm)', caseSensitive: false).allMatches(d);
  final cms = cmMatches
      .map((m) => int.tryParse(m.group(1)!) ?? 0)
      .where((n) => n > 0 && n <= 300)
      .toList();

  // Fallback: todos los números razonables como cm
  if (cms.isEmpty) {
    final plain = RegExp(r'\b(\d{1,3})\b').allMatches(d);
    cms.addAll(plain
        .map((m) => int.tryParse(m.group(1)!) ?? 0)
        .where((n) => n >= 5 && n <= 200));
  }

  final maxCm = cms.isNotEmpty ? cms.reduce(max) : 20;

  if (kg <= 0.5 && maxCm <= 20) return 'XS';
  if (kg <= 3.0 && maxCm <= 30) return 'S';
  if (kg <= 6.0 && maxCm <= 35) return 'M';
  return 'L';
}

// ── Screen ────────────────────────────────────────────────────────────────
class ConfirmacionScreen extends StatefulWidget {
  final String data;
  final File imagen;

  const ConfirmacionScreen({
    super.key,
    required this.data,
    required this.imagen,
  });

  @override
  State<ConfirmacionScreen> createState() => _ConfirmacionScreenState();
}

class _ConfirmacionScreenState extends State<ConfirmacionScreen> {
  late TextEditingController titulo;
  late TextEditingController descripcion;
  final precio = TextEditingController();
  String _categoria    = "";
  String _subcategoria = "";

  // ── Multi-foto ────────────────────────────────────────────────────────
  late List<File> _imagenes;
  int _paginaActual = 0;
  late PageController _pageController;
  bool _publicando = false;
  final _picker = ImagePicker();

  // ── Talla de envío ────────────────────────────────────────────────────
  String _tallaId = 'S';
  final _altoCtrl  = TextEditingController();
  final _largoCtrl = TextEditingController();
  final _anchoCtrl = TextEditingController();
  final _pesoCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _imagenes      = [widget.imagen];
    _pageController = PageController();

    final jsonData   = jsonDecode(widget.data);
    titulo           = TextEditingController(text: jsonData["titulo"]      ?? "");
    descripcion      = TextEditingController(text: jsonData["descripcion"] ?? "");
    _categoria       = jsonData["categoria"]    ?? "";
    _subcategoria    = jsonData["subcategoria"] ?? "";

    // Auto-detectar talla desde las dimensiones generadas por IA
    final dimIA = jsonData["dimensiones"] ?? "";
    _tallaId = _detectarTallaDesdeIA(dimIA);
  }

  @override
  void dispose() {
    _pageController.dispose();
    titulo.dispose();
    descripcion.dispose();
    precio.dispose();
    _altoCtrl.dispose();
    _largoCtrl.dispose();
    _anchoCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  // ── Selector fuente imagen ────────────────────────────────────────────
  Future<ImageSource?> _elegirFuente() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.carbon),
              title: const Text('Cámara',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.carbon),
              title: const Text('Galería',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _agregarFoto() async {
    if (_imagenes.length >= 4) return;
    final source = await _elegirFuente();
    if (source == null) return;
    final foto = await _picker.pickImage(source: source, imageQuality: 80);
    if (foto == null) return;
    setState(() => _imagenes.add(File(foto.path)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && _imagenes.length > 1) {
        _pageController.animateToPage(
          _imagenes.length - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ── Generar string de dimensiones para el backend ─────────────────────
  String _getDimensiones() {
    if (_tallaId == 'manual') {
      final a  = _altoCtrl.text.trim();
      final l  = _largoCtrl.text.trim();
      final an = _anchoCtrl.text.trim();
      final p  = _pesoCtrl.text.trim();
      if (a.isEmpty && l.isEmpty && an.isEmpty) return 'No especificado';
      return '${a}×${l}×${an} cm${p.isNotEmpty ? ", $p kg" : ""}';
    }
    final t = _tallas.firstWhere((t) => t.id == _tallaId);
    return '${t.titulo}: ${t.descripcion}';
  }

  // ── Publicar ──────────────────────────────────────────────────────────
  Future<void> publicar() async {
    if (precio.text.trim().isEmpty) {
      _snack("Ingresa un precio");
      return;
    }
    if (_tallaId == 'manual') {
      if (_altoCtrl.text.trim().isEmpty ||
          _largoCtrl.text.trim().isEmpty ||
          _anchoCtrl.text.trim().isEmpty) {
        _snack("Ingresa las dimensiones del producto");
        return;
      }
    }

    setState(() => _publicando = true);

    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("${ApiService.baseUrl}/publicar"),
      );

      request.fields["titulo"]       = titulo.text.trim();
      request.fields["descripcion"]  = descripcion.text.trim();
      request.fields["precio"]       = precio.text.trim();
      request.fields["dimensiones"]  = _getDimensiones();
      if (_categoria.isNotEmpty)    request.fields["categoria"]    = _categoria;
      if (_subcategoria.isNotEmpty) request.fields["subcategoria"] = _subcategoria;

      // Foto principal + extras
      request.files.add(
          await http.MultipartFile.fromPath("file", _imagenes[0].path));
      if (_imagenes.length > 1)
        request.files.add(
            await http.MultipartFile.fromPath("file2", _imagenes[1].path));
      if (_imagenes.length > 2)
        request.files.add(
            await http.MultipartFile.fromPath("file3", _imagenes[2].path));
      if (_imagenes.length > 3)
        request.files.add(
            await http.MultipartFile.fromPath("file4", _imagenes[3].path));

      final session = await SessionService.obtenerSesion();
      if (session["user_id"] != null) {
        request.fields["user_id"] = session["user_id"].toString();
      } else {
        request.fields["guest_id"] = session["guest_id"].toString();
      }

      final response = await request.send();
      final respStr  = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        debugPrint("ERROR PUBLICAR: $respStr");
        throw Exception("Error al publicar");
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MisPublicacionesScreen()),
      );
    } catch (e) {
      debugPrint("ERROR PUBLICAR: $e");
      if (!mounted) return;
      setState(() => _publicando = false);
      _snack("Error al publicar el producto");
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Campo de texto estándar ───────────────────────────────────────────
  Widget _campo(String label, TextEditingController ctrl,
      {bool readOnly = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        readOnly: readOnly,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              const TextStyle(color: AppColors.grayMid, fontSize: 14),
          filled: true,
          fillColor: readOnly ? AppColors.background : AppColors.surface,
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
    );
  }

  // ── GALERÍA PageView ──────────────────────────────────────────────────
  Widget _buildGaleria() {
    final totalPages =
        _imagenes.length + (_imagenes.length < 4 ? 1 : 0);

    return SizedBox(
      height: 240,
      child: PageView.builder(
        controller: _pageController,
        itemCount: totalPages,
        onPageChanged: (i) => setState(() => _paginaActual = i),
        itemBuilder: (_, i) {
          if (i == _imagenes.length) return _buildAddFotoPage();
          return _buildFotoPagina(i);
        },
      ),
    );
  }

  Widget _buildFotoPagina(int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(_imagenes[index], fit: BoxFit.cover),
        if (index == 0)
          Positioned(
            top: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text("Principal",
                  style: TextStyle(
                      color: AppColors.textOnPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        if (_imagenes.length > 1)
          Positioned(
            top: 12, right: 12,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _imagenes.removeAt(index);
                  if (_paginaActual >= _imagenes.length) {
                    _paginaActual = _imagenes.length - 1;
                  }
                });
              },
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.carbon.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: AppColors.surface, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAddFotoPage() {
    return GestureDetector(
      onTap: _agregarFoto,
      child: Container(
        color: AppColors.background,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider, width: 1.5),
              ),
              child: const Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.grayMid, size: 32),
            ),
            const SizedBox(height: 12),
            const Text("Agregar foto",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text("${_imagenes.length}/4 · Desliza para ver las demás",
                style: const TextStyle(
                    fontSize: 13, color: AppColors.grayMid)),
          ],
        ),
      ),
    );
  }

  Widget _buildDots() {
    final totalPages =
        _imagenes.length + (_imagenes.length < 4 ? 1 : 0);
    if (totalPages <= 1) return const SizedBox(height: 10);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: AppColors.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalPages, (i) {
          final isActive   = i == _paginaActual;
          final isAddSlot  = i == _imagenes.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isActive ? 20 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isAddSlot
                  ? AppColors.divider
                  : isActive
                      ? AppColors.primary
                      : AppColors.divider,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  // ── TALLA SELECTOR (card tappable → bottom sheet) ─────────────────────
  Widget _buildTallaSection() {
    final tallaActual = _tallas.firstWhere(
      (t) => t.id == _tallaId,
      orElse: () => _tallas[1],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined,
                  size: 15, color: AppColors.grayMid),
              const SizedBox(width: 6),
              const Text(
                "Dimensiones de envío",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "Auto-detectado",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Card con talla seleccionada
          GestureDetector(
            onTap: _abrirTallaSheet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.4), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _tallaId == 'manual' ? '✏️' : _tallaId,
                        style: TextStyle(
                          fontSize: _tallaId == 'manual' ? 16 : 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tallaActual.titulo,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tallaActual.descripcion,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.grayMid),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined,
                      size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),

          // Campos manuales (solo si tallaId == 'manual')
          if (_tallaId == 'manual') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _campoMedida("Alto (cm)", _altoCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _campoMedida("Largo (cm)", _largoCtrl)),
              ],
            ),
            Row(
              children: [
                Expanded(child: _campoMedida("Ancho (cm)", _anchoCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _campoMedida("Peso (kg)", _pesoCtrl)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _campoMedida(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(
            fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: AppColors.grayMid, fontSize: 13),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
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
            borderSide: const BorderSide(
                color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Bottom sheet de selección de talla ────────────────────────────────
  void _abrirTallaSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _buildTallaSheetContent(),
    );
  }

  Widget _buildTallaSheetContent() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: const [
                Icon(Icons.local_shipping_outlined,
                    color: Colors.white54, size: 16),
                SizedBox(width: 8),
                Text(
                  "Seleccionar dimensiones",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Opciones
          ...List.generate(_tallas.length, (i) {
            final t        = _tallas[i];
            final selected = _tallaId == t.id;
            final isLast   = i == _tallas.length - 1;

            return GestureDetector(
              onTap: () {
                setState(() => _tallaId = t.id);
                Navigator.pop(context);
              },
              child: Container(
                color: Colors.transparent,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.titulo,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  t.descripcion,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: selected
                                        ? AppColors.primary
                                            .withOpacity(0.8)
                                        : Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Colors.white12,
                        indent: 20,
                        endIndent: 20,
                      ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Build principal ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Confirmar producto",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.carbon),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppColors.divider, height: 0.5),
        ),
      ),
      body: _publicando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text("Publicando...",
                      style: TextStyle(
                          color: AppColors.grayMid, fontSize: 14)),
                ],
              ),
            )
          : ListView(
              children: [
                // ── Galería ───────────────────────────────────────────
                _buildGaleria(),
                _buildDots(),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Contador de fotos
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.photo_library_outlined,
                                size: 14, color: AppColors.grayMid),
                            const SizedBox(width: 6),
                            Text(
                              "${_imagenes.length} foto${_imagenes.length != 1 ? 's' : ''} · "
                              "${_imagenes.length < 4 ? 'Desliza para agregar más' : 'Máximo alcanzado'}",
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grayMid),
                            ),
                          ],
                        ),
                      ),

                      // Campos editables
                      _campo("Título", titulo),
                      _campo("Descripción", descripcion, maxLines: 3),

                      // Categoría detectada
                      if (_categoria.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                  width: 0.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Categoría detectada: $_categoria"
                                    "${_subcategoria.isNotEmpty ? ' › $_subcategoria' : ''}",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── Selector de Talla ─────────────────────────
                      _buildTallaSection(),

                      // Precio
                      TextField(
                        controller: precio,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: "Precio",
                          labelStyle: const TextStyle(
                              color: AppColors.grayMid, fontSize: 14),
                          prefixText: "\$ ",
                          prefixStyle: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.divider, width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.divider, width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 1.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: publicar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textOnPrimary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text("Publicar"),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
