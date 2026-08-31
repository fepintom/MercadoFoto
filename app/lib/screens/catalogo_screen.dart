import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/net_image.dart';

/// Catálogo de tienda del vendedor.
///
/// Sube un PDF o enlaza su página; el backend lo procesa en segundo plano
/// (leer un catálogo con IA toma decenas de segundos), así que esta pantalla
/// consulta el avance cada pocos segundos mientras está en 'procesando'.
///
/// Cuando queda listo, el vendedor ve la vitrina tal como la verán los
/// compradores en su perfil, y puede ocultar los ítems que no quiera mostrar.
class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  int? _userId;
  Map<String, dynamic>? _catalogo;
  bool _cargando = true;
  bool _subiendo = false;
  Timer? _poll;
  final _urlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    _userId = await SessionService.obtenerUser();
    await _cargar();
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargar() async {
    if (_userId == null) return;
    try {
      final data = await ApiService.obtenerMiCatalogo(_userId!);
      if (!mounted) return;
      setState(() => _catalogo = data['existe'] == true ? data : null);
      _ajustarPoll();
    } catch (_) {
      // Silencioso: es una consulta de avance, no vale interrumpir al usuario.
    }
  }

  /// Consulta cada 4 s solo mientras el backend está procesando.
  void _ajustarPoll() {
    final procesando = _catalogo?['estado'] == 'procesando';
    if (procesando && _poll == null) {
      _poll = Timer.periodic(const Duration(seconds: 4), (_) => _cargar());
    } else if (!procesando) {
      _poll?.cancel();
      _poll = null;
    }
  }

  void _aviso(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: error ? colors.primary : colors.carbon,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _subirPdf() async {
    if (_userId == null || _subiendo) return;
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      final ruta = res?.files.single.path;
      if (ruta == null) return;

      setState(() => _subiendo = true);
      await ApiService.subirCatalogoPdf(_userId!, File(ruta));
      await _cargar();
      _aviso('Estamos leyendo tu catálogo. Puede tardar un par de minutos.');
    } catch (e) {
      _aviso('$e'.replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _enlazarWeb() async {
    final url = _urlCtrl.text.trim();
    if (_userId == null || _subiendo || url.isEmpty) return;
    setState(() => _subiendo = true);
    try {
      final r = await ApiService.enlazarCatalogoWeb(_userId!, url);
      _urlCtrl.clear();
      await _cargar();
      final aviso = r['aviso'] as String?;
      _aviso(aviso ?? 'Estamos leyendo tu página. Puede tardar un momento.');
    } catch (e) {
      _aviso('$e'.replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Quitar catálogo',
            style: TextStyle(color: colors.textPrimary)),
        content: Text(
            'Tu tienda dejará de verse en tu perfil. Puedes volver a subirla '
            'cuando quieras.',
            style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Quitar', style: TextStyle(color: colors.primary))),
        ],
      ),
    );
    if (ok != true || _userId == null) return;
    try {
      await ApiService.eliminarCatalogo(_userId!);
      await _cargar();
      _aviso('Catálogo quitado');
    } catch (e) {
      _aviso('$e'.replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _alternarVisible(Map<String, dynamic> p) async {
    if (_userId == null) return;
    final nuevo = (p['visible'] ?? 1) != 1;
    setState(() => p['visible'] = nuevo ? 1 : 0);
    try {
      await ApiService.cambiarVisibilidadCatalogo(
          p['id'] as int, _userId!, nuevo);
    } catch (e) {
      setState(() => p['visible'] = nuevo ? 0 : 1);
      _aviso('No se pudo actualizar', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: const Text('Catálogo'),
        actions: [
          if (_catalogo != null)
            IconButton(
              onPressed: _eliminar,
              icon: Icon(Icons.delete_outline_rounded, color: colors.grayMid),
            ),
        ],
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _userId == null
              ? _mensajeCentrado(
                  Icons.lock_outline_rounded,
                  'Inicia sesión para publicar tu catálogo.')
              : RefreshIndicator(
                  color: colors.primary,
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    children: [
                      _intro(),
                      const SizedBox(height: 20),
                      if (_catalogo == null) ..._formularios() else _estado(),
                    ],
                  ),
                ),
    );
  }

  Widget _mensajeCentrado(IconData icono, String texto) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icono, size: 42, color: colors.grayMid),
            const SizedBox(height: 12),
            Text(texto,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.grayMid)),
          ]),
        ),
      );

  Widget _intro() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tu tienda dentro de OkVenta',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'Sube tu catálogo o enlaza tu página y lo mostramos en tu perfil, '
            'con tus productos y los colores de tu marca.',
            style: TextStyle(fontSize: 13.5, color: colors.grayMid, height: 1.45),
          ),
        ],
      );

  List<Widget> _formularios() => [
        _tarjeta(
          icono: Icons.picture_as_pdf_rounded,
          titulo: 'Subir un PDF',
          detalle: 'Tu catálogo tal cual lo tienes. Hasta 25 MB.',
          hijo: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _subiendo ? null : _subirPdf,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(_subiendo ? 'Subiendo...' : 'Elegir archivo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _tarjeta(
          icono: Icons.link_rounded,
          titulo: 'Enlazar tu página',
          detalle:
              'Tu tienda online o tu perfil de Instagram. De Instagram tomamos '
              'tu nombre, foto y colores; para traer tus publicaciones hay que '
              'conectar su API oficial.',
          hijo: Column(
            children: [
              TextField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                style: TextStyle(fontSize: 14, color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'mitienda.cl',
                  hintStyle: TextStyle(color: colors.grayMid),
                  isDense: true,
                  filled: true,
                  fillColor: colors.background,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.divider, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.divider, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _subiendo ? null : _enlazarWeb,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Enlazar'),
                ),
              ),
            ],
          ),
        ),
      ];

  Widget _tarjeta({
    required IconData icono,
    required String titulo,
    required String detalle,
    required Widget hijo,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: colors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(titulo,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(detalle,
              style:
                  TextStyle(fontSize: 12.5, color: colors.grayMid, height: 1.4)),
          const SizedBox(height: 14),
          hijo,
        ],
      ),
    );
  }

  // ── Estado del catálogo ya subido ─────────────────────────────────────────

  Widget _estado() {
    final cat = _catalogo!;
    final estado = cat['estado'] as String?;

    if (estado == 'procesando') {
      return _tarjeta(
        icono: Icons.hourglass_top_rounded,
        titulo: 'Leyendo tu catálogo',
        detalle:
            'Estamos identificando tus productos y los colores de tu marca. '
            'Puedes salir de esta pantalla: te esperamos aquí cuando vuelvas.',
        hijo: LinearProgressIndicator(
          color: colors.primary,
          backgroundColor: colors.divider,
        ),
      );
    }

    if (estado == 'error') {
      return Column(children: [
        _tarjeta(
          icono: Icons.error_outline_rounded,
          titulo: 'No pudimos leerlo',
          detalle: (cat['mensaje_error'] as String?) ??
              'Ocurrió un problema al procesar el catálogo.',
          hijo: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _eliminar,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Intentar con otro'),
            ),
          ),
        ),
      ]);
    }

    final productos =
        List<Map<String, dynamic>>.from(cat['productos'] ?? const []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VitrinaCatalogo(catalogo: cat, soloLectura: true),
        const SizedBox(height: 20),
        Text('Qué se muestra',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
        const SizedBox(height: 4),
        Text('Apaga los que no quieras mostrar en tu perfil.',
            style: TextStyle(fontSize: 12.5, color: colors.grayMid)),
        const SizedBox(height: 10),
        ...productos.map(_filaProducto),
      ],
    );
  }

  Widget _filaProducto(Map<String, dynamic> p) {
    final visible = (p['visible'] ?? 1) == 1;
    final img = p['imagen_url'] as String?;
    return Opacity(
      opacity: visible ? 1 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider, width: 0.5),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (img != null && img.isNotEmpty)
                ? NetImage('${ApiService.baseUrl}$img',
                    width: 48, height: 48, fit: BoxFit.cover)
                : Container(
                    width: 48,
                    height: 48,
                    color: colors.background,
                    child: Icon(Icons.inventory_2_outlined,
                        size: 20, color: colors.grayMid),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['titulo']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary)),
                if (p['precio'] != null)
                  Text(formatPrecio(p['precio']),
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: colors.primary)),
              ],
            ),
          ),
          Switch(
            value: visible,
            activeColor: colors.primary,
            onChanged: (_) => _alternarVisible(p),
          ),
        ]),
      ),
    );
  }
}

