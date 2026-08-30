import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

class PerfilInfoScreen extends StatefulWidget {
  const PerfilInfoScreen({super.key});

  @override
  State<PerfilInfoScreen> createState() => _PerfilInfoScreenState();
}

class _PerfilInfoScreenState extends State<PerfilInfoScreen> {
  // ── Datos locales ─────────────────────────────────────────────────────────
  String _nombre        = "";
  String _apellido      = "";
  String _rut           = "";
  String _email         = "";
  String _telefono      = "";
  String _username      = "";
  String _fotoUrl       = "";
  int?   _userId;

  // Dirección
  String _direccion     = "";
  String _comuna        = "";
  String _ciudad        = "";

  // Datos bancarios
  String _banco         = "";
  String _tipoCuenta    = "";
  String _numeroCuenta  = "";
  String _correoBanco   = "";

  bool _subiendoFoto = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nombre       = p.getString("nombre")        ?? "";
      _apellido     = p.getString("apellido")      ?? "";
      _rut          = p.getString("rut")           ?? "";
      _email        = p.getString("email")         ?? "";
      _telefono     = p.getString("telefono")      ?? "";
      _username     = p.getString("username")      ?? _generarUsername();
      _fotoUrl      = p.getString("foto_url")      ?? "";
      _userId       = p.getInt("user_id");
      _direccion    = p.getString("direccion")     ?? "";
      _comuna       = p.getString("comuna")        ?? "";
      _ciudad       = p.getString("ciudad")        ?? "";
      _banco        = p.getString("banco")         ?? "";
      _tipoCuenta   = p.getString("tipo_cuenta")   ?? "";
      _numeroCuenta = p.getString("numero_cuenta") ?? "";
      _correoBanco  = p.getString("correo_banco")  ?? "";
    });
  }

  String _generarUsername() {
    if (_nombre.isNotEmpty) {
      return (_nombre.substring(0, _nombre.length > 4 ? 4 : _nombre.length) +
              (_apellido.isNotEmpty ? _apellido.substring(0, 2) : ""))
          .toUpperCase();
    }
    return "";
  }

  Future<void> _guardarCampo(String clave, String valor) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(clave, valor);
  }

  // ── Foto de perfil ────────────────────────────────────────────────────────
  Future<void> _cambiarFoto() async {
    if (_userId == null) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Foto de perfil',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: colors.textPrimary),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: colors.textPrimary),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final foto = await _picker.pickImage(source: source, imageQuality: 80);
    if (foto == null || !mounted) return;

    setState(() => _subiendoFoto = true);
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/usuarios/$_userId/foto');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('foto', foto.path));
      final resp = await request.send();
      final body = await resp.stream.bytesToString();
      if (resp.statusCode == 200) {
        final data = jsonDecode(body);
        final newUrl = data['foto_url'] as String;
        await _guardarCampo('foto_url', newUrl);
        if (mounted) setState(() => _fotoUrl = newUrl);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto'),
              backgroundColor: colors.carbon),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  // ── Política de datos ─────────────────────────────────────────────────────
  // Nota: copy factual basada en el manejo real de datos de la app (escrow,
  // evidencia de entregas, ubicación). No reemplaza una política legal
  // redactada por el equipo — solo evita que el enlace quede en el vacío.
  void _mostrarPoliticaDatos() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text('Cómo cuidamos tus datos',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
            SizedBox(height: 16),
            _ItemPolitica(
              icon: Icons.lock_outline_rounded,
              texto: 'Tus datos bancarios son privados: nunca se muestran '
                  'al comprador ni al vendedor, solo se usan para procesar '
                  'el pago de tus ventas.',
            ),
            _ItemPolitica(
              icon: Icons.location_on_outlined,
              texto: 'Tu ubicación en tiempo real solo se comparte con el '
                  'comprador mientras una entrega está en curso (opción '
                  '"Lo entrego yo"). Fuera de ese momento no se transmite.',
            ),
            _ItemPolitica(
              icon: Icons.photo_camera_outlined,
              texto: 'Las fotos de entrega y recepción se guardan como '
                  'evidencia del proceso de compra-venta, y solo se usan '
                  'para mediar en caso de un reclamo o disputa.',
            ),
            _ItemPolitica(
              icon: Icons.account_balance_wallet_outlined,
              texto: 'Los pagos se procesan a través de Mercado Pago; '
                  'OkVenta no almacena los datos de tu tarjeta.',
            ),
          ],
        ),
      ),
    );
  }

  // ── Dirección con geocodificación ─────────────────────────────────────────
  void _editarDireccion() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DireccionSheet(
        direccionActual: _direccion,
        comunaActual: _comuna,
        ciudadActual: _ciudad,
        onGuardar: (dir, comuna, ciudad, lat, lng) async {
          setState(() {
            _direccion = dir;
            _comuna    = comuna;
            _ciudad    = ciudad;
          });
          await _guardarCampo("direccion", dir);
          await _guardarCampo("comuna",    comuna);
          await _guardarCampo("ciudad",    ciudad);
          // Actualizar ubicación en backend si hay coords
          if (_userId != null && lat != null && lng != null) {
            try {
              await http.put(
                Uri.parse('${ApiService.baseUrl}/usuarios/$_userId/ubicacion'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'lat': lat, 'lng': lng,
                  'direccion': dir, 'comuna': comuna, 'ciudad': ciudad,
                }),
              );
            } catch (_) {}
          }
        },
      ),
    );
  }

  // ── Diálogo de edición genérico ───────────────────────────────────────────
  void _editarCampo({
    required String titulo,
    required String valorActual,
    required String hint,
    TextInputType teclado = TextInputType.text,
    List<TextInputFormatter> formatters = const [],
    required Future<void> Function(String) onGuardar,
  }) {
    final ctrl = TextEditingController(text: valorActual);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
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
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(titulo,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: teclado,
              inputFormatters: formatters,
              autofocus: true,
              style: TextStyle(fontSize: 15, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: colors.grayMid, fontSize: 14),
                filled: true,
                fillColor: colors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: colors.divider, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: colors.divider, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: colors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await onGuardar(ctrl.text.trim());
                  await _cargarDatos();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Guardar",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Fila de dato ──────────────────────────────────────────────────────────
  Widget _fila({
    required IconData icon,
    required String valor,
    required String sublabel,
    bool verificado = false,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    final estaCompleto = valor.isNotEmpty;
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: colors.grayMid),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        estaCompleto ? valor : "Sin información",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: estaCompleto
                              ? colors.textPrimary
                              : colors.grayMid,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sublabel,
                        style: TextStyle(
                            fontSize: 12, color: colors.grayMid, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (verificado && estaCompleto)
                  Container(
                    width: 22, height: 22,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: colors.success, shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white),
                  ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: colors.grayMid),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
              height: 1, thickness: 0.5, indent: 54, color: colors.divider),
      ],
    );
  }

  Widget _seccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 10),
      child: Text(
        titulo,
        style: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700, color: colors.textPrimary,
        ),
      ),
    );
  }

  Widget _card(List<Widget> filas) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: filas),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final nombreCompleto =
        [_nombre, _apellido].where((s) => s.isNotEmpty).join(" ");

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.arrow_back_rounded,
                    size: 24, color: colors.textPrimary),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Información de tu perfil",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Toca cualquier campo para editarlo.",
                style: TextStyle(fontSize: 14, color: colors.grayMid, height: 1.4),
              ),
            ),

            // ── Contenido scrollable ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Avatar ─────────────────────────────────────────
                    const SizedBox(height: 24),
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _cambiarFoto,
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: colors.divider,
                              backgroundImage: _fotoUrl.isNotEmpty
                                  ? NetworkImage(
                                      '${ApiService.baseUrl}$_fotoUrl')
                                  : null,
                              child: _fotoUrl.isEmpty
                                  ? Text(
                                      _nombre.isNotEmpty
                                          ? _nombre[0].toUpperCase()
                                          : 'U',
                                      style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w700,
                                          color: colors.grayMid),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _cambiarFoto,
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: _subiendoFoto
                                    ? const Padding(
                                        padding: EdgeInsets.all(7),
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.camera_alt_rounded,
                                        size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text('Toca para cambiar foto',
                          style: TextStyle(
                              fontSize: 12, color: colors.grayMid)),
                    ),

                    // ── SECCIÓN: Información personal ──────────────
                    _seccion("Información personal"),
                    _card([
                      _fila(
                        icon: Icons.badge_outlined,
                        valor: nombreCompleto,
                        sublabel: "Nombre y apellido.",
                        verificado: true,
                        onTap: _editarNombreCompleto,
                      ),
                      _fila(
                        icon: Icons.assignment_ind_outlined,
                        valor: _rut,
                        sublabel: "RUT (12.345.678-9).",
                        verificado: true,
                        onTap: () => _editarCampo(
                          titulo: "Número de documento (RUT)",
                          valorActual: _rut,
                          hint: "12.345.678-9",
                          formatters: [_RutInputFormatter()],
                          onGuardar: (v) async {
                            final rutFormateado = _formatearRut(v);
                            setState(() => _rut = rutFormateado);
                            await _guardarCampo("rut", rutFormateado);
                          },
                        ),
                      ),
                      _fila(
                        icon: Icons.face_outlined,
                        valor: _username,
                        sublabel: "Nombre elegido.",
                        verificado: false,
                        isLast: true,
                        onTap: () => _editarCampo(
                          titulo: "Nombre elegido",
                          valorActual: _username,
                          hint: "Tu apodo o nombre público",
                          onGuardar: (v) async {
                            setState(() => _username = v);
                            await _guardarCampo("username", v);
                          },
                        ),
                      ),
                    ]),

                    // ── SECCIÓN: Datos de la cuenta ────────────────
                    _seccion("Datos de la cuenta"),
                    _card([
                      _fila(
                        icon: Icons.mail_outline_rounded,
                        valor: _email,
                        sublabel: "E-mail donde recibes comunicaciones.",
                        verificado: true,
                        onTap: () => _editarCampo(
                          titulo: "Correo electrónico",
                          valorActual: _email,
                          hint: "tucorreo@ejemplo.com",
                          teclado: TextInputType.emailAddress,
                          onGuardar: (v) async {
                            setState(() => _email = v);
                            await _guardarCampo("email", v);
                          },
                        ),
                      ),
                      _fila(
                        icon: Icons.phone_outlined,
                        valor: _telefono.isNotEmpty
                            ? (_telefono.startsWith("+")
                                ? _telefono
                                : "+56$_telefono")
                            : "",
                        sublabel: "Número de teléfono.",
                        verificado: true,
                        onTap: () => _editarCampo(
                          titulo: "Número de teléfono",
                          valorActual: _telefono,
                          hint: "+56912345678",
                          teclado: TextInputType.phone,
                          onGuardar: (v) async {
                            setState(() => _telefono = v);
                            await _guardarCampo("telefono", v);
                          },
                        ),
                      ),
                      _fila(
                        icon: Icons.person_outline_rounded,
                        valor: _username.isNotEmpty ? _username.toUpperCase() : "",
                        sublabel: "Nombre de usuario.",
                        verificado: false,
                        isLast: true,
                        onTap: () => _editarCampo(
                          titulo: "Nombre de usuario",
                          valorActual: _username,
                          hint: "TUUSUARIO",
                          onGuardar: (v) async {
                            setState(() => _username = v.toUpperCase());
                            await _guardarCampo("username", v.toUpperCase());
                          },
                        ),
                      ),
                    ]),

                    // ── SECCIÓN: Dirección ────────────────────────
                    _seccion("Dirección"),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: colors.primary.withOpacity(0.15),
                            width: 0.5),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 15, color: colors.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Define la ubicación de tus publicaciones en el mapa. Se valida automáticamente con mapas reales.",
                              style: TextStyle(
                                  fontSize: 12, color: colors.primary, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _card([
                      _fila(
                        icon: Icons.home_outlined,
                        valor: _direccion,
                        sublabel: "Calle y número — toca para buscar en el mapa.",
                        verificado: _direccion.isNotEmpty,
                        onTap: _editarDireccion,
                      ),
                      _fila(
                        icon: Icons.location_city_outlined,
                        valor: _comuna,
                        sublabel: "Comuna.",
                        verificado: _comuna.isNotEmpty,
                        onTap: _editarDireccion,
                      ),
                      _fila(
                        icon: Icons.map_outlined,
                        valor: _ciudad,
                        sublabel: "Ciudad.",
                        verificado: _ciudad.isNotEmpty,
                        isLast: true,
                        onTap: _editarDireccion,
                      ),
                    ]),

                    // ── SECCIÓN: Datos bancarios ───────────────────
                    _seccion("Datos bancarios"),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.carbon.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.divider, width: 0.5),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 15, color: colors.grayMid),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Tus datos bancarios son privados y solo se usan para recibir pagos por tus ventas.",
                              style: TextStyle(
                                  fontSize: 12, color: colors.grayMid, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _card([
                      _fila(
                        icon: Icons.assignment_ind_outlined,
                        valor: _rut,
                        sublabel: "RUT del titular de la cuenta.",
                        verificado: true,
                        onTap: () => _editarCampo(
                          titulo: "Número de documento (RUT)",
                          valorActual: _rut,
                          hint: "12.345.678-9",
                          formatters: [_RutInputFormatter()],
                          onGuardar: (v) async {
                            final rutFormateado = _formatearRut(v);
                            setState(() => _rut = rutFormateado);
                            await _guardarCampo("rut", rutFormateado);
                          },
                        ),
                      ),
                      _fila(
                        icon: Icons.account_balance_outlined,
                        valor: _banco,
                        sublabel: "Banco donde recibes tus pagos.",
                        verificado: true,
                        onTap: _abrirSelectorBanco,
                      ),
                      _fila(
                        icon: Icons.credit_card_outlined,
                        valor: _tipoCuenta,
                        sublabel: "Tipo de cuenta bancaria.",
                        verificado: true,
                        onTap: _abrirSelectorTipoCuenta,
                      ),
                      _fila(
                        icon: Icons.numbers_outlined,
                        valor: _numeroCuenta,
                        sublabel: "Número de cuenta.",
                        verificado: true,
                        onTap: () => _editarCampo(
                          titulo: "Número de cuenta",
                          valorActual: _numeroCuenta,
                          hint: "00000000000",
                          teclado: TextInputType.number,
                          onGuardar: (v) async {
                            setState(() => _numeroCuenta = v);
                            await _guardarCampo("numero_cuenta", v);
                          },
                        ),
                      ),
                      _fila(
                        icon: Icons.email_outlined,
                        valor: _correoBanco,
                        sublabel: "Correo asociado a la cuenta.",
                        verificado: true,
                        isLast: true,
                        onTap: () => _editarCampo(
                          titulo: "Correo del banco",
                          valorActual: _correoBanco,
                          hint: "tucorreo@banco.cl",
                          teclado: TextInputType.emailAddress,
                          onGuardar: (v) async {
                            setState(() => _correoBanco = v);
                            await _guardarCampo("correo_banco", v);
                          },
                        ),
                      ),
                    ]),

                    const SizedBox(height: 28),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 16, color: colors.grayMid),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colors.grayMid,
                                  height: 1.5),
                              children: [
                                const TextSpan(
                                  text:
                                      "Tu información personal está siempre protegida. Si tienes dudas, puedes consultar ",
                                ),
                                TextSpan(
                                  text: "cómo cuidamos tus datos.",
                                  style: TextStyle(
                                    color: colors.primary,
                                    decoration: TextDecoration.underline,
                                    decorationColor: colors.primary,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = _mostrarPoliticaDatos,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  // ── Editar nombre y apellido ──────────────────────────────────────────────
  void _editarNombreCompleto() {
    final nombreCtrl   = TextEditingController(text: _nombre);
    final apellidoCtrl = TextEditingController(text: _apellido);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
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
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text("Nombre y apellido",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
            const SizedBox(height: 14),
            _campoEdicion(nombreCtrl, "Nombre", autofocus: true),
            const SizedBox(height: 10),
            _campoEdicion(apellidoCtrl, "Apellido(s)"),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final n = nombreCtrl.text.trim();
                  final a = apellidoCtrl.text.trim();
                  Navigator.pop(context);
                  setState(() { _nombre = n; _apellido = a; });
                  await _guardarCampo("nombre", n);
                  await _guardarCampo("apellido", a);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Guardar",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Selector banco ────────────────────────────────────────────────────────
  void _abrirSelectorBanco() {
    const bancos = [
      "Banco de Chile", "BancoEstado", "Santander", "BCI", "Scotiabank",
      "Itaú", "BICE", "Banco Security", "Falabella", "Ripley",
      "HSBC", "Coopeuch", "Tenpo", "Mercado Pago",
    ];
    _abrirSelectorOpciones(
      titulo: "Selecciona tu banco",
      opciones: bancos,
      valorActual: _banco,
      onSeleccionar: (v) async {
        setState(() => _banco = v);
        await _guardarCampo("banco", v);
      },
    );
  }

  void _abrirSelectorTipoCuenta() {
    const tipos = [
      "Cuenta Corriente",
      "Cuenta Vista / RUT",
      "Cuenta de Ahorro",
      "Cuenta Digital",
    ];
    _abrirSelectorOpciones(
      titulo: "Tipo de cuenta",
      opciones: tipos,
      valorActual: _tipoCuenta,
      onSeleccionar: (v) async {
        setState(() => _tipoCuenta = v);
        await _guardarCampo("tipo_cuenta", v);
      },
    );
  }

  void _abrirSelectorOpciones({
    required String titulo,
    required List<String> opciones,
    required String valorActual,
    required Future<void> Function(String) onSeleccionar,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(titulo,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
            ),
            const Divider(height: 1, thickness: 0.5),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: opciones.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, thickness: 0.5, indent: 20, endIndent: 20),
                itemBuilder: (_, i) {
                  final op = opciones[i];
                  final sel = op == valorActual;
                  return ListTile(
                    title: Text(op,
                        style: TextStyle(
                            fontSize: 15,
                            color: sel ? colors.primary : colors.textPrimary,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                    trailing: sel
                        ? Icon(Icons.check_circle_rounded,
                            color: colors.primary, size: 20)
                        : null,
                    onTap: () async {
                      Navigator.pop(context);
                      await onSeleccionar(op);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _campoEdicion(TextEditingController ctrl, String hint,
      {bool autofocus = false}) {
    return TextField(
      controller: ctrl,
      autofocus: autofocus,
      style: TextStyle(fontSize: 15, color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.grayMid, fontSize: 14),
        filled: true,
        fillColor: colors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.divider, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.divider, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ── RUT formatter ─────────────────────────────────────────────────────────────

String _formatearRut(String rut) {
  final limpio = rut.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();
  if (limpio.isEmpty) return '';
  if (limpio.length == 1) return limpio;
  final cuerpo = limpio.substring(0, limpio.length - 1);
  final dv = limpio[limpio.length - 1];
  final buf = StringBuffer();
  for (int i = 0; i < cuerpo.length; i++) {
    if (i > 0 && (cuerpo.length - i) % 3 == 0) buf.write('.');
    buf.write(cuerpo[i]);
  }
  return '${buf.toString()}-$dv';
}

class _RutInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final limpio = newValue.text.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();
    if (limpio.isEmpty) return newValue.copyWith(text: '');
    if (limpio.length == 1) {
      return newValue.copyWith(
          text: limpio, selection: TextSelection.collapsed(offset: 1));
    }
    final cuerpo = limpio.substring(0, limpio.length - 1);
    final dv = limpio[limpio.length - 1];
    final buf = StringBuffer();
    for (int i = 0; i < cuerpo.length; i++) {
      if (i > 0 && (cuerpo.length - i) % 3 == 0) buf.write('.');
      buf.write(cuerpo[i]);
    }
    final resultado = '${buf.toString()}-$dv';
    return TextEditingValue(
      text: resultado,
      selection: TextSelection.collapsed(offset: resultado.length),
    );
  }
}

// ── Dirección con geocodificación Nominatim ───────────────────────────────────

class _DireccionSheet extends StatefulWidget {
  final String direccionActual;
  final String comunaActual;
  final String ciudadActual;
  final Future<void> Function(
      String dir, String comuna, String ciudad, double? lat, double? lng) onGuardar;

  const _DireccionSheet({
    required this.direccionActual,
    required this.comunaActual,
    required this.ciudadActual,
    required this.onGuardar,
  });

  @override
  State<_DireccionSheet> createState() => _DireccionSheetState();
}

class _DireccionSheetState extends State<_DireccionSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _sugerencias = [];
  bool _buscando = false;
  Timer? _debounce;
  Map<String, dynamic>? _seleccionada;

  // Fallback manual: si el buscador no encuentra la dirección (o no hay
  // internet), permite guardarla como texto libre sin geocodificar.
  bool _modoManual = false;
  final _calleCtrl = TextEditingController();
  final _comunaCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-populate with current address
    final partes = [
      widget.direccionActual,
      widget.comunaActual,
      widget.ciudadActual,
    ].where((s) => s.isNotEmpty).join(', ');
    _ctrl.text = partes;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _calleCtrl.dispose();
    _comunaCtrl.dispose();
    _ciudadCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onCambio(String texto) {
    _debounce?.cancel();
    if (texto.trim().length < 5) {
      setState(() => _sugerencias = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _buscar(texto));
  }

  Future<void> _buscar(String query) async {
    setState(() => _buscando = true);
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
      ).replace(queryParameters: {
        'q': '$query, Chile',
        'format': 'json',
        'limit': '6',
        'addressdetails': '1',
        'countrycodes': 'cl',
      });
      final resp = await http.get(uri, headers: {
        'User-Agent': 'OkVenta/1.0 (okventa.app)',
        'Accept-Language': 'es',
      }).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        if (mounted) {
          setState(() => _sugerencias =
              data.map((e) => Map<String, dynamic>.from(e)).toList());
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _buscando = false);
  }

  InputDecoration _inputManual(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.grayMid, fontSize: 14),
      filled: true,
      fillColor: colors.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.divider, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.divider, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
    );
  }

  String _extraerCampo(Map<String, dynamic> addr, List<String> claves) {
    for (final c in claves) {
      final v = addr[c];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, sc) => Container(
          color: colors.surface,
          child: Column(
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_modoManual ? 'Ingresar dirección' : 'Buscar dirección',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary)),
                        TextButton(
                          onPressed: () => setState(() {
                            _modoManual = !_modoManual;
                            _seleccionada = null;
                          }),
                          child: Text(
                            _modoManual ? 'Buscar en el mapa' : 'Ingresar manualmente',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: colors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_modoManual) ...[
                      TextField(
                        controller: _calleCtrl,
                        style: const TextStyle(fontSize: 14),
                        onChanged: (_) => setState(() {}),
                        decoration: _inputManual('Calle y número'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _comunaCtrl,
                        style: const TextStyle(fontSize: 14),
                        decoration: _inputManual('Comuna'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _ciudadCtrl,
                        style: const TextStyle(fontSize: 14),
                        decoration: _inputManual('Ciudad'),
                      ),
                    ] else
                    TextField(
                      controller: _ctrl,
                      autofocus: true,
                      onChanged: _onCambio,
                      style: TextStyle(
                          fontSize: 15, color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Ej: Av. Providencia 1234, Providencia',
                        hintStyle: TextStyle(
                            color: colors.grayMid, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: colors.grayMid, size: 20),
                        suffixIcon: _buscando
                            ? Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.primary),
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: colors.background,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: colors.divider, width: 0.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: colors.divider, width: 0.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: colors.primary, width: 1.5),
                        ),
                      ),
                    ),
                    if (_seleccionada != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 14, color: Colors.green),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Dirección verificada',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5),
              Expanded(
                child: _modoManual
                    ? const SizedBox.shrink()
                    : _sugerencias.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_searching_rounded,
                                size: 40,
                                color: colors.grayMid.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'Escribe la dirección para ver sugerencias',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: colors.grayMid),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: sc,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _sugerencias.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, thickness: 0.5, indent: 54),
                        itemBuilder: (_, i) {
                          final s = _sugerencias[i];
                          final addr = Map<String, dynamic>.from(
                              s['address'] as Map? ?? {});
                          final displayName = s['display_name'] as String? ?? '';
                          final partes = displayName.split(',');
                          final linea1 = partes.isNotEmpty
                              ? partes.take(2).join(',').trim()
                              : displayName;
                          final linea2 = partes.length > 2
                              ? partes.skip(2).take(2).join(',').trim()
                              : '';

                          return ListTile(
                            leading: Icon(Icons.location_on_outlined,
                                color: colors.primary, size: 22),
                            title: Text(linea1,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textPrimary)),
                            subtitle: linea2.isNotEmpty
                                ? Text(linea2,
                                    style: TextStyle(
                                        fontSize: 12, color: colors.grayMid))
                                : null,
                            onTap: () {
                              final lat = double.tryParse(s['lat'] ?? '');
                              final lng = double.tryParse(s['lon'] ?? '');
                              final road = _extraerCampo(addr, [
                                'road', 'pedestrian', 'footway', 'street'
                              ]);
                              final numero = _extraerCampo(addr, ['house_number']);
                              final dir = numero.isNotEmpty
                                  ? '$road $numero'.trim()
                                  : road.isNotEmpty ? road : linea1;
                              final comuna = _extraerCampo(addr, [
                                'suburb', 'city_district', 'town', 'village', 'municipality'
                              ]);
                              final ciudad = _extraerCampo(addr, [
                                'city', 'town', 'county', 'state'
                              ]);
                              setState(() {
                                _seleccionada = {
                                  'dir': dir, 'comuna': comuna,
                                  'ciudad': ciudad, 'lat': lat, 'lng': lng,
                                };
                                _sugerencias = [];
                                _ctrl.text = displayName;
                              });
                            },
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _modoManual
                        ? (_calleCtrl.text.trim().isEmpty
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await widget.onGuardar(
                                  _calleCtrl.text.trim(),
                                  _comunaCtrl.text.trim(),
                                  _ciudadCtrl.text.trim(),
                                  null,
                                  null,
                                );
                              })
                        : (_seleccionada == null
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await widget.onGuardar(
                                  _seleccionada!['dir'] as String,
                                  _seleccionada!['comuna'] as String,
                                  _seleccionada!['ciudad'] as String,
                                  _seleccionada!['lat'] as double?,
                                  _seleccionada!['lng'] as double?,
                                );
                              }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: colors.divider,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirmar dirección',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemPolitica extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _ItemPolitica({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto,
                style: TextStyle(
                    fontSize: 13.5,
                    color: colors.textPrimary,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}
