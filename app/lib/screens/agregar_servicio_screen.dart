import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

class AgregarServicioScreen extends StatefulWidget {
  final String tipoInicial;
  const AgregarServicioScreen({super.key, this.tipoInicial = 'ofrezco'});

  @override
  State<AgregarServicioScreen> createState() =>
      _AgregarServicioScreenState();
}

class _AgregarServicioScreenState extends State<AgregarServicioScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _tituloCtrl  = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _comunasCtrl = TextEditingController();
  final _valorCtrl   = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _wsCtrl      = TextEditingController();

  late String _tipo;
  String _modalidad = 'servicio';
  List<XFile> _medios = [];
  XFile? _certificado;
  bool _enviando = false;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _tipo = widget.tipoInicial;
    _cargarUsuario();
  }

  @override
  void dispose() {
    for (final c in [
      _tituloCtrl, _descCtrl, _comunasCtrl,
      _valorCtrl, _telefonoCtrl, _wsCtrl
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _cargarUsuario() async {
    _userId = await SessionService.obtenerUser();
    if (_userId == null && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _elegirMedio() async {
    if (_medios.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 2 archivos (fotos o videos)')));
      return;
    }
    final picker = ImagePicker();
    final opcion = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: const Text('Foto desde galería'),
              onTap: () => Navigator.pop(context, 'foto'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined,
                  color: AppColors.primary),
              title: const Text('Video desde galería (máx. 15 seg)'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.primary),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, 'camara'),
            ),
          ],
        ),
      ),
    );
    if (opcion == null) return;

    XFile? file;
    if (opcion == 'foto') {
      file = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
    } else if (opcion == 'video') {
      file = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(seconds: 15));
    } else {
      file = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 85);
    }

    if (file != null && mounted) {
      setState(() => _medios.add(file!));
    }
  }

  Future<void> _elegirCertificado() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 90);
    if (file != null && mounted) {
      setState(() => _certificado = file);
    }
  }

  Future<void> _publicar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_userId == null) return;

    setState(() => _enviando = true);

    try {
      final uri  = Uri.parse('${ApiService.baseUrl}/servicios');
      final req  = http.MultipartRequest('POST', uri);

      req.fields['user_id']     = _userId.toString();
      req.fields['tipo']        = _tipo;
      req.fields['titulo']      = _tituloCtrl.text.trim();
      req.fields['descripcion'] = _descCtrl.text.trim();
      req.fields['comunas']     = _comunasCtrl.text.trim();
      req.fields['valor']       = _valorCtrl.text.trim().isEmpty
          ? '0'
          : _valorCtrl.text.trim();
      req.fields['modalidad']   = _modalidad;
      req.fields['telefono']    = _telefonoCtrl.text.trim();
      req.fields['whatsapp']    = _wsCtrl.text.trim();

      for (final m in _medios) {
        req.files.add(await http.MultipartFile.fromPath('fotos', m.path));
      }

      final streamed = await req.send();
      final body     = await streamed.stream.bytesToString();
      final data     = jsonDecode(body);

      if (streamed.statusCode == 200 && data['id'] != null) {
        // Subir certificado si fue seleccionado
        if (_certificado != null) {
          final certUri =
              Uri.parse('${ApiService.baseUrl}/servicios/${data['id']}/certificado');
          final certReq = http.MultipartRequest('POST', certUri);
          certReq.fields['user_id'] = _userId.toString();
          certReq.files.add(
              await http.MultipartFile.fromPath('archivo', _certificado!.path));
          final certResp = await certReq.send();
          final certBody =
              jsonDecode(await certResp.stream.bytesToString());

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(certBody['mensaje'] ?? 'Certificado procesado'),
              backgroundColor: AppColors.primary,
            ));
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Servicio publicado con éxito'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al publicar: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_tipo == 'busco' ? 'Publicar solicitud' : 'Publicar servicio',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.divider),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Tipo ─────────────────────────────────────────────────────
              _label('¿Qué quieres publicar?'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chipTipo('ofrezco', 'Ofrezco un servicio',
                      Icons.handyman_outlined),
                  const SizedBox(width: 10),
                  _chipTipo('busco', 'Busco un servicio',
                      Icons.search_rounded),
                ],
              ),

              const SizedBox(height: 20),

              // ── Fotos / Videos ────────────────────────────────────────────
              _label('Fotos o videos del servicio (máx. 2)'),
              const SizedBox(height: 8),
              Row(
                children: [
                  ..._medios.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(e.value.path),
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 90,
                                  height: 90,
                                  color: AppColors.background,
                                  child: const Icon(Icons.videocam,
                                      color: AppColors.primary, size: 32),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setState(
                                    () => _medios.removeAt(e.key)),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (_medios.length < 2)
                    GestureDetector(
                      onTap: _elegirMedio,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.4),
                              style: BorderStyle.solid),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: AppColors.primary, size: 28),
                            SizedBox(height: 4),
                            Text('Agregar',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Título ────────────────────────────────────────────────────
              _label('Título del servicio *'),
              const SizedBox(height: 8),
              _campo(_tituloCtrl, 'Ej: Gasfitería y reparaciones del hogar',
                  required: true),

              const SizedBox(height: 16),

              // ── Descripción ───────────────────────────────────────────────
              _label('Detalle del servicio'),
              const SizedBox(height: 8),
              _campo(_descCtrl,
                  'Describe qué incluye tu servicio, experiencia, etc.',
                  maxLines: 4),

              const SizedBox(height: 16),

              // ── Comunas ───────────────────────────────────────────────────
              _label('Comunas de cobertura'),
              const SizedBox(height: 8),
              _campo(_comunasCtrl,
                  'Ej: Providencia, Ñuñoa, Las Condes, Santiago'),

              const SizedBox(height: 16),

              // ── Valor + modalidad ─────────────────────────────────────────
              _label('Valor del servicio'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: _deco('\$', hint: '0'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      _chipModalidad('hora', 'Por hora'),
                      const SizedBox(height: 6),
                      _chipModalidad('servicio', 'Por servicio'),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Teléfono / WhatsApp ───────────────────────────────────────
              _label('Teléfono de contacto'),
              const SizedBox(height: 8),
              _campo(_telefonoCtrl, 'Ej: 912345678',
                  tipo: TextInputType.phone),

              const SizedBox(height: 12),

              _label('WhatsApp (si es diferente)'),
              const SizedBox(height: 8),
              _campo(_wsCtrl, 'Ej: 987654321',
                  tipo: TextInputType.phone),

              const SizedBox(height: 24),

              // ── Certificado profesional ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.amber.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified,
                            color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Certificado profesional',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sube tu certificado con código QR para obtener la insignia de Profesional Certificado OkVenta.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.grayMid),
                    ),
                    const SizedBox(height: 12),
                    if (_certificado != null)
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _certificado!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _certificado = null),
                            child: const Text('Eliminar',
                                style: TextStyle(
                                    color: Colors.red, fontSize: 12)),
                          ),
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _elegirCertificado,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Subir certificado',
                            style: TextStyle(
                                fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber.shade800,
                          side:
                              BorderSide(color: Colors.amber.shade400),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Publicar ──────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _enviando ? null : _publicar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Publicar servicio',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary));

  Widget _campo(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    bool required = false,
    TextInputType tipo = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: tipo,
      textCapitalization: TextCapitalization.sentences,
      decoration: _deco(null, hint: hint),
      validator: required
          ? (v) =>
              (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
          : null,
    );
  }

  InputDecoration _deco(String? prefix, {String hint = ''}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      hintStyle:
          const TextStyle(color: AppColors.grayMid, fontSize: 14),
      filled: true,
      fillColor: AppColors.surface,
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _chipTipo(String valor, String label, IconData icono) {
    final sel = _tipo == valor;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tipo = valor),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    sel ? AppColors.primary : AppColors.divider,
                width: sel ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icono,
                  color:
                      sel ? AppColors.primary : AppColors.grayMid,
                  size: 22),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          sel ? AppColors.primary : AppColors.grayMid)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipModalidad(String valor, String label) {
    final sel = _modalidad == valor;
    return GestureDetector(
      onTap: () => setState(() => _modalidad = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: sel ? AppColors.primary : AppColors.divider,
              width: sel ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    sel ? AppColors.primary : AppColors.grayMid)),
      ),
    );
  }
}
