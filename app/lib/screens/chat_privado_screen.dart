import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/privados_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/orden_acciones.dart';
import '../widgets/avatar_usuario.dart';
import '../widgets/compartir_ubicacion.dart';
import '../widgets/mapa_mini.dart';
import 'perfil_publico_screen.dart';

/// Chat privado 1 a 1 entre usuarios (se abre tocando a alguien en
/// Comunidad, o desde Mensajes → Privados). Se actualiza cada 4 s mientras
/// está abierto. Se puede compartir la ubicación exacta.
class ChatPrivadoScreen extends StatefulWidget {
  final int otroId;
  final String nombre;
  final String? fotoUrl;
  final String? mensajeInicial;

  const ChatPrivadoScreen({
    super.key,
    required this.otroId,
    required this.nombre,
    this.fotoUrl,
    this.mensajeInicial,
  });

  @override
  State<ChatPrivadoScreen> createState() => _ChatPrivadoScreenState();
}

class _ChatPrivadoScreenState extends State<ChatPrivadoScreen> {
  final _mensajes = <Map<String, dynamic>>[];
  late final _ctrl = TextEditingController(text: widget.mensajeInicial ?? '');
  final _scroll = ScrollController();
  int? _yo;
  late String _nombre = widget.nombre;
  late String? _foto = widget.fotoUrl;
  bool _cargando = true;
  bool _enviando = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    _yo = await SessionService.obtenerUser();
    if (_nombre.trim().isEmpty) _cargarPerfil();
    await _traer();
    if (mounted) setState(() => _cargando = false);
    _alFinal();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _traer());
  }

  /// Abierto desde una notificación: solo se sabe el id, se busca el nombre.
  Future<void> _cargarPerfil() async {
    try {
      final r = await http.get(Uri.parse(
          '${ApiService.baseUrl}/usuarios/${widget.otroId}/perfil_publico'));
      if (r.statusCode != 200 || !mounted) return;
      final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
      setState(() {
        _nombre = (d['nombre'] ?? 'Usuario').toString();
        final f = (d['foto_url'] ?? '').toString();
        _foto = f.isEmpty ? null : f;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int get _ultimo =>
      _mensajes.isEmpty ? 0 : (_mensajes.last['id'] as num).toInt();

  Future<void> _traer() async {
    final yo = _yo;
    if (yo == null) return;
    final nuevos = await PrivadosService.conversacion(yo, widget.otroId,
        despuesDe: _ultimo);
    if (!mounted || nuevos.isEmpty) return;
    final cerca = !_scroll.hasClients ||
        _scroll.position.maxScrollExtent - _scroll.offset < 120;
    setState(() {
      for (final m in nuevos) {
        if (!_mensajes.any((x) => x['id'] == m['id'])) _mensajes.add(m);
      }
    });
    if (cerca) _alFinal();
  }

  void _alFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _enviar({double? lat, double? lng, String? texto}) async {
    final yo = _yo;
    final t = (texto ?? _ctrl.text).trim();
    if (yo == null || _enviando || (t.isEmpty && lat == null)) return;
    setState(() => _enviando = true);
    final m = await PrivadosService.enviar(
        deId: yo, paraId: widget.otroId, texto: t, lat: lat, lng: lng);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (m != null) {
        if (texto == null) _ctrl.clear();
        if (!_mensajes.any((x) => x['id'] == m['id'])) _mensajes.add(m);
      }
    });
    if (m == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar. Intenta de nuevo.')));
    } else {
      HapticFeedback.lightImpact();
      _alFinal();
    }
  }

  Future<void> _ubicacion() async {
    final u = await pedirUbicacionCompartida(context, publico: false);
    if (u == null) return;
    await _enviar(lat: u.lat, lng: u.lng, texto: u.texto);
  }

  String _hora(dynamic ts) {
    final d = DateTime.tryParse('${ts.toString().replaceFirst(' ', 'T')}Z')
        ?.toLocal();
    if (d == null) return '';
    return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PerfilPublicoScreen(
                    userId: widget.otroId, nombre: _nombre)),
          ),
          child: Row(children: [
            AvatarUsuario(
                fotoUrl: _foto, nombre: _nombre, tamano: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary)),
                  Text('Mensaje privado',
                      style: TextStyle(
                          fontSize: 11.5, color: colors.textPrimary)),
                ],
              ),
            ),
          ]),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _cargando
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary))
                : _mensajes.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                              'Escríbele a ${_nombre.split(' ').first}. '
                              'Solo ustedes dos ven esta conversación.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.textPrimary)),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: _mensajes.length,
                        itemBuilder: (_, i) => _burbuja(_mensajes[i]),
                      ),
          ),
          _caja(),
        ],
      ),
    );
  }

  Widget _burbuja(Map<String, dynamic> m) {
    final mio = m['de_id'] == _yo;
    final ubic = m['ubicacion'] as Map?;
    final texto = (m['texto'] ?? '').toString();
    final colorTexto = mio ? Colors.white : colors.textPrimary;
    // Comprobante de una compra/venta compartido desde Mis órdenes.
    final comp = OrdenAcciones.deTexto(texto);
    if (comp != null) {
      return Align(
        alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              mio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TarjetaComprobante(
                  datos: comp,
                  ancho: MediaQuery.of(context).size.width * 0.7 > 270
                      ? 270
                      : MediaQuery.of(context).size.width * 0.7),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(_hora(m['created_at']),
                  style: TextStyle(fontSize: 9.5, color: colors.textPrimary)),
            ),
          ],
        ),
      );
    }
    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            mio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
            decoration: BoxDecoration(
              color: mio ? colors.primary : colors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mio ? 16 : 4),
                bottomRight: Radius.circular(mio ? 4 : 16),
              ),
              border: mio
                  ? null
                  : Border.all(color: colors.divider, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ubic != null) ...[
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.location_on_rounded,
                        size: 15, color: colorTexto),
                    const SizedBox(width: 3),
                    Text('Ubicación',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: colorTexto)),
                  ]),
                  const SizedBox(height: 5),
                  MapaMini(
                      lat: (ubic['lat'] as num).toDouble(),
                      lng: (ubic['lng'] as num).toDouble(),
                      alto: 120,
                      ancho: 220),
                  if (texto.isNotEmpty) const SizedBox(height: 6),
                ],
                if (texto.isNotEmpty)
                  Text(texto,
                      style: TextStyle(fontSize: 14.5, color: colorTexto)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(_hora(m['created_at']),
                style: TextStyle(fontSize: 9.5, color: colors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _caja() {
    final puede = _ctrl.text.trim().isNotEmpty && !_enviando;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(children: [
          IconButton(
            tooltip: 'Enviar mi ubicación',
            onPressed: _ubicacion,
            icon: Icon(Icons.location_on_outlined,
                color: colors.primary, size: 24),
          ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 15.5, color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje privado…',
                hintStyle: TextStyle(color: colors.grayMid),
                filled: true,
                fillColor: colors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide(color: colors.divider)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide(color: colors.divider)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: puede ? () => _enviar() : null,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: puede ? colors.primary : colors.divider,
                shape: BoxShape.circle,
              ),
              child: _enviando
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 21),
            ),
          ),
        ]),
      ),
    );
  }
}
