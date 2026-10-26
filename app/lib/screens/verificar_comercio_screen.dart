import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/apple_mapkit.dart';
import '../services/comercio_service.dart';
import '../services/session_service.dart';
import '../services/theme_service.dart';
import '../services/ubicacion_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mapa_mini.dart';
import 'mapa_ubicacion_picker_screen.dart';
import 'perfil_comercio_screen.dart';

/// "Verificar mi comercio": formulario para que una pyme o empresa (persona
/// con giro comercial) obtenga la insignia de Comercio verificado.
///
///   1. Datos del comercio: RUT, razón social y nombre comercial.
///   2. Responsable: documento de identidad + certificado de vigencia de
///      poderes (foto o PDF). Privados: solo los ve el equipo de OkVenta.
///   3. Ubicación: dirección + punto en el mapa (o "usar mi ubicación").
///   4. Fotos del local: fachada, letrero e interior, tomadas en la app.
///
/// Si ya hay una solicitud, muestra su estado (en revisión, verificado o
/// rechazado con el motivo y la opción de corregir y reenviar).
class VerificarComercioScreen extends StatefulWidget {
  const VerificarComercioScreen({super.key});

  @override
  State<VerificarComercioScreen> createState() =>
      _VerificarComercioScreenState();
}

class _VerificarComercioScreenState extends State<VerificarComercioScreen> {
  final _rutCtrl = TextEditingController();
  final _razonCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _picker = ImagePicker();

  int? _userId;
  bool _cargando = true;
  bool _enviando = false;
  bool _buscandoGps = false;
  bool _editar = false; // tras un rechazo, volver a llenar
  Map<String, dynamic>? _estado;

  double? _lat, _lng;
  File? _docIdentidad, _docPoderes;
  File? _fachada, _letrero, _interior;

