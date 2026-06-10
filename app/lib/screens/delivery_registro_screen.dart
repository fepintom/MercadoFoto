import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'mapa_ubicacion_picker_screen.dart';

class DeliveryRegistroScreen extends StatefulWidget {
  /// Si no es null, se pasa el perfil existente para editar/ver
  final Map<String, dynamic>? perfilExistente;
  const DeliveryRegistroScreen({super.key, this.perfilExistente});

  @override
  State<DeliveryRegistroScreen> createState() => _DeliveryRegistroScreenState();
}

class _DeliveryRegistroScreenState extends State<DeliveryRegistroScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _picker    = ImagePicker();

  // ── Campos de texto ──────────────────────────────────────────────────────
  final _nombreCtrl      = TextEditingController();
  final _edadCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _rutCtrl         = TextEditingController();
  final _telefonoCtrl    = TextEditingController();
  final _direccionCtrl   = TextEditingController();
  final _patenteCtrl     = TextEditingController();
  final _bancoCtrl       = TextEditingController();
  final _cuentaCtrl      = TextEditingController();

  String _tipoVehiculo = 'bicicleta';

  // ── Fotos ────────────────────────────────────────────────────────────────
  File? _fotoPerfil;
  File? _fotoVehiculo;
  File? _fotoCiFrente;
  File? _fotoCiReverso;
  File? _selfie;

  // ── Ubicación ────────────────────────────────────────────────────────────
  double? _lat;
  double? _lng;
  double  _radioKm = 5.0;

  // ── Estado ───────────────────────────────────────────────────────────────
  bool _aceptoTerminos = false;
  bool _guardando      = false;
  int? _userId;
  int? _deliveryId;  // si ya existe un perfil

  @override
  void initState() {
    super.initState();
    _cargarUserId();
    _precargar();
  }

  Future<void> _cargarUserId() async {
    _userId = await SessionService.obtenerUser();
    setState(() {});
  }

  void _precargar() {
    final p = widget.perfilExistente;
    if (p == null) return;
    _deliveryId      = p['id'] as int?;
    _nombreCtrl.text = p['nombre'] as String? ?? '';
    _edadCtrl.text   = '${p['edad'] ?? ''}';
    _emailCtrl.text  = p['email'] as String? ?? '';
    _rutCtrl.text    = p['rut'] as String? ?? '';
    _telefonoCtrl.text   = p['telefono'] as String? ?? '';
    _direccionCtrl.text  = p['direccion'] as String? ?? '';
    _patenteCtrl.text    = p['patente'] as String? ?? '';
    _bancoCtrl.text      = p['banco'] as String? ?? '';
    _cuentaCtrl.text     = p['cuenta_banco'] as String? ?? '';
    _tipoVehiculo        = p['tipo_vehiculo'] as String? ?? 'bicicleta';
    _lat                 = (p['lat'] as num?)?.toDouble();
    _lng                 = (p['lng'] as num?)?.toDouble();
    _radioKm             = (p['radio_km'] as num?)?.toDouble() ?? 5.0;
    _aceptoTerminos      = (p['acepto_terminos'] as int? ?? 0) == 1;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _edadCtrl.dispose(); _emailCtrl.dispose();
    _rutCtrl.dispose(); _telefonoCtrl.dispose(); _direccionCtrl.dispose();
    _patenteCtrl.dispose(); _bancoCtrl.dispose(); _cuentaCtrl.dispose();
    super.dispose();
  }

  // ── Tomar foto con cámara (NO galería) ───────────────────────────────────
  Future<File?> _tomarFoto() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (xfile == null) return null;
    return File(xfile.path);
  }

  // ── Elegir sector en mapa ─────────────────────────────────────────────────
  Future<void> _elegirUbicacion() async {
    final result = await Navigator.push<UbicacionElegida>(
      context,
      MaterialPageRoute(
        builder: (_) => MapaUbicacionPickerScreen(
          latInicial:     _lat ?? -33.4489,
          lngInicial:     _lng ?? -70.6693,
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

  // ── Guardar ───────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceptoTerminos) {
      _snack('Debes aceptar los términos y condiciones', error: true);
      return;
    }
    if (_userId == null) {
      _snack('Debes iniciar sesión', error: true);
      return;
    }

    // Fotos mínimas requeridas (perfil + CI frente + selfie)
    final tieneNuevas = _fotoPerfil != null || _fotoCiFrente != null || _selfie != null;
    final esNuevo = _deliveryId == null;
    if (esNuevo && (_fotoPerfil == null || _fotoCiFrente == null || _selfie == null)) {
      _snack('Debes tomar foto de perfil, CI frente y selfie con CI', error: true);
      return;
    }

    setState(() => _guardando = true);
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/delivery');
      final req = http.MultipartRequest('POST', uri);

      req.fields['user_id']       = '$_userId';
      req.fields['nombre']        = _nombreCtrl.text.trim();
      req.fields['edad']          = _edadCtrl.text.trim();
      req.fields['email']         = _emailCtrl.text.trim();
      req.fields['rut']           = _rutCtrl.text.trim();
      req.fields['telefono']      = _telefonoCtrl.text.trim();
      req.fields['direccion']     = _direccionCtrl.text.trim();
      req.fields['tipo_vehiculo'] = _tipoVehiculo;
      req.fields['patente']       = _patenteCtrl.text.trim();
      req.fields['banco']         = _bancoCtrl.text.trim();
      req.fields['cuenta_banco']  = _cuentaCtrl.text.trim();
      req.fields['radio_km']      = '$_radioKm';
      if (_lat != null) req.fields['lat'] = '$_lat';
      if (_lng != null) req.fields['lng'] = '$_lng';

      Future<void> adjuntar(File? f, String field) async {
        if (f == null) return;
        req.files.add(await http.MultipartFile.fromPath(field, f.path));
      }
      await adjuntar(_fotoPerfil,    'foto_perfil');
      await adjuntar(_fotoVehiculo,  'foto_vehiculo');
      await adjuntar(_fotoCiFrente,  'foto_ci_frente');
      await adjuntar(_fotoCiReverso, 'foto_ci_reverso');
      await adjuntar(_selfie,        'selfie_ci');

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        if (mounted) {
          _snack('✅ Perfil de delivery guardado correctamente');
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) Navigator.pop(context, true);
        }
      } else {
        _snack('Error al guardar: $body', error: true);
      }
    } catch (e) {
      _snack('Error de conexión: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.carbon,
        foregroundColor: Colors.white,
        title: const Text(
          'Registro Delivery OkVenta',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _seccion('📋 Datos personales'),
            _campo(_nombreCtrl,   'Nombre completo', Icons.person_outline,  obligatorio: true),
            _campo(_edadCtrl,     'Edad',            Icons.cake_outlined,    teclado: TextInputType.number),
            _campo(_emailCtrl,    'Correo electrónico', Icons.email_outlined, teclado: TextInputType.emailAddress),
            _campo(_rutCtrl,      'RUT (ej: 12.345.678-9)', Icons.badge_outlined),
            _campo(_telefonoCtrl, 'Teléfono',        Icons.phone_outlined,   teclado: TextInputType.phone),
            _campo(_direccionCtrl,'Dirección',        Icons.home_outlined),

            const SizedBox(height: 20),
            _seccion('🚴 Vehículo'),
            _selectorVehiculo(),
            if (_tipoVehiculo != 'bicicleta')
              _campo(_patenteCtrl, 'Patente / Patent', Icons.directions_car_outlined),

            const SizedBox(height: 20),
            _seccion('🏦 Cuenta bancaria (a tu nombre)'),
            _infoBox(
              '⚠️ La cuenta debe estar a tu nombre y mismo RUT. Esto es obligatorio para recibir pagos de los envíos.',
            ),
            _campo(_bancoCtrl,   'Banco', Icons.account_balance_outlined),
            _campo(_cuentaCtrl,  'Número de cuenta', Icons.numbers_outlined, teclado: TextInputType.number),

            const SizedBox(height: 20),
            _seccion('📷 Fotos (cámara obligatoria)'),
            _infoBox(
              'Por seguridad solo se acepta foto directa desde la cámara, no desde galería.',
            ),
            _fotoItem('Foto de perfil *',     _fotoPerfil,    (f) => setState(() => _fotoPerfil    = f), widget.perfilExistente?['foto_perfil']    as String?),
            _fotoItem('Foto de vehículo',     _fotoVehiculo,  (f) => setState(() => _fotoVehiculo  = f), widget.perfilExistente?['foto_vehiculo']  as String?),
            _fotoItem('CI frente *',          _fotoCiFrente,  (f) => setState(() => _fotoCiFrente  = f), widget.perfilExistente?['foto_ci_frente'] as String?),
            _fotoItem('CI reverso',           _fotoCiReverso, (f) => setState(() => _fotoCiReverso = f), widget.perfilExistente?['foto_ci_reverso'] as String?),
            _fotoItem('Selfie sosteniendo CI *', _selfie,     (f) => setState(() => _selfie        = f), widget.perfilExistente?['selfie_ci']      as String?),

            const SizedBox(height: 20),
            _seccion('📍 Sector de cobertura'),
            _infoBox('Fija un pin en el mapa y ajusta el radio de km que cubres para entregas.'),
            const SizedBox(height: 8),
            _botonMapa(),

            const SizedBox(height: 20),
            _seccion('📜 Términos y condiciones'),
            _terminosBox(),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _guardando ? 'Guardando…' : 'Registrarme como Delivery',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.carbon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _seccion(String titulo) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(titulo,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
      );

  Widget _infoBox(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withOpacity(0.4)),
        ),
        child: Text(msg,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      );

  Widget _campo(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obligatorio = false,
    TextInputType teclado = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: teclado,
        validator: obligatorio
            ? (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: AppColors.grayMid),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.divider),
          ),
        ),
      ),
    );
  }

  Widget _selectorVehiculo() => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Wrap(
          spacing: 8,
          children: [
            _chipVehiculo('bicicleta', Icons.directions_bike_rounded),
            _chipVehiculo('moto',      Icons.two_wheeler_rounded),
            _chipVehiculo('auto',      Icons.directions_car_rounded),
          ],
        ),
      );

  Widget _chipVehiculo(String v, IconData icon) {
    final sel = _tipoVehiculo == v;
    return ChoiceChip(
      selected: sel,
      onSelected: (_) => setState(() => _tipoVehiculo = v),
      avatar: Icon(icon, size: 16, color: sel ? Colors.white : AppColors.grayMid),
      label: Text(v[0].toUpperCase() + v.substring(1)),
      selectedColor: AppColors.carbon,
      labelStyle: TextStyle(
          color: sel ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600),
    );
  }

  Widget _fotoItem(String label, File? file, void Function(File) onTaken, String? urlExistente) {
    final tieneImagen = file != null || urlExistente != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: file != null
                ? Image.file(file, width: 60, height: 60, fit: BoxFit.cover)
                : urlExistente != null
                    ? Image.network('${ApiService.baseUrl}$urlExistente',
                        width: 60, height: 60, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _fotoPlaceholder(tieneImagen))
                    : _fotoPlaceholder(false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  tieneImagen ? '✅ Foto cargada' : 'Sin foto',
                  style: TextStyle(
                      fontSize: 11,
                      color: tieneImagen ? Colors.green : AppColors.grayMid),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final f = await _tomarFoto();
              if (f != null) onTaken(f);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.carbon,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Cámara',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fotoPlaceholder(bool tiene) => Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: tiene
              ? Colors.green.withOpacity(0.1)
              : AppColors.grayMid.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          tiene ? Icons.check_circle_outline : Icons.camera_alt_outlined,
          color: tiene ? Colors.green : AppColors.grayMid,
          size: 24,
        ),
      );

  Widget _botonMapa() => GestureDetector(
        onTap: _elegirUbicacion,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: _lat != null
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.divider),
          ),
          child: Row(
            children: [
              Icon(
                _lat != null ? Icons.my_location : Icons.map_outlined,
                color: _lat != null ? AppColors.primary : AppColors.grayMid,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _lat != null
                      ? '📍 Sector definido — radio: ${_radioKm.toStringAsFixed(0)} km'
                      : 'Toca para definir tu sector de entrega',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        _lat != null ? FontWeight.w700 : FontWeight.w400,
                    color: _lat != null
                        ? AppColors.primary
                        : AppColors.grayMid,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.grayMid, size: 18),
            ],
          ),
        ),
      );

  Widget _terminosBox() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Al registrarte como Delivery OkVenta aceptas:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            ...[
              '• Que tus datos personales y fotos sean verificados por OkVenta.',
              '• Que tu RUT, número de CI y selfie sean validados contra fraude.',
              '• Que tu cuenta bancaria debe estar registrada a tu nombre.',
              '• Que en caso de incumplimiento tu perfil puede ser suspendido.',
              '• Cumplir con los plazos y condiciones de cada envío.',
            ].map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(t,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                )),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _aceptoTerminos,
                  onChanged: (v) => setState(() => _aceptoTerminos = v ?? false),
                  activeColor: AppColors.carbon,
                ),
                const Expanded(
                  child: Text(
                    'Acepto los términos y condiciones',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
