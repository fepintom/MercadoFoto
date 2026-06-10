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
  final List<File> _imagenes = [];
  bool _publicando = false;
  final _picker = ImagePicker();

  // ── Delivery ──────────────────────────────────────────────────────────
  int? _deliveryId;
  List<Map<String, dynamic>> _deliveryWorkers = [];

  static const _categorias = [
    'Electrónica',
    'Automotriz',
    'Hogar',
    'Ocio',
    'Mascotas',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    _cargarDelivery();
  }

  Future<void> _cargarDelivery() async {
    try {
      final workers = await ApiService.obtenerDelivery(soloActivos: true);
      if (mounted) setState(() => _deliveryWorkers = workers);
    } catch (_) {}
  }

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
      if (_deliveryId != null) {
        request.fields["delivery_id"] = '$_deliveryId';
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
                _buildCampoPrecio(),
                _buildDropdownCategoria(),
                _buildDeliverySection(),
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
            onChanged: (v) =>
                setState(() => _categoria = v ?? 'General'),
          ),
        ),
      ),
    );
  }

  // ── Delivery selector ──────────────────────────────────────────────────────
  Widget _buildDeliverySection() {
    final selectedWorker = _deliveryId == null
        ? null
        : _deliveryWorkers.where((d) => d['id'] == _deliveryId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          '🚴 Método de entrega',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),

        // Yo entrego
        GestureDetector(
          onTap: () => setState(() => _deliveryId = null),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: _deliveryId == null
                  ? AppColors.primary.withOpacity(0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _deliveryId == null
                    ? AppColors.primary
                    : AppColors.divider,
                width: _deliveryId == null ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: AppColors.grayMid),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Yo hago la entrega',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                if (_deliveryId == null)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 18),
              ],
            ),
          ),
        ),

        // Delivery OkVenta
        if (_deliveryWorkers.isNotEmpty)
          GestureDetector(
            onTap: () async {
              final elegido =
                  await showModalBottomSheet<Map<String, dynamic>>(
                context: context,
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) =>
                    _DeliveryPickerSheet(workers: _deliveryWorkers),
              );
              if (elegido != null && mounted) {
                setState(() => _deliveryId = elegido['id'] as int?);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: _deliveryId != null
                    ? Colors.green.withOpacity(0.06)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _deliveryId != null
                      ? Colors.green.withOpacity(0.5)
                      : AppColors.divider,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.delivery_dining_rounded,
                      color: _deliveryId != null
                          ? Colors.green
                          : AppColors.grayMid),
                  const SizedBox(width: 10),
                  Expanded(
                    child: selectedWorker != null
                        ? Text(
                            '${selectedWorker['nombre']} — ${selectedWorker['tipo_vehiculo']}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          )
                        : const Text(
                            'Delivery OkVenta — elegir...',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.grayMid),
                          ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.grayMid, size: 16),
                ],
              ),
            ),
          ),
      ],
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

// ── Delivery picker bottom sheet ──────────────────────────────────────────────

class _DeliveryPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> workers;
  const _DeliveryPickerSheet({required this.workers});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2)),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Seleccionar Delivery OkVenta',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: workers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = workers[i];
              final nombre   = d['nombre'] as String? ?? 'Delivery';
              final vehiculo = d['tipo_vehiculo'] as String? ?? 'bicicleta';
              final radio    = (d['radio_km'] as num?)?.toStringAsFixed(0) ?? '5';
              final fotoUrl  = d['foto_perfil'] as String? ?? '';
              final iconos = {
                'bicicleta': Icons.directions_bike_rounded,
                'moto':      Icons.two_wheeler_rounded,
                'auto':      Icons.directions_car_rounded,
              };
              return GestureDetector(
                onTap: () => Navigator.pop(context, d),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            AppColors.primary.withOpacity(0.1),
                        backgroundImage: fotoUrl.isNotEmpty
                            ? NetworkImage(
                                '${ApiService.baseUrl}$fotoUrl')
                            : null,
                        child: fotoUrl.isEmpty
                            ? Text(nombre[0].toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            Row(
                              children: [
                                Icon(
                                    iconos[vehiculo] ??
                                        Icons.delivery_dining_outlined,
                                    size: 12,
                                    color: AppColors.grayMid),
                                const SizedBox(width: 4),
                                Text('$vehiculo  •  $radio km',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.grayMid)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.grayMid, size: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