  static const _rojo = Color(0xFFD62B2B);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_rutCtrl, _razonCtrl, _nombreCtrl, _direccionCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    final uid = await SessionService.obtenerUser();
    Map<String, dynamic>? e;
    if (uid != null) e = await ComercioService.estado(uid);
    if (!mounted) return;
    setState(() {
      _userId = uid;
      _estado = e;
      _cargando = false;
      final d = e?['datos'];
      if (d is Map) {
        _rutCtrl.text = (d['rut'] ?? '').toString();
        _razonCtrl.text = (d['razon_social'] ?? '').toString();
        _nombreCtrl.text = (d['nombre_comercial'] ?? '').toString();
        _direccionCtrl.text = (d['direccion'] ?? '').toString();
        _lat = (d['lat'] as num?)?.toDouble();
        _lng = (d['lng'] as num?)?.toDouble();
      }
    });
  }

  void _aviso(String t, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(t),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? _rojo : colors.carbon,
      ));
  }

  // ── Documentos y fotos ───────────────────────────────────────────────────

  Future<File?> _elegirDocumento(String titulo) async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text(titulo,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary)),
          ListTile(
            leading: Icon(Icons.photo_camera_outlined, color: colors.textPrimary),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(ctx, 'camara'),
          ),
          ListTile(
            leading: Icon(Icons.photo_library_outlined, color: colors.textPrimary),
            title: const Text('Elegir foto'),
            onTap: () => Navigator.pop(ctx, 'galeria'),
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined, color: colors.textPrimary),
            title: const Text('Subir archivo (PDF)'),
            onTap: () => Navigator.pop(ctx, 'archivo'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (opcion == null) return null;
    if (opcion == 'archivo') {
      final r = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic']);
      final p = r?.files.single.path;
      return p == null ? null : File(p);
    }
    final x = await _picker.pickImage(
        source: opcion == 'camara' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2000,
        maxHeight: 2000);
    return x == null ? null : File(x.path);
  }

  /// Las fotos del local se toman en el momento (no de la galería).
  Future<File?> _tomarFoto() async {
    final x = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1800,
        maxHeight: 1800);
    return x == null ? null : File(x.path);
  }

  // ── Ubicación ─────────────────────────────────────────────────────────────

  Future<void> _usarMiUbicacion() async {
    setState(() => _buscandoGps = true);
    final yo = await UbicacionService.obtener(usarCache: false);
    if (!mounted) return;
    setState(() => _buscandoGps = false);
    if (yo == null) {
      _aviso('No pudimos obtener tu ubicación. Revisa los permisos.',
          error: true);
      return;
    }
    setState(() {
      _lat = yo.lat;
      _lng = yo.lng;
    });
    final dir = await AppleMapKit.direccion(yo.lat, yo.lng);
    if (dir != null && mounted && _direccionCtrl.text.trim().isEmpty) {
      setState(() => _direccionCtrl.text = dir);
    }
  }

  Future<void> _elegirEnMapa() async {
    final r = await Navigator.push<UbicacionElegida>(
      context,
      MaterialPageRoute(
        builder: (_) => MapaUbicacionPickerScreen(
          latInicial: _lat,
          lngInicial: _lng,
          radioKmInicial: 1,
        ),
      ),
    );
    if (r == null || !mounted) return;
    setState(() {
      _lat = r.lat;
      _lng = r.lng;
    });
    final dir = await AppleMapKit.direccion(r.lat, r.lng);
    if (dir != null && mounted && _direccionCtrl.text.trim().isEmpty) {
      setState(() => _direccionCtrl.text = dir);
    }
  }

  // ── Enviar ────────────────────────────────────────────────────────────────

  Future<void> _enviar() async {
    final uid = _userId;
    if (uid == null) {
      _aviso('Inicia sesión para verificar tu comercio', error: true);
      return;
    }
    final faltan = <String>[
      if (!ComercioService.rutValido(_rutCtrl.text)) 'RUT válido de la empresa',
      if (_razonCtrl.text.trim().length < 3) 'razón social',
      if (_nombreCtrl.text.trim().length < 2) 'nombre comercial',
      if (_docIdentidad == null) 'documento de identidad',
      if (_docPoderes == null) 'certificado de vigencia de poderes',
      if (_direccionCtrl.text.trim().length < 5) 'dirección',
      if (_lat == null || _lng == null) 'ubicación en el mapa',
      if (_fachada == null) 'foto de la fachada',
      if (_letrero == null) 'foto del letrero',
      if (_interior == null) 'foto del interior',
    ];
    if (faltan.isNotEmpty) {
      _aviso('Falta: ${faltan.join(', ')}', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _enviando = true);
    try {
      final dir = _direccionCtrl.text.trim();
      final partes = dir.split(',');
      await ComercioService.enviar(
        userId: uid,
        rut: _rutCtrl.text,
        razonSocial: _razonCtrl.text.trim(),
        nombreComercial: _nombreCtrl.text.trim(),
        direccion: dir,
        comuna: partes.length > 1 ? partes.last.trim() : '',
        lat: _lat,
        lng: _lng,
        docIdentidad: _docIdentidad!,
        docPoderes: _docPoderes!,
        fotoFachada: _fachada!,
        fotoLetrero: _letrero!,
        fotoInterior: _interior!,
      );
      if (!mounted) return;
      _editar = false;
      await _cargar();
      _aviso('¡Listo! Enviamos tus datos a revisión.');
    } catch (e) {
      if (mounted) _aviso('$e'.replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  void _ayuda() {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Qué es Comercio verificado?',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary)),
              const SizedBox(height: 10),
              Text(
                'Es la insignia para pymes y empresas con giro comercial. '
                'El equipo de OkVenta revisa el RUT, la razón social, al '
                'representante legal, la dirección y fotos del local.\n\n'
                'Con la insignia, tus productos y servicios muestran '
                '"Verificado" y los compradores pueden ver el perfil de tu '
                'comercio: así compran con más confianza.\n\n'
                'La revisión toma hasta 2 días hábiles. Tus documentos son '
                'privados: no se muestran a otros usuarios.',
                style: TextStyle(
                    fontSize: 13.5, height: 1.45, color: colors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estado = (_estado?['estado'] ?? 'ninguna').toString();
    final verificado = _estado?['verificado'] == true;
    final mostrarForm =
        !_cargando && (estado == 'ninguna' || (estado == 'rechazada' && _editar));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colors.textPrimary,
        centerTitle: true,
        title: Image.asset(
            ThemeService.isDarkMode
                ? 'assets/images/logo_okventa_blanco.png'
                : 'assets/images/logo_okventa.png',
            height: 34),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: _ayuda,
          ),
        ],
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Text('Verificar mi comercio',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary)),
                const SizedBox(height: 2),
                Text('Genera confianza y destaca tu negocio',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: colors.textSecondary)),
                const SizedBox(height: 16),
                if (mostrarForm) ...[
                  if (estado == 'rechazada') _bannerRechazo(),
                  _bannerInsignia(),
                  ..._formulario(),
                ] else
                  _vistaEstado(estado, verificado),
              ],
            ),
    );
  }

  Widget _bannerInsignia() => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: _rojo.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.verified_user_outlined, size: 40, color: _rojo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Comercio verificado',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _rojo)),
                const SizedBox(height: 2),
                Text('Confirma tus datos para obtener tu insignia.',
                    style: TextStyle(fontSize: 13.5, color: colors.textPrimary)),
              ],
            ),
          ),
        ]),
      );

  Widget _bannerRechazo() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Tu solicitud anterior fue rechazada: '
          '${_estado?['motivo_rechazo'] ?? 'revisa tus datos.'}\n'
          'Corrige lo necesario y vuelve a enviarla.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF5C4400)),
        ),
      );

  List<Widget> _formulario() => [
        // 1 ─ Datos del comercio
        _titulo(1, 'Datos del comercio'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _campo(
              'RUT de la empresa',
              _rutCtrl,
              'Ej. 12.345.678-9',
              teclado: TextInputType.text,
              formato: [_FormatoRut()],
              error: _rutCtrl.text.length >= 9 &&
                      !ComercioService.rutValido(_rutCtrl.text)
                  ? 'RUT no válido'
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: _campo(
                  'Razón social', _razonCtrl, 'Ej. Inversiones SpA')),
        ]),
        _campo('Nombre comercial', _nombreCtrl, 'Ej. Mi Tienda'),

        // 2 ─ Responsable
        _titulo(2, 'Responsable del comercio'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _cajaArchivo(
              icono: Icons.badge_outlined,
              titulo: 'Documento de identidad',
              archivo: _docIdentidad,
              ayuda: 'Sube una foto o archivo',
              onTap: () async {
                final f = await _elegirDocumento('Documento de identidad');
                if (f != null) setState(() => _docIdentidad = f);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _cajaArchivo(
              icono: Icons.description_outlined,
              titulo:
                  'Certificado de vigencia de poderes o escritura con certificado de vigencia',
              archivo: _docPoderes,
              ayuda: 'Sube una foto o archivo',
              onTap: () async {
                final f = await _elegirDocumento('Vigencia de poderes');
                if (f != null) setState(() => _docPoderes = f);
              },
            ),
          ),
        ]),

        // 3 ─ Ubicación
        _titulo(3, 'Ubicación del comercio'),
        _campo('Dirección, número y comuna', _direccionCtrl,
            'Ej. Av. Providencia 123, Santiago'),
        GestureDetector(
          onTap: _elegirEnMapa,
          child: Stack(children: [
            MapaMini(
              key: ValueKey('${_lat}_$_lng'),
              lat: _lat ?? -33.4372,
              lng: _lng ?? -70.6506,
              alto: 150,
              zoom: _lat == null ? 12 : 16,
              abrirAlTocar: false,
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_lat == null ? 'Toca para marcar' : 'Toca para mover',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _buscandoGps ? null : _usarMiUbicacion,
            icon: _buscandoGps
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _rojo))
                : const Icon(Icons.my_location_rounded, size: 19),
            label: const Text('Usar mi ubicación actual'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _rojo,
              side: const BorderSide(color: _rojo),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),

        // 4 ─ Fotos del local
        _titulo(4, 'Fotos del local'),
        Row(children: [
          for (final (nombre, archivo, poner) in [
            ('Fachada', _fachada, (File f) => _fachada = f),
            ('Letrero', _letrero, (File f) => _letrero = f),
            ('Interior', _interior, (File f) => _interior = f),
          ]) ...[
            Expanded(
              child: _cajaFoto(nombre, archivo, () async {
                final f = await _tomarFoto();
                if (f != null) setState(() => poner(f));
              }),
            ),
            if (nombre != 'Interior') const SizedBox(width: 10),
          ],
        ]),
        const SizedBox(height: 6),
        Text('Toma las fotos desde la aplicación.',
            style: TextStyle(fontSize: 12, color: colors.textSecondary)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_rounded, size: 14, color: colors.grayMid),
          const SizedBox(width: 4),
          Text('Tus documentos son privados.',
              style: TextStyle(fontSize: 12.5, color: colors.grayMid)),
        ]),
        const SizedBox(height: 10),
        _botonEnviar(),
      ];

  Widget _botonEnviar() => Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
              colors: [Color(0xFFE94B4B), Color(0xFFC81E1E)]),
          boxShadow: [
            BoxShadow(
                color: _rojo.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _enviando ? null : _enviar,
            child: Center(
              child: _enviando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white))
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Enviar a revisión',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 20),
                    ]),
            ),
          ),
        ),
      );

  Widget _titulo(int n, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 22, 0, 12),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _rojo.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Text('$n',
                style: const TextStyle(
                    color: _rojo, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Text(t,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary)),
        ]),
      );

  Widget _campo(String label, TextEditingController c, String hint,
      {TextInputType teclado = TextInputType.text,
      List<TextInputFormatter>? formato,
      String? error}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: teclado,
          inputFormatters: formato,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          style: TextStyle(fontSize: 15, color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            errorText: error,
            hintStyle: TextStyle(color: colors.grayMid, fontSize: 14.5),
            filled: true,
            fillColor: colors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colors.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _rojo, width: 1.4)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _rojo)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _rojo, width: 1.4)),
          ),
        ),
      ]),
    );
  }

  Widget _cajaArchivo({
    required IconData icono,
    required String titulo,
    required String ayuda,
    required File? archivo,
    required VoidCallback onTap,
  }) {
    final listo = archivo != null;
    final nombre = archivo?.path.split('/').last ?? '';
    return _Punteado(
      color: listo ? Colors.green : colors.divider,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 150),
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(listo ? Icons.check_circle_rounded : icono,
                  size: 38,
                  color: listo ? Colors.green : colors.textPrimary),
              const SizedBox(height: 10),
              Text(titulo,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13.5,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary)),
              const SizedBox(height: 4),
              Text(listo ? nombre : ayuda,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: listo ? Colors.green : colors.grayMid)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cajaFoto(String nombre, File? archivo, VoidCallback onTap) {
    return _Punteado(
      color: archivo != null ? Colors.green : colors.divider,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 118,
          child: archivo != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.file(archivo, fit: BoxFit.cover),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('$nombre ✓',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_camera_outlined,
                        size: 34, color: colors.textPrimary),
                    const SizedBox(height: 8),
                    Text(nombre,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary)),
                    Text('Toma una foto',
                        style: TextStyle(fontSize: 12, color: colors.grayMid)),
                  ],
                ),
        ),
      ),
    );
  }

  /// Estado de una solicitud ya enviada.
  Widget _vistaEstado(String estado, bool verificado) {
    final d = _estado?['datos'] as Map?;
    late final IconData icono;
    late final Color color;
    late final String titulo, texto;
    if (verificado || estado == 'aprobada') {
      icono = Icons.verified_rounded;
      color = const Color(0xFF1E88E5);
      titulo = '¡Tu comercio está verificado!';
      texto = 'Tus productos y servicios ya muestran la insignia '
          '"Verificado". Los compradores pueden ver el perfil de tu comercio.';
    } else if (estado == 'rechazada') {
      icono = Icons.error_outline_rounded;
      color = _rojo;
      titulo = 'No pudimos verificar tu comercio';
      texto = (_estado?['motivo_rechazo'] ?? 'Revisa tus datos.').toString();
    } else {
      icono = Icons.hourglass_top_rounded;
      color = const Color(0xFFF5A623);
      titulo = 'Estamos revisando tus datos';
      texto = 'La revisión toma hasta 2 días hábiles. Te avisaremos con una '
          'notificación cuando esté lista.';
    }
    return Column(children: [
      const SizedBox(height: 8),
      Icon(icono, size: 72, color: color),
      const SizedBox(height: 12),
      Text(titulo,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary)),
      const SizedBox(height: 8),
      Text(texto,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14, height: 1.4, color: colors.textSecondary)),
      if (d != null) ...[
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.divider, width: 0.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (k, v) in [
                ('Nombre comercial', d['nombre_comercial']),
                ('Razón social', d['razon_social']),
                ('RUT', d['rut']),
                ('Dirección', d['direccion']),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(k,
                            style: TextStyle(
                                fontSize: 13, color: colors.grayMid)),
                      ),
                      Expanded(
                        child: Text('${v ?? ''}',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 20),
      if (verificado || estado == 'aprobada')
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _userId == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            PerfilComercioScreen(userId: _userId!))),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ver el perfil de mi comercio'),
          ),
        ),
      if (estado == 'rechazada')
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() => _editar = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _rojo,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Corregir y volver a enviar'),
          ),
        ),
    ]);
  }
}

/// Borde punteado redondeado (cajas para subir archivos y fotos).
class _Punteado extends StatelessWidget {
  final Widget child;
  final Color color;
  const _Punteado({required this.child, required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _PintorPunteado(color),
        child: child,
      );
}

class _PintorPunteado extends CustomPainter {
  final Color color;
  _PintorPunteado(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(12)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 5), p);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PintorPunteado old) => old.color != color;
}

/// Da formato al RUT mientras se escribe: 12.345.678-9.
class _FormatoRut extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final limpio =
        newValue.text.replaceAll(RegExp(r'[^0-9kK]'), '').toUpperCase();
    final corto = limpio.length > 9 ? limpio.substring(0, 9) : limpio;
    final t = ComercioService.formatearRut(corto);
    return TextEditingValue(
        text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}
