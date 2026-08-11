import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/space_invaders_widget.dart';
import 'mis_publicaciones_screen.dart';

class VentaManualScreen extends StatefulWidget {
  const VentaManualScreen({super.key});

  @override
  State<VentaManualScreen> createState() => _VentaManualScreenState();
}

class _VentaManualScreenState extends State<VentaManualScreen> {
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _precio = TextEditingController();
  String _categoria = 'General';
  String _condicion = 'nuevo';
  bool _aceptaOfertas = true;
  final List<File> _imagenes = [];
  bool _publicando = false;
  final _picker = ImagePicker();

  // Tallas (Ropa / Calzado)
  Set<String> _tallasSeleccionadas = {};
  String _tipoTalla = 'adulto'; // 'adulto' | 'niño'

  static const _categorias = [
    'Automotriz',
    'Electrónica',
    'Hogar',
    'Ropa',
    'Calzado',
    'Deportes',
    'Ocio',
    'Mascotas',
    'Salud',
    'Construcción',
    'Fotografía',
    'Educación',
    'Negocios',
    'General',
  ];

  static const _tallasRopaAdulto = ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
  static const _tallasRopaNino   = ['2', '4', '6', '8', '10', '12', '14', '16'];
  static const _tallasZapatoAdulto = ['36', '37', '38', '39', '40', '41', '42', '43', '44', '45'];
  static const _tallasZapatoNino   = ['20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34'];