/// La vitrina de la tienda: la franja con la marca del vendedor y sus
/// productos. Se usa igual en el perfil del dueño (vista previa) y en el
/// perfil público que ven los compradores.
///
/// Los colores vienen del catálogo del vendedor, así que son arbitrarios:
/// pasan por [AppPalette.textoLegibleSobre] para que el texto sea legible
/// sea cual sea la marca.
class VitrinaCatalogo extends StatelessWidget {
  final Map<String, dynamic> catalogo;
  final bool soloLectura;

  const VitrinaCatalogo({
    super.key,
    required this.catalogo,
    this.soloLectura = false,
  });

  @override
  Widget build(BuildContext context) {
    final productos = List<Map<String, dynamic>>.from(
        catalogo['productos'] ?? const []).where((p) {
      return soloLectura ? true : (p['visible'] ?? 1) == 1;
    }).toList();
    if (productos.isEmpty) return const SizedBox.shrink();

    final fondo = AppPalette.desdeHex(catalogo['color_fondo'] as String?) ??
        colors.surface;
    final acento =
        AppPalette.desdeHex(catalogo['color_primario'] as String?) ??
            colors.primary;
    final sobreFondo = AppPalette.textoLegibleSobre(fondo);
    final nombre = (catalogo['nombre_tienda'] as String?)?.trim();
    final logo = catalogo['logo_url'] as String?;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (logo != null && logo.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: NetImage('${ApiService.baseUrl}$logo',
                    width: 38, height: 38, fit: BoxFit.cover),
              )
            else
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: acento,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.storefront_rounded,
                    size: 20, color: AppPalette.textoLegibleSobre(acento)),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre?.isNotEmpty == true ? nombre! : 'Catálogo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: sobreFondo)),
                  Text('${productos.length} productos',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: sobreFondo.withOpacity(0.75))),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: productos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) =>
                  _tarjetaVitrina(productos[i], acento, sobreFondo, fondo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaVitrina(Map<String, dynamic> p, Color acento,
      Color sobreFondo, Color fondo) {
    final img = p['imagen_url'] as String?;
    // El precio conserva el color de acento de la tienda, pero ajustado
    // para que se lea sobre su propio fondo.
    final colorPrecio = AppPalette.ajustarSobre(acento, fondo);
    return SizedBox(
      width: 124,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: (img != null && img.isNotEmpty)
                ? NetImage('${ApiService.baseUrl}$img',
                    width: 124, height: 106, fit: BoxFit.cover)
                : Container(
                    width: 124,
                    height: 106,
                    color: sobreFondo.withOpacity(0.08),
                    child: Icon(Icons.inventory_2_outlined,
                        color: sobreFondo.withOpacity(0.5)),
                  ),
          ),
          const SizedBox(height: 6),
          Text(p['titulo']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                  color: sobreFondo)),
          if (p['precio'] != null)
            Text(formatPrecio(p['precio']),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colorPrecio)),
        ],
      ),
    );
  }
}
