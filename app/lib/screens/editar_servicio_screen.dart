import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/net_image.dart';

/// Edición de una publicación de servicio.
///
/// Antes no existía: tocar tu propio servicio en "Mis servicios" abría el
/// detalle público y no había forma de corregir nada. Sigue el mismo patrón
/// que la edición de productos — campos, vista previa y guardar — para que
/// se sienta igual en las dos partes de la app.
class EditarServicioScreen extends StatefulWidget {
  final Map<String, dynamic> servicio;

  const EditarServicioScreen({super.key, required this.servicio});

  @override
  State<EditarServicioScreen> createState() => _EditarServicioScreenState();
}

class _EditarServicioScreenState extends State<EditarServicioScreen> {
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _comunasCtrl;
  late final TextEditingController _valorCtrl;
  late String _modalidad;

  /// Fotos que ya estaban en el servidor y se conservan.
  late List<String> _fotosExistentes;

  /// Fotos recién elegidas desde el teléfono.
  final List<File> _fotosNuevas = [];

  int? _userId;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final s = widget.servicio;
    _tituloCtrl = TextEditingController(text: (s['titulo'] ?? '').toString());
    _descCtrl =
        TextEditingController(text: (s['descripcion'] ?? '').toString());
    _comunasCtrl = TextEditingController(text: (s['comunas'] ?? '').toString());
    final valor = (s['valor'] as num?)?.toDouble() ?? 0;
    _valorCtrl =
        TextEditingController(text: valor > 0 ? valor.toStringAsFixed(0) : '');
    _modalidad = (s['modalidad'] ?? 'servicio').toString();
    _fotosExistentes = _leerFotos(s['fotos']);
    _cargarUsuario();
  }

  /// Las fotos pueden llegar de dos formas según de dónde venga el servicio:
  /// como lista (lo normal) o como el texto JSON tal cual sale de la base de
  /// datos. Un endpoint devolvía lo segundo y por eso al editar un servicio
  /// propio el bloque de fotos aparecía vacío aunque tuviera fotos. El
  /// servidor ya está corregido; esto aguanta las dos formas para que la app
  /// funcione también contra un servidor sin actualizar.
  ///
  /// Ojo con el `??`: mezclar Iterable<String> con un [] vacío hace que Dart
  /// infiera Object y no compile. Por eso los `if` explícitos.
  static List<String> _leerFotos(dynamic raw) {
    if (raw is List) return raw.whereType<String>().toList();
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is List) return d.whereType<String>().toList();
      } catch (_) {
        // No era JSON: se trata como si no hubiera fotos.
      }
    }
    return <String>[];
  }

  Future<void> _cargarUsuario() async {
    _userId = await SessionService.obtenerUser();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _comunasCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  void _aviso(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: error ? colors.primary : colors.carbon,
      behavior: SnackBarBehavior.floating,
    ));
  }

  int get _totalFotos => _fotosExistentes.length + _fotosNuevas.length;

  Future<void> _agregarFoto() async {
    if (_totalFotos >= 4) {
      _aviso('Máximo 4 fotos');
      return;
    }
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1280);
    if (picked == null) return;
    setState(() => _fotosNuevas.add(File(picked.path)));
  }

  Future<void> _guardar() async {
    if (_userId == null || _guardando) return;
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty) {
      _aviso('El título no puede quedar vacío', error: true);
      return;
    }
    setState(() => _guardando = true);
    try {
      await ApiService.editarServicio(
        servicioId: widget.servicio['id'] as int,
        userId: _userId!,
        titulo: titulo,
        descripcion: _descCtrl.text.trim(),
        comunas: _comunasCtrl.text.trim(),
        valor: double.tryParse(
                _valorCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ??
            0,
        modalidad: _modalidad,
        fotosMantener: _fotosExistentes,
        fotosNuevas: _fotosNuevas,
      );
      if (!mounted) return;
      _aviso('Cambios guardados');
      Navigator.pop(context, true);
    } catch (e) {
      _aviso('$e'.replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _vistaPrevia() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VistaPreviaServicio(
          titulo: _tituloCtrl.text.trim(),
          descripcion: _descCtrl.text.trim(),
          comunas: _comunasCtrl.text.trim(),
          valor: double.tryParse(
                  _valorCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ??
              0,
          modalidad: _modalidad,
          tipo: (widget.servicio['tipo'] ?? 'ofrezco').toString(),
          fotosExistentes: _fotosExistentes,
          fotosNuevas: _fotosNuevas,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: const Text('Editar servicio'),
        actions: [
          TextButton(
            onPressed: _vistaPrevia,
            child: Text('Vista previa',
                style: TextStyle(
                    color: colors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _campo('Título', _tituloCtrl),
          const SizedBox(height: 14),
          _campo('Descripción', _descCtrl, lineas: 4),
          const SizedBox(height: 14),
          _campo('Comunas donde atiendes', _comunasCtrl),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _campo('Valor', _valorCtrl,
                    teclado: TextInputType.number),
              ),
              const SizedBox(width: 12),
              Expanded(child: _selectorModalidad()),
            ],
          ),
          const SizedBox(height: 20),
          _seccionFotos(),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: colors.grayMid,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar cambios',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(String label, TextEditingController c,
      {TextInputType teclado = TextInputType.text, int lineas = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: colors.grayMid)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: teclado,
          maxLines: lineas,
          style: TextStyle(fontSize: 14, color: colors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: colors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      ],
    );
  }

  Widget _selectorModalidad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cobro', style: TextStyle(fontSize: 12.5, color: colors.grayMid)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.divider, width: 0.5),
          ),
          child: Row(
            children: [
              for (final m in const ['servicio', 'hora'])
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _modalidad = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: _modalidad == m
                            ? colors.primary.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        m == 'hora' ? 'Por hora' : 'Por servicio',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _modalidad == m
                              ? colors.primary
                              : colors.grayMid,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seccionFotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos ($_totalFotos de 4)',
            style: TextStyle(fontSize: 12.5, color: colors.grayMid)),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (int i = 0; i < _fotosExistentes.length; i++)
                _miniatura(
                  hijo: NetImage('${ApiService.baseUrl}${_fotosExistentes[i]}',
                      width: 92, height: 92, fit: BoxFit.cover),
                  onQuitar: () =>
                      setState(() => _fotosExistentes.removeAt(i)),
                ),
              for (int i = 0; i < _fotosNuevas.length; i++)
                _miniatura(
                  hijo: Image.file(_fotosNuevas[i],
                      width: 92, height: 92, fit: BoxFit.cover),
                  onQuitar: () => setState(() => _fotosNuevas.removeAt(i)),
                ),
              if (_totalFotos < 4)
                GestureDetector(
                  onTap: _agregarFoto,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.divider),
                    ),
                    child: Icon(Icons.add_a_photo_outlined,
                        color: colors.grayMid, size: 22),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniatura({required Widget hijo, required VoidCallback onQuitar}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: hijo),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onQuitar,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close,
                    size: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cómo se verá la publicación para los demás. Es solo lectura: reproduce
/// la tarjeta del listado de servicios para que el vendedor vea lo mismo
/// que ve un cliente antes de guardar.
class _VistaPreviaServicio extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final String comunas;
  final double valor;
  final String modalidad;
  final String tipo;
  final List<String> fotosExistentes;
  final List<File> fotosNuevas;

  const _VistaPreviaServicio({
    required this.titulo,
    required this.descripcion,
    required this.comunas,
    required this.valor,
    required this.modalidad,
    required this.tipo,
    required this.fotosExistentes,
    required this.fotosNuevas,
  });

  @override
  Widget build(BuildContext context) {
    final acento = tipo == 'ofrezco' ? colors.primary : colors.warning;
    final prefijo = tipo == 'ofrezco' ? 'Ofrezco' : 'Busco';

    Widget? portada;
    if (fotosExistentes.isNotEmpty) {
      portada = NetImage('${ApiService.baseUrl}${fotosExistentes.first}',
          width: double.infinity, height: 220, fit: BoxFit.cover);
    } else if (fotosNuevas.isNotEmpty) {
      portada = Image.file(fotosNuevas.first,
          width: double.infinity, height: 220, fit: BoxFit.cover);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: const Text('Vista previa'),
      ),
      body: ListView(
        children: [
          Container(
            color: colors.surface,
            child: portada ??
                Container(
                  height: 160,
                  alignment: Alignment.center,
                  child: Icon(Icons.handyman_outlined,
                      size: 42, color: colors.grayMid),
                ),
          ),
          Container(
            width: double.infinity,
            color: colors.surface,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: '$prefijo: ',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: acento),
                    ),
                    TextSpan(
                      text: titulo.isEmpty ? 'Sin título' : titulo,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary),
                    ),
                  ]),
                ),
                if (comunas.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: colors.grayMid),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(comunas,
                          style: TextStyle(
                              fontSize: 13, color: colors.grayMid)),
                    ),
                  ]),
                ],
                if (valor > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${formatPrecio(valor)} / ${modalidad == 'hora' ? 'hora' : 'servicio'}',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.primary),
                  ),
                ],
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(descripcion,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: colors.textSecondary)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Así verán tu publicación en el listado de servicios. Vuelve '
              'atrás para seguir editando.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: colors.grayMid),
            ),
          ),
        ],
      ),
    );
  }
}