  bool get _esRopaOCalzado => _categoria == 'Ropa' || _categoria == 'Calzado';

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _precio.dispose();
    super.dispose();
  }

  // ── Selector de fuente de imagen ─────────────────────────────────────────
  Future<ImageSource?> _elegirFuente() async {
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
              width: 40,
              height: 4,
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
    final foto =
        await _picker.pickImage(source: source, imageQuality: 80);
    if (foto == null) return;
    setState(() => _imagenes.add(File(foto.path)));
  }

  // ── Publicar ─────────────────────────────────────────────────────────────
  Future<void> _publicar() async {
    if (_imagenes.isEmpty) {
      _snack("Agrega al menos una foto");
      return;
    }
    if (_titulo.text.trim().isEmpty) {
      _snack("Ingresa un título");
      return;
    }
    if (_precio.text.trim().isEmpty) {
      _snack("Ingresa un precio");
      return;
    }

    setState(() => _publicando = true);

    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("${ApiService.baseUrl}/publicar"),
      );

      request.fields["titulo"] = _titulo.text.trim();
      request.fields["descripcion"] = _descripcion.text.trim();
      request.fields["precio"] = _precio.text.trim();
      request.fields["categoria"] = _categoria;
      request.fields["condicion"] = _condicion;
      request.fields["acepta_ofertas"] = _aceptaOfertas ? "1" : "0";
      if (_esRopaOCalzado && _tallasSeleccionadas.isNotEmpty) {
        request.fields["tallas"] = jsonEncode({
          'tipo': _tipoTalla,
          'valores': _tallasSeleccionadas.toList(),
        });
      }

      final session = await SessionService.obtenerSesion();
      if (session["user_id"] != null) {
        request.fields["user_id"] = session["user_id"].toString();
      } else {
        request.fields["guest_id"] = session["guest_id"].toString();
      }

      // Foto principal + extras (hasta 4 en total)
      request.files.add(
          await http.MultipartFile.fromPath("file", _imagenes[0].path));
      if (_imagenes.length > 1) {
        request.files.add(
            await http.MultipartFile.fromPath("file2", _imagenes[1].path));
      }
      if (_imagenes.length > 2) {
        request.files.add(
            await http.MultipartFile.fromPath("file3", _imagenes[2].path));
      }
      if (_imagenes.length > 3) {
        request.files.add(
            await http.MultipartFile.fromPath("file4", _imagenes[3].path));
      }

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (!mounted) return;
      setState(() => _publicando = false);

      if (response.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MisPublicacionesScreen()),
        );
      } else {
        debugPrint("ERROR PUBLICAR MANUAL: $respStr");
        _snack("Error al publicar. Intenta de nuevo.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _publicando = false);
      _snack("Error de conexión. Verifica tu red.");
    }
  }

  void _snack(String msg) {
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

  // ── Build ─────────────────────────────────────────────────────────────────
  // ── Pantalla de espera con Space Invaders ─────────────────────────────────
  Widget _buildPublicando() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          color: AppColors.surface,
          child: const Column(
            children: [
              Text(
                "Publicando tu producto…",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Mientras suben las fotos, ¡juega un poco!",
                style: TextStyle(fontSize: 13, color: AppColors.grayMid),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
        const Expanded(child: SpaceInvadersWidget()),
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Procesando y subiendo imágenes…",
                style: TextStyle(fontSize: 12, color: AppColors.grayMid),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Publicación manual",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Image.asset('assets/images/chekin.png',
                  width: 28, height: 28),
            ),
          ),
        ],
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.carbon),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppColors.divider, height: 0.5),
        ),
      ),
      body: _publicando
          ? _buildPublicando()

          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildFotosSection(),
                const SizedBox(height: 24),
                _buildCampo("Título *", _titulo),
                _buildCampoMultilinea("Descripción", _descripcion),
                _buildCondicion(),
                _buildAceptaOfertas(),
                _buildCampoPrecio(),
                _buildDropdownCategoria(),
                if (_esRopaOCalzado) _buildSelectorTallas(),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _publicar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
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
    );
  }

  // ── Sección de fotos ──────────────────────────────────────────────────────
  Widget _buildFotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Fotos del producto",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Hasta 4 fotos · La primera será la imagen principal",
          style: TextStyle(fontSize: 12, color: AppColors.grayMid),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._imagenes.asMap().entries.map(
                    (e) => _buildThumb(e.key, e.value),
                  ),
              if (_imagenes.length < 4) _buildAddBtn(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThumb(int index, File file) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file,
              width: 110,
              height: 110,
              fit: BoxFit.cover,
            ),
          ),
          // Badge "Principal"
          if (index == 0)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "Principal",
                  style: TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          // Botón quitar
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: () => setState(() => _imagenes.removeAt(index)),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.carbon.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: AppColors.surface, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddBtn() {
    return GestureDetector(
      onTap: _agregarFoto,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.divider, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined,
                color: AppColors.grayMid, size: 28),
            const SizedBox(height: 4),
            Text(
              _imagenes.isEmpty ? "Agregar foto" : "Agregar más",
              style: const TextStyle(
                  fontSize: 11, color: AppColors.grayMid),
            ),
          ],
        ),
      ),
    );
  }

  // ── Campos de formulario ──────────────────────────────────────────────────
  Widget _buildCampo(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(
            fontSize: 15, color: AppColors.textPrimary),
        decoration: _inputDeco(label),
      ),
    );
  }

  Widget _buildCampoMultilinea(
      String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        maxLines: 3,
        style: const TextStyle(
            fontSize: 15, color: AppColors.textPrimary),
        decoration: _inputDeco(label),
      ),
    );
  }

  Widget _buildCampoPrecio() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: _precio,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
            fontSize: 15, color: AppColors.textPrimary),
        decoration: _inputDeco("Precio *").copyWith(
          prefixText: "\$ ",
          prefixStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownCategoria() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _categoria,
            isExpanded: true,
            style: const TextStyle(
                fontSize: 15, color: AppColors.textPrimary),
            items: _categorias
                .map((c) =>
                    DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() {
              _categoria = v ?? 'General';
              _tallasSeleccionadas = {};
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildCondicion() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estado del producto',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Row(
            children: [
              _condicionChip('nuevo', 'Nuevo', Icons.star_outline_rounded),
              const SizedBox(width: 10),
              _condicionChip('usado', 'Usado', Icons.recycling_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _condicionChip(String valor, String label, IconData icono) {
    final sel = _condicion == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _condicion = valor),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary.withOpacity(0.08) : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? AppColors.primary : AppColors.divider,
              width: sel ? 1.5 : 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono,
                  size: 16,
                  color: sel ? AppColors.primary : AppColors.grayMid),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: sel ? AppColors.primary : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAceptaOfertas() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => setState(() => _aceptaOfertas = !_aceptaOfertas),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider, width: 0.8),
          ),
          child: Row(
            children: [
              Icon(Icons.handshake_outlined,
                  size: 18,
                  color: _aceptaOfertas ? AppColors.primary : AppColors.grayMid),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Acepto ofertas o canjes',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    Text('Otros usuarios podrán proponer un precio o canje',
                        style: TextStyle(fontSize: 11, color: AppColors.grayMid)),
                  ],
                ),
              ),
              Switch(
                value: _aceptaOfertas,
                onChanged: (v) => setState(() => _aceptaOfertas = v),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Selector de tallas ────────────────────────────────────────────────────
  List<String> get _tallasList {
    if (_categoria == 'Ropa') {
      return _tipoTalla == 'adulto' ? _tallasRopaAdulto : _tallasRopaNino;
    } else {
      return _tipoTalla == 'adulto' ? _tallasZapatoAdulto : _tallasZapatoNino;
    }
  }

  Widget _buildSelectorTallas() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tallas disponibles',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _mostrarGuiaTallas,
                child: const Row(
                  children: [
                    Icon(Icons.straighten_rounded, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Guía de tallas',
                      style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Toggle adulto / niño
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: Row(
              children: ['adulto', 'niño'].map((tipo) {
                final sel = _tipoTalla == tipo;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _tipoTalla = tipo;
                      _tallasSeleccionadas = {};
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tipo == 'adulto' ? 'Adulto' : 'Niño/a',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? AppColors.textOnPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Chips de tallas
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tallasList.map((t) {
              final sel = _tallasSeleccionadas.contains(t);
              return GestureDetector(
                onTap: () => setState(() {
                  if (sel) {
                    _tallasSeleccionadas.remove(t);
                  } else {
                    _tallasSeleccionadas.add(t);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 52,
                  height: 40,
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary.withOpacity(0.10) : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sel ? AppColors.primary : AppColors.divider,
                      width: sel ? 1.5 : 0.8,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_tallasSeleccionadas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Seleccionadas: ${_tallasSeleccionadas.join(', ')}',
              style: const TextStyle(fontSize: 11, color: AppColors.grayMid),
            ),
          ],
        ],
      ),
    );
  }

  void _mostrarGuiaTallas() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.70,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, ctrl) => _GuiaTallasSheet(
          esCalzado: _categoria == 'Calzado',
          scrollController: ctrl,
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
          color: AppColors.grayMid, fontSize: 14),
      filled: true,
      fillColor: AppColors.surface,
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
    );
  }
}

// ── Guía de tallas (bottom sheet) ─────────────────────────────────────────

class _GuiaTallasSheet extends StatefulWidget {
  final bool esCalzado;
  final ScrollController scrollController;
  const _GuiaTallasSheet({required this.esCalzado, required this.scrollController});

  @override
  State<_GuiaTallasSheet> createState() => _GuiaTallasSheetState();
}

class _GuiaTallasSheetState extends State<_GuiaTallasSheet> {
  String _tipo = 'adulto';

  static const _ropaAdulto = [
    ['XS',    '78–83',  '60–65',  '86–91'],
    ['S',     '84–89',  '66–71',  '92–97'],
    ['M',     '90–95',  '72–77',  '98–103'],
    ['L',     '96–101', '78–83',  '104–109'],
    ['XL',    '102–107','84–89',  '110–115'],
    ['XXL',   '108–113','90–95',  '116–121'],
    ['XXXL',  '114–119','96–101', '122–127'],
  ];

  static const _ropaNino = [
    ['2',  '92'],
    ['4',  '104'],
    ['6',  '116'],
    ['8',  '128'],
    ['10', '140'],
    ['12', '152'],
    ['14', '164'],
    ['16', '176'],
  ];

  static const _zapatoAdulto = [
    ['36', '22.5'],
    ['37', '23.0'],
    ['38', '23.5'],
    ['39', '24.5'],
    ['40', '25.0'],
    ['41', '25.5'],
    ['42', '26.5'],
    ['43', '27.0'],
    ['44', '27.5'],
    ['45', '28.5'],
  ];

  static const _zapatoNino = [
    ['20', '12.5'],
    ['21', '13.0'],
    ['22', '13.5'],
    ['23', '14.5'],
    ['24', '15.0'],
    ['25', '15.5'],
    ['26', '16.5'],
    ['27', '17.0'],
    ['28', '17.5'],
    ['29', '18.5'],
    ['30', '19.0'],
    ['31', '19.5'],
    ['32', '20.5'],
    ['33', '21.0'],
    ['34', '21.5'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                widget.esCalzado ? 'Guía de tallas — Calzado' : 'Guía de tallas — Ropa',
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.grayMid),
              ),
            ],
          ),
        ),
        // Toggle adulto / niño
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: Row(
              children: ['adulto', 'niño'].map((tipo) {
                final sel = _tipo == tipo;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tipo = tipo),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tipo == 'adulto' ? 'Adulto' : 'Niño/a',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? AppColors.textOnPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Tabla
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: widget.esCalzado ? _tablaCalzado() : _tablaRopa(),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _tablaRopa() {
    final filas = _tipo == 'adulto' ? _ropaAdulto : _ropaNino;
    final isAdulto = _tipo == 'adulto';
    return Table(
      border: TableBorder.all(color: AppColors.divider, width: 0.5),
      columnWidths: isAdulto
          ? const {0: FixedColumnWidth(48), 1: FlexColumnWidth(), 2: FlexColumnWidth(), 3: FlexColumnWidth()}
          : const {0: FixedColumnWidth(48), 1: FlexColumnWidth()},
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.background),
          children: [
            _th('Talla'),
            if (isAdulto) ...[_th('Pecho\n(cm)'), _th('Cintura\n(cm)'), _th('Cadera\n(cm)')],
            if (!isAdulto) _th('Altura (cm)'),
          ],
        ),
        ...filas.map((f) => TableRow(
          children: f.map((c) => _td(c)).toList(),
        )),
      ],
    );
  }

  Widget _tablaCalzado() {
    final filas = _tipo == 'adulto' ? _zapatoAdulto : _zapatoNino;
    return Table(
      border: TableBorder.all(color: AppColors.divider, width: 0.5),
      columnWidths: const {0: FixedColumnWidth(60), 1: FlexColumnWidth()},
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.background),
          children: [_th('Talla'), _th('Pie (cm)')],
        ),
        ...filas.map((f) => TableRow(children: f.map((c) => _td(c)).toList())),
      ],
    );
  }

  Widget _th(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(t, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      );

  Widget _td(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Text(t, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
      );
}
