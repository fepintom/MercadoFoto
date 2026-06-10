import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'mapa_ubicacion_picker_screen.dart';

class DeliveryRegistroScreen extends StatefulWidget {
  final Map<String, dynamic>? perfilExistente;
  const DeliveryRegistroScreen({super.key, this.perfilExistente});

  @override
  State<DeliveryRegistroScreen> createState() => _DeliveryRegistroScreenState();
}

class _DeliveryRegistroScreenState extends State<DeliveryRegistroScreen> {
  final _picker = ImagePicker();

  // ── Campos ────────────────────────────────────────────────────────────────
  String _nombre       = '';
  String _edad         = '';
  String _email        = '';
  String _rut          = '';
  String _telefono     = '';
  String _direccion    = '';
  String _tipoVehiculo = 'bicicleta';
  String _patente      = '';
  String _banco        = '';
  String _cuenta       = '';

  // ── Fotos ─────────────────────────────────────────────────────────────────
  File? _fotoPerfil;
  File? _fotoVehiculo;
  File? _fotoCiFrente;
  File? _fotoCiReverso;
  File? _selfie;

  // ── Ubicación ─────────────────────────────────────────────────────────────
  double? _lat;
  double? _lng;
  double  _radioKm = 5.0;

  // ── Estado ────────────────────────────────────────────────────────────────
  bool _aceptoTerminos = false;
  bool _guardando      = false;
  int? _userId;
  int? _deliveryId;

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
    _deliveryId  = p['id'] as int?;
    _nombre      = p['nombre']       as String? ?? '';
    _edad        = '${p['edad']      ?? ''}';
    _email       = p['email']        as String? ?? '';
    _rut         = p['rut']          as String? ?? '';
    _telefono    = p['telefono']     as String? ?? '';
    _direccion   = p['direccion']    as String? ?? '';
    _tipoVehiculo= p['tipo_vehiculo']as String? ?? 'bicicleta';
    _patente     = p['patente']      as String? ?? '';
    _banco       = p['banco']        as String? ?? '';
    _cuenta      = p['cuenta_banco'] as String? ?? '';
    _lat         = (p['lat']         as num?)?.toDouble();
    _lng         = (p['lng']         as num?)?.toDouble();
    _radioKm     = (p['radio_km']    as num?)?.toDouble() ?? 5.0;
    _aceptoTerminos = (p['acepto_terminos'] as int? ?? 0) == 1;
  }

  // ── Tomar foto (SOLO cámara) ──────────────────────────────────────────────
  Future<File?> _tomarFoto() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1200,
    );
    return xfile == null ? null : File(xfile.path);
  }

  // ── Editar campo de texto (bottom sheet) ─────────────────────────────────
  void _editarCampo({
    required String titulo,
    required String valorActual,
    required String hint,
    TextInputType teclado = TextInputType.text,
    List<TextInputFormatter> formatters = const [],
    required void Function(String) onGuardar,
  }) {
    final ctrl = TextEditingController(text: valorActual);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(titulo,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: teclado,
              inputFormatters: formatters,
              autofocus: true,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.grayMid, fontSize: 14),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
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
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onGuardar(ctrl.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Guardar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Elegir sector en mapa ────────────────────────────────────────────────
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
      setState(() { _lat = result.lat; _lng = result.lng; _radioKm = result.radioKm; });
    }
  }

  // ── Guardar ───────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (_nombre.isEmpty) {
      _snack('Ingresa tu nombre completo', error: true); return;
    }
    if (!_aceptoTerminos) {
      _snack('Debes aceptar los términos y condiciones', error: true); return;
    }
    if (_userId == null) {
      _snack('Debes iniciar sesión', error: true); return;
    }
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
      req.fields['nombre']        = _nombre;
      req.fields['edad']          = _edad;
      req.fields['email']         = _email;
      req.fields['rut']           = _rut;
      req.fields['telefono']      = _telefono;
      req.fields['direccion']     = _direccion;
      req.fields['tipo_vehiculo'] = _tipoVehiculo;
      req.fields['patente']       = _patente;
      req.fields['banco']         = _banco;
      req.fields['cuenta_banco']  = _cuenta;
      req.fields['radio_km']      = '$_radioKm';
      if (_lat != null) req.fields['lat'] = '$_lat';
      if (_lng != null) req.fields['lng'] = '$_lng';

      Future<void> adj(File? f, String field) async {
        if (f == null) return;
        req.files.add(await http.MultipartFile.fromPath(field, f.path));
      }
      await adj(_fotoPerfil,    'foto_perfil');
      await adj(_fotoVehiculo,  'foto_vehiculo');
      await adj(_fotoCiFrente,  'foto_ci_frente');
      await adj(_fotoCiReverso, 'foto_ci_reverso');
      await adj(_selfie,        'selfie_ci');

      final streamed = await req.send();
      if (streamed.statusCode == 200) {
        _snack('✅ Perfil de delivery guardado');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context, true);
      } else {
        final body = await streamed.stream.bytesToString();
        _snack('Error: $body', error: true);
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 24, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Delivery OkVenta',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Completa tu perfil para aparecer disponible como repartidor en OkVenta.',
                style: TextStyle(
                    fontSize: 14, color: AppColors.grayMid, height: 1.4),
              ),
            ),

            // ── Contenido scrollable ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Datos personales ──────────────────────────────
                    _seccion('Datos personales'),
                    _card([
                      _fila(icon: Icons.person_outline,
                          valor: _nombre, sublabel: 'Nombre completo',
                          onTap: () => _editarCampo(
                              titulo: 'Nombre completo', valorActual: _nombre,
                              hint: 'Ej: Juan Pérez',
                              onGuardar: (v) => setState(() => _nombre = v))),
                      _fila(icon: Icons.cake_outlined,
                          valor: _edad, sublabel: 'Edad',
                          onTap: () => _editarCampo(
                              titulo: 'Edad', valorActual: _edad,
                              hint: 'Ej: 28',
                              teclado: TextInputType.number,
                              onGuardar: (v) => setState(() => _edad = v))),
                      _fila(icon: Icons.email_outlined,
                          valor: _email, sublabel: 'Correo electrónico',
                          onTap: () => _editarCampo(
                              titulo: 'Correo electrónico', valorActual: _email,
                              hint: 'correo@ejemplo.com',
                              teclado: TextInputType.emailAddress,
                              onGuardar: (v) => setState(() => _email = v))),
                      _fila(icon: Icons.badge_outlined,
                          valor: _rut, sublabel: 'RUT',
                          onTap: () => _editarCampo(
                              titulo: 'RUT', valorActual: _rut,
                              hint: 'Ej: 12.345.678-9',
                              onGuardar: (v) => setState(() => _rut = v))),
                      _fila(icon: Icons.phone_outlined,
                          valor: _telefono, sublabel: 'Teléfono',
                          onTap: () => _editarCampo(
                              titulo: 'Teléfono', valorActual: _telefono,
                              hint: '+56 9 1234 5678',
                              teclado: TextInputType.phone,
                              onGuardar: (v) => setState(() => _telefono = v))),
                      _fila(icon: Icons.home_outlined,
                          valor: _direccion, sublabel: 'Dirección',
                          isLast: true,
                          onTap: () => _editarCampo(
                              titulo: 'Dirección', valorActual: _direccion,
                              hint: 'Av. Ejemplo 1234, Santiago',
                              onGuardar: (v) => setState(() => _direccion = v))),
                    ]),

                    // ── Vehículo ──────────────────────────────────────
                    _seccion('Vehículo'),
                    _card([
                      _filaVehiculo(),
                      if (_tipoVehiculo != 'bicicleta')
                        _fila(icon: Icons.directions_car_outlined,
                            valor: _patente, sublabel: 'Patente / Patent',
                            isLast: true,
                            onTap: () => _editarCampo(
                                titulo: 'Patente', valorActual: _patente,
                                hint: 'Ej: ABCD12',
                                onGuardar: (v) => setState(() => _patente = v)))
                      else
                        const SizedBox.shrink(),
                    ]),

                    // ── Cuenta bancaria ───────────────────────────────
                    _seccion('Cuenta bancaria (a tu nombre)'),
                    _infoBox(
                        '⚠️ La cuenta debe estar registrada con tu mismo RUT para recibir pagos.'),
                    _card([
                      _fila(icon: Icons.account_balance_outlined,
                          valor: _banco, sublabel: 'Banco',
                          onTap: () => _editarCampo(
                              titulo: 'Banco', valorActual: _banco,
                              hint: 'Ej: Banco de Chile',
                              onGuardar: (v) => setState(() => _banco = v))),
                      _fila(icon: Icons.numbers_outlined,
                          valor: _cuenta, sublabel: 'Número de cuenta',
                          isLast: true,
                          onTap: () => _editarCampo(
                              titulo: 'Número de cuenta', valorActual: _cuenta,
                              hint: 'Ej: 00123456789',
                              teclado: TextInputType.number,
                              onGuardar: (v) => setState(() => _cuenta = v))),
                    ]),

                    // ── Fotos (solo cámara) ───────────────────────────
                    _seccion('Fotos de verificación'),
                    _infoBox(
                        '📷 Solo se acepta foto directa desde la cámara, no desde galería.'),
                    _card([
                      _filaFoto('Foto de perfil *',    _fotoPerfil,    widget.perfilExistente?['foto_perfil']    as String?, (f) => setState(() => _fotoPerfil    = f)),
                      _filaFoto('Foto de vehículo',    _fotoVehiculo,  widget.perfilExistente?['foto_vehiculo']  as String?, (f) => setState(() => _fotoVehiculo  = f)),
                      _filaFoto('CI frente *',         _fotoCiFrente,  widget.perfilExistente?['foto_ci_frente'] as String?, (f) => setState(() => _fotoCiFrente  = f)),
                      _filaFoto('CI reverso',          _fotoCiReverso, widget.perfilExistente?['foto_ci_reverso']as String?, (f) => setState(() => _fotoCiReverso = f)),
                      _filaFoto('Selfie con CI *',     _selfie,        widget.perfilExistente?['selfie_ci']      as String?, (f) => setState(() => _selfie        = f), isLast: true),
                    ]),

                    // ── Sector de cobertura ───────────────────────────
                    _seccion('Sector de cobertura'),
                    _card([
                      _filaUbicacion(),
                    ]),

                    // ── Términos ──────────────────────────────────────
                    _seccion('Términos y condiciones'),
                    _card([
                      _filaTerminos(),
                    ]),

                    const SizedBox(height: 28),

                    // ── Botón guardar ─────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _guardando
                              ? 'Guardando…'
                              : _deliveryId == null
                                  ? 'Registrarme como Delivery'
                                  : 'Guardar cambios',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.carbon,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
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

  // ── Helpers de diseño (estilo perfil_info) ────────────────────────────────

  Widget _seccion(String titulo) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 28, 0, 10),
        child: Text(titulo,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      );

  Widget _infoBox(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.withOpacity(0.4)),
        ),
        child: Text(msg,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Column(children: children),
      );

  Widget _fila({
    required IconData icon,
    required String valor,
    required String sublabel,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    final completo = valor.isNotEmpty;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(14))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AppColors.grayMid),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        completo ? valor : 'Sin información',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: completo
                              ? AppColors.textPrimary
                              : AppColors.grayMid,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(sublabel,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.grayMid,
                              height: 1.3)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.grayMid),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(
              height: 1, thickness: 0.5, indent: 54, color: AppColors.divider),
      ],
    );
  }

  Widget _filaVehiculo() {
    const vehiculos = ['bicicleta', 'moto', 'auto'];
    final iconos = {
      'bicicleta': Icons.directions_bike_rounded,
      'moto':      Icons.two_wheeler_rounded,
      'auto':      Icons.directions_car_rounded,
    };
    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2))),
              const Text('Tipo de vehículo',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              ...vehiculos.map((v) => ListTile(
                    leading: Icon(iconos[v], color: AppColors.carbon),
                    title: Text(v[0].toUpperCase() + v.substring(1),
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: _tipoVehiculo == v
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() => _tipoVehiculo = v);
                      Navigator.pop(context);
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(iconos[_tipoVehiculo] ?? Icons.directions_bike_rounded,
                size: 22, color: AppColors.grayMid),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tipoVehiculo[0].toUpperCase() + _tipoVehiculo.substring(1),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary),
                  ),
                  const Text('Tipo de vehículo',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.grayMid, height: 1.3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.grayMid),
          ],
        ),
      ),
    );
  }

  Widget _filaFoto(
    String label, File? file, String? urlExistente,
    void Function(File) onTaken, {bool isLast = false}) {
    final tiene = file != null || urlExistente != null;
    return Column(
      children: [
        InkWell(
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(14))
              : BorderRadius.zero,
          onTap: () async {
            final f = await _tomarFoto();
            if (f != null) onTaken(f);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: file != null
                      ? Image.file(file, width: 44, height: 44, fit: BoxFit.cover)
                      : urlExistente != null
                          ? Image.network(
                              '${ApiService.baseUrl}$urlExistente',
                              width: 44, height: 44, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _fotoPlaceholder(false))
                          : _fotoPlaceholder(false),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                      Text(
                        tiene ? '✅ Foto cargada' : 'Toca para tomar foto',
                        style: TextStyle(
                            fontSize: 12,
                            color: tiene ? Colors.green : AppColors.grayMid),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.carbon,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.camera_alt, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Cámara',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(
              height: 1, thickness: 0.5, indent: 76, color: AppColors.divider),
      ],
    );
  }

  Widget _fotoPlaceholder(bool tiene) => Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: AppColors.grayMid.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.camera_alt_outlined,
            color: AppColors.grayMid, size: 20),
      );

  Widget _filaUbicacion() => InkWell(
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(14)),
        onTap: _elegirUbicacion,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(
                _lat != null ? Icons.my_location : Icons.map_outlined,
                size: 22,
                color:
                    _lat != null ? AppColors.primary : AppColors.grayMid,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lat != null
                          ? 'Sector definido — radio ${_radioKm.toStringAsFixed(0)} km'
                          : 'Sin sector definido',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _lat != null
                            ? AppColors.textPrimary
                            : AppColors.grayMid,
                      ),
                    ),
                    const Text('Radio de cobertura en el mapa',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.grayMid,
                            height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.grayMid),
            ],
          ),
        ),
      );

  Widget _filaTerminos() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Checkbox(
              value: _aceptoTerminos,
              onChanged: (v) =>
                  setState(() => _aceptoTerminos = v ?? false),
              activeColor: AppColors.carbon,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acepto los términos y condiciones',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary),
                  ),
                  Text(
                    'Mis datos serán verificados. La cuenta bancaria debe estar a mi nombre con el mismo RUT.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.grayMid,
                        height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
