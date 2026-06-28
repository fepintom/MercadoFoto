import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'mapa_ubicacion_picker_screen.dart';

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
  String _modalidad  = 'servicio';
  String _categoria  = 'Otros';
  String _colorHex   = '#007AFF';
  List<XFile> _medios = [];
  XFile? _certificado;
  bool _enviando = false;
  int? _userId;

  // Ubicación
  double? _lat;
  double? _lng;
  double  _radioKm = 5.0;
  bool    _cargandoUbicacion = false;

  static const _kCategorias = [
    'Hogar', 'Tecnología', 'Transporte', 'Educación', 'Salud',
    'Belleza', 'Construcción', 'Fotografía', 'Limpieza', 'Mascotas',
    'Negocios', 'Otros',
  ];
  static const _kColores = [
    Color(0xFF007AFF), Color(0xFF34C759), Color(0xFFFF9500),
    Color(0xFFFF3B30), Color(0xFFAF52DE), Color(0xFF5AC8FA),
    Color(0xFFFFCC00), Color(0xFFFF2D55), Color(0xFF00C7BE),
    Color(0xFF636366),
  ];

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

  // ── Ubicación: GPS ────────────────────────────────────────────────────────
  Future<void> _usarGPS() async {
    setState(() => _cargandoUbicacion = true);
    try {
      bool servicio = await Geolocator.isLocationServiceEnabled();
      if (!servicio) {
        _snack('El servicio de ubicación está desactivado');
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _snack('Permiso de ubicación denegado');
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _snack('Permiso permanentemente denegado. Actívalo en Ajustes.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
        _snack('📍 Ubicación actual registrada', color: Colors.green);
      }
    } catch (e) {
      _snack('Error al obtener ubicación: $e');
    } finally {
      if (mounted) setState(() => _cargandoUbicacion = false);
    }
  }

  // ── Ubicación: dirección del perfil → Nominatim ────────────────────────────
  Future<void> _usarDireccionPerfil() async {
    setState(() => _cargandoUbicacion = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final direccion = prefs.getString('direccion') ?? '';
      final comuna    = prefs.getString('comuna')    ?? '';
      final ciudad    = prefs.getString('ciudad')    ?? '';
      final query     = [direccion, comuna, ciudad, 'Chile']
          .where((s) => s.isNotEmpty)
          .join(', ');

      if (query.trim() == 'Chile' || query.trim().isEmpty) {
        _snack('Completa tu dirección en el perfil primero');
        return;
      }

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&format=json&limit=1',
      );
      final resp = await http.get(uri,
          headers: {'User-Agent': 'OkVenta/1.0 contact@okventa.cl'});

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        if (data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat'] as String);
          final lng = double.tryParse(data[0]['lon'] as String);
          if (lat != null && lng != null && mounted) {
            setState(() {
              _lat = lat;
              _lng = lng;
            });
            _snack('📍 Dirección del perfil ubicada', color: Colors.green);
            return;
          }
        }
      }
      _snack('No se pudo ubicar la dirección del perfil');
    } catch (e) {
      _snack('Error al geocodificar: $e');
    } finally {
      if (mounted) setState(() => _cargandoUbicacion = false);
    }
  }

  // ── Ubicación: picker de mapa ──────────────────────────────────────────────
  Future<void> _usarMapa() async {
    final result = await Navigator.push<UbicacionElegida>(
      context,
      MaterialPageRoute(
        builder: (_) => MapaUbicacionPickerScreen(
          latInicial: _lat,
          lngInicial: _lng,
          radioKmInicial: _radioKm,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _lat     = result.lat;
        _lng     = result.lng;
        _radioKm = result.radioKm;
      });
    }
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color ?? AppColors.carbon,
      behavior: SnackBarBehavior.floating,
    ));
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
      req.fields['categoria']   = _categoria;
      req.fields['color_hex']   = _colorHex;
      if (_lat != null && _lng != null) {
        req.fields['lat']      = _lat.toString();
        req.fields['lng']      = _lng.toString();
        req.fields['radio_km'] = _radioKm.toStringAsFixed(1);
      }

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

              // ── Categoría ─────────────────────────────────────────────────
              _label('Categoría'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _kCategorias.map((cat) {
                  final sel = _categoria == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _categoria = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.primary.withOpacity(0.12)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? AppColors.primary : AppColors.divider,
                          width: sel ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: sel
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ── Color del aviso ───────────────────────────────────────────
              _label('Color del aviso'),
              const SizedBox(height: 4),
              const Text(
                'Así se verá tu tarjeta en el mapa y en la lista',
                style: TextStyle(fontSize: 12, color: AppColors.grayMid),
              ),
              const SizedBox(height: 10),
              Row(
                children: _kColores.map((c) {
                  final hex =
                      '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
                  final sel = _colorHex.toUpperCase() == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: sel
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                    color: c.withOpacity(0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1)
                              ]
                            : null,
                      ),
                      child: sel
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14)
                          : null,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

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
              const SizedBox(height: 4),
              const Text(
                'Solo el número sin +56 — se agrega automáticamente',
                style: TextStyle(fontSize: 11, color: AppColors.grayMid),
              ),
              const SizedBox(height: 8),
              _campo(_telefonoCtrl, 'Ej: 912345678  (prefijo 9, 8, 7…)',
                  tipo: TextInputType.phone),

              const SizedBox(height: 12),

              _label('WhatsApp (si es diferente)'),
              const SizedBox(height: 4),
              const Text(
                'Solo el número sin +56',
                style: TextStyle(fontSize: 11, color: AppColors.grayMid),
              ),
              const SizedBox(height: 8),
              _campo(_wsCtrl, 'Ej: 987654321',
                  tipo: TextInputType.phone),

              const SizedBox(height: 24),

              // ── Ubicación ─────────────────────────────────────────────────
              _label('Ubicación del servicio'),
              const SizedBox(height: 4),
              const Text(
                'Elige cómo registrar tu área de cobertura en el mapa',
                style: TextStyle(fontSize: 12, color: AppColors.grayMid),
              ),
              const SizedBox(height: 10),

              // 3 opciones
              Row(
                children: [
                  _botonUbicacion(
                    icon: Icons.my_location_rounded,
                    label: 'GPS actual',
                    onTap: _cargandoUbicacion ? null : _usarGPS,
                  ),
                  const SizedBox(width: 8),
                  _botonUbicacion(
                    icon: Icons.home_outlined,
                    label: 'Mi perfil',
                    onTap: _cargandoUbicacion ? null : _usarDireccionPerfil,
                  ),
                  const SizedBox(width: 8),
                  _botonUbicacion(
                    icon: Icons.map_outlined,
                    label: 'En el mapa',
                    onTap: _cargandoUbicacion ? null : _usarMapa,
                  ),
                ],
              ),

              // Resultado de ubicación elegida
              if (_cargandoUbicacion)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary)),
                      SizedBox(width: 8),
                      Text('Obteniendo ubicación...',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.grayMid)),
                    ],
                  ),
                )
              else if (_lat != null && _lng != null)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ubicación registrada  •  Radio: ${_radioKm.toStringAsFixed(0)} km',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      // Ajustar radio inline
                      GestureDetector(
                        onTap: _usarMapa,
                        child: const Text('Ajustar',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ),

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

  Widget _botonUbicacion({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: onTap == null
                ? AppColors.background
                : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: onTap == null
                      ? AppColors.grayMid
                      : AppColors.primary,
                  size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: onTap == null
                          ? AppColors.grayMid
                          : AppColors.textPrimary)),
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
