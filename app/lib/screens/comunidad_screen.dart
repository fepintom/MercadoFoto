import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_usuario.dart';
import '../widgets/net_image.dart';
import 'perfil_publico_screen.dart';
import 'producto_detalle_screen.dart';
import 'servicio_detalle_screen.dart';

/// Comunidad: una sala de chat abierta donde todos hablan con todos, como
/// los chats antiguos de Messenger.
///
/// - Cualquiera puede leer; para escribir hay que tener sesión.
/// - Se puede anclar una publicación o un servicio propio: sale como
///   tarjeta en el mensaje y en la franja "Anclados" de arriba.
/// - El bot de OkVenta saluda, publica ofertas y responde cuando lo
///   etiquetan con @okventa (la respuesta la genera el backend).
///
/// Versión inicial a propósito: sin moderación, sin respuestas en hilo ni
/// reacciones. La idea es ver cómo se usa antes de sumar más.
class ComunidadScreen extends StatefulWidget {
  /// Si esta pestaña es la que se está viendo. Vive dentro de un
  /// IndexedStack, así que existe aunque no se vea: sin esto seguiría
  /// consultando al servidor cada pocos segundos en segundo plano.
  final bool activa;

  /// Para pedir inicio de sesión desde el cuadro de texto.
  final VoidCallback? onPedirLogin;

  const ComunidadScreen({super.key, this.activa = true, this.onPedirLogin});

  @override
  State<ComunidadScreen> createState() => _ComunidadScreenState();
}

class _ComunidadScreenState extends State<ComunidadScreen> {
  static const _kIntervalo = Duration(seconds: 4);
  static const _kEmojis = [
    '😀', '😂', '😍', '🥳', '😎', '🤔', '😅', '😢', '😡', '👍', '👏', '🙏',
    '🙌', '💪', '🔥', '❤️', '💯', '🎉', '👋', '✅', '💰', '🛒', '📦', '🛠️',
  ];

  final _mensajes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _anclados = [];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _foco = FocusNode();

  int? _miId;
  bool _cargando = true;
  bool _enviando = false;
  bool _verEmojis = false;
  Map<String, dynamic>? _anclaElegida;
  Timer? _timer;

  int get _ultimoId =>
      _mensajes.isEmpty ? 0 : (_mensajes.last['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void didUpdateWidget(covariant ComunidadScreen old) {
    super.didUpdateWidget(old);
    if (widget.activa != old.activa) {
      if (widget.activa) {
        _refrescarSesion();
        _traerNuevos();
        _programar();
      } else {
        _timer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _refrescarSesion() async {
    final id = await SessionService.obtenerUser();
    if (mounted && id != _miId) setState(() => _miId = id);
  }

  Future<void> _iniciar() async {
    await _refrescarSesion();
    try {
      final msgs = await ApiService.obtenerMensajesComunidad();
      final anc = await ApiService.obtenerAncladosComunidad();
      if (!mounted) return;
      setState(() {
        _mensajes
          ..clear()
          ..addAll(msgs);
        _anclados = anc;
        _cargando = false;
      });
      _alFinal(animado: false);
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
    if (widget.activa) _programar();
  }

  void _programar() {
    _timer?.cancel();
    _timer = Timer.periodic(_kIntervalo, (_) => _traerNuevos());
  }

  Future<void> _traerNuevos() async {
    try {
      final nuevos =
          await ApiService.obtenerMensajesComunidad(despuesDe: _ultimoId);
      if (!mounted || nuevos.isEmpty) return;
      final estabaAbajo = !_scroll.hasClients ||
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 80;
      final ids = _mensajes.map((m) => m['id']).toSet();
      setState(() => _mensajes
          .addAll(nuevos.where((m) => !ids.contains(m['id']))));
      if (nuevos.any((m) => m['ancla_tipo'] != null)) {
        ApiService.obtenerAncladosComunidad().then((a) {
          if (mounted) setState(() => _anclados = a);
        });
      }
      // Si el usuario está leyendo más arriba, no se lo lleva de un tirón.
      if (estabaAbajo) _alFinal();
    } catch (_) {}
  }

  void _alFinal({bool animado = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final fin = _scroll.position.maxScrollExtent;
      if (animado) {
        _scroll.animateTo(fin,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(fin);
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (_miId == null) {
      widget.onPedirLogin?.call();
      return;
    }
    if (_enviando || (texto.isEmpty && _anclaElegida == null)) return;
    setState(() => _enviando = true);
    try {
      final msg = await ApiService.enviarMensajeComunidad(
        userId: _miId!,
        texto: texto,
        anclaTipo: _anclaElegida?['tipo'],
        anclaId: (_anclaElegida?['id'] as num?)?.toInt(),
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        if (!_mensajes.any((m) => m['id'] == msg['id'])) _mensajes.add(msg);
        _ctrl.clear();
        if (_anclaElegida != null) {
          _anclados = [msg, ..._anclados.where((a) =>
              !(a['ancla_tipo'] == msg['ancla_tipo'] &&
                  a['ancla_id'] == msg['ancla_id']))];
        }
        _anclaElegida = null;
      });
      _alFinal();
      // Si se etiquetó al bot, su respuesta llega en unos segundos: se
      // pide antes del siguiente ciclo para que no parezca que no oyó.
      if (texto.toLowerCase().contains('@okventa')) {
        Future.delayed(const Duration(milliseconds: 1500), _traerNuevos);
      }
    } catch (e) {
      if (!mounted) return;
      final txt = e.toString();
      final deRed = txt.contains('Socket') ||
          txt.contains('Connection') ||
          txt.contains('ClientException') ||
          txt.contains('TimeoutException');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(deRed
            ? 'No se pudo conectar con el servidor. Revisa tu internet e intenta de nuevo.'
            : txt.replaceFirst('Exception: ', '')),
        backgroundColor: colors.primary,
      ));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _insertar(String s) {
    final sel = _ctrl.selection;
    final t = _ctrl.text;
    final ini = sel.isValid ? sel.start : t.length;
    final fin = sel.isValid ? sel.end : t.length;
    _ctrl.value = TextEditingValue(
      text: t.replaceRange(ini, fin, s),
      selection: TextSelection.collapsed(offset: ini + s.length),
    );
    setState(() {});
  }

  // ── Anclar ──────────────────────────────────────────────────────────────

  Future<void> _elegirAncla() async {
    if (_miId == null) {
      widget.onPedirLogin?.call();
      return;
    }
    final elegido = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SelectorAncla(userId: _miId!),
    );
    if (elegido != null && mounted) {
      setState(() => _anclaElegida = elegido);
      _foco.requestFocus();
    }
  }

  Future<void> _abrirAncla(String? tipo, int? id) async {
    if (tipo == null || id == null) return;
    if (tipo == 'publicacion') {
      final p = await ApiService.obtenerPublicacion(id);
      if (!mounted) return;
      if (p == null) {
        _avisoNoDisponible();
        return;
      }
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: p)));
    } else {
      final s = await ApiService.obtenerServicioPorId(id);
      if (!mounted) return;
      if (s == null) {
        _avisoNoDisponible();
        return;
      }
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ServicioDetalleScreen(servicio: s)));
    }
  }

  void _avisoNoDisponible() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Esto ya no está disponible'),
      backgroundColor: colors.carbon,
    ));
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.background,
      child: Column(
        children: [
          _encabezado(),
          if (_anclados.isNotEmpty) _franjaAnclados(),
          Expanded(
            child: _cargando
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary))
                : GestureDetector(
                    onTap: () {
                      _foco.unfocus();
                      if (_verEmojis) setState(() => _verEmojis = false);
                    },
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      itemCount: _mensajes.length,
                      itemBuilder: (_, i) => _burbuja(i),
                    ),
                  ),
          ),
          if (_verEmojis) _barraEmojis(),
          _cajaTexto(),
        ],
      ),
    );
  }

  Widget _encabezado() {
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.groups_outlined, size: 20, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Comunidad',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary)),
                Text('Conversa con todos · etiqueta a @okventa',
                    style: TextStyle(fontSize: 11, color: colors.grayMid)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _franjaAnclados() {
    return Container(
      color: colors.surface,
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        itemCount: _anclados.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final a = _anclados[i];
          return GestureDetector(
            onTap: () =>
                _abrirAncla(a['ancla_tipo'], (a['ancla_id'] as num?)?.toInt()),
            child: Container(
              width: 190,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.divider, width: 0.5),
              ),
              child: Row(
                children: [
                  _miniatura(a['ancla_imagen'], 40,
                      a['ancla_tipo'] == 'servicio'),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.push_pin_rounded,
                              size: 10, color: colors.primary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              a['ancla_tipo'] == 'servicio'
                                  ? 'Servicio'
                                  : 'Producto',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary),
                            ),
                          ),
                        ]),
                        Text(a['ancla_titulo'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary)),
                        if (a['ancla_precio'] != null)
                          Text(_precio(a['ancla_precio']),
                              style: TextStyle(
                                  fontSize: 11, color: colors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _burbuja(int i) {
    final m = _mensajes[i];
    final esBot = m['es_bot'] == true;
    final mio = !esBot && _miId != null && m['user_id'] == _miId;
    final anterior = i > 0 ? _mensajes[i - 1] : null;
    // Mensajes seguidos de la misma persona: el nombre y la foto solo en el
    // primero, como en cualquier chat.
    final mismoAutor = anterior != null &&
        anterior['user_id'] == m['user_id'] &&
        anterior['es_bot'] == m['es_bot'];
    final nombre = esBot
        ? 'OkVenta'
        : [m['nombre'], m['apellido']]
            .where((x) => x != null && '$x'.trim().isNotEmpty)
            .join(' ');

    final fondo = esBot
        ? colors.carbon
        : mio
            ? colors.primary
            : colors.surface;
    final colorTexto = (esBot || mio) ? Colors.white : colors.textPrimary;

    final contenido = Column(
      crossAxisAlignment:
          mio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!mismoAutor)
          GestureDetector(
            onTap: esBot ? null : () => _abrirPerfil(m, nombre),
            child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(nombre.isEmpty ? 'Usuario' : nombre,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: esBot ? colors.primary : colors.textSecondary)),
              if (esBot) ...[
                const SizedBox(width: 3),
                Icon(Icons.verified_rounded, size: 12, color: colors.primary),
              ],
            ]),
          ),
          ),
        Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mio ? 16 : 4),
              bottomRight: Radius.circular(mio ? 4 : 16),
            ),
            border: (esBot || mio)
                ? null
                : Border.all(color: colors.divider, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((m['texto'] ?? '').toString().isNotEmpty)
                _textoConMenciones(m['texto'].toString(), colorTexto),
              if (m['ancla_tipo'] != null) ...[
                if ((m['texto'] ?? '').toString().isNotEmpty)
                  const SizedBox(height: 6),
                _tarjetaAncla(m),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
          child: Text(_hora(m['created_at']),
              style: TextStyle(fontSize: 9, color: colors.grayMid)),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(top: mismoAutor ? 2 : 8),
      child: Row(
        mainAxisAlignment:
            mio ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mio) ...[
            _columnaAvatar(m, esBot, mismoAutor, nombre),
            const SizedBox(width: 6),
          ],
          Flexible(child: contenido),
          if (mio) ...[
            const SizedBox(width: 6),
            _columnaAvatar(m, esBot, mismoAutor, nombre),
          ],
        ],
      ),
    );
  }

  /// Foto del autor (solo en el primer mensaje de cada tanda). Tocarla
  /// abre su perfil, igual que tocar el nombre.
  Widget _columnaAvatar(
      Map<String, dynamic> m, bool esBot, bool mismoAutor, String nombre) {
    return SizedBox(
      width: 30,
      child: mismoAutor
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 16),
              child: esBot
                  ? _avatarBot()
                  : GestureDetector(
                      onTap: () => _abrirPerfil(m, nombre),
                      child: AvatarUsuario(
                          fotoUrl: m['foto_url'], nombre: nombre, tamano: 28),
                    ),
            ),
    );
  }

  void _abrirPerfil(Map<String, dynamic> m, String nombre) {
    final uid = (m['user_id'] as num?)?.toInt();
    if (uid == null) return;
    _foco.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilPublicoScreen(
            userId: uid, nombre: nombre.isEmpty ? 'Usuario' : nombre),
      ),
    );
  }

  Widget _avatarBot() {
    return Container(
      width: 28,
      height: 28,
      decoration:
          BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const Text('ok',
          style: TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  /// Resalta las @menciones (por ahora solo existe @okventa).
  Widget _textoConMenciones(String texto, Color color) {
    final re = RegExp(r'@\s?ok\s?venta', caseSensitive: false);
    final spans = <TextSpan>[];
    var i = 0;
    for (final m in re.allMatches(texto)) {
      if (m.start > i) spans.add(TextSpan(text: texto.substring(i, m.start)));
      spans.add(TextSpan(
          text: m.group(0),
          style: const TextStyle(fontWeight: FontWeight.w800)));
      i = m.end;
    }
    if (i < texto.length) spans.add(TextSpan(text: texto.substring(i)));
    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(fontSize: 14, height: 1.3, color: color),
    );
  }

  Widget _tarjetaAncla(Map<String, dynamic> m) {
    final esServicio = m['ancla_tipo'] == 'servicio';
    return GestureDetector(
      onTap: () => _abrirAncla(m['ancla_tipo'], (m['ancla_id'] as num?)?.toInt()),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.divider, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _miniatura(m['ancla_imagen'], 48, esServicio),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(esServicio ? '📌 Servicio' : '📌 Producto',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: colors.primary)),
                  Text(m['ancla_titulo'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary)),
                  if (m['ancla_precio'] != null)
                    Text(_precio(m['ancla_precio']),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.primary)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: colors.grayMid),
          ],
        ),
      ),
    );
  }

  Widget _barraEmojis() {
    return Container(
      color: colors.surface,
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _kEmojis.length,
        itemBuilder: (_, i) => InkWell(
          onTap: () => _insertar(_kEmojis[i]),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
                child: Text(_kEmojis[i], style: const TextStyle(fontSize: 24))),
          ),
        ),
      ),
    );
  }

  Widget _cajaTexto() {
    if (_miId == null) {
      return Container(
        color: colors.surface,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              widget.onPedirLogin?.call();
              await Future.delayed(const Duration(seconds: 1));
              _refrescarSesion();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
            ),
            child: const Text('Inicia sesión para conversar'),
          ),
        ),
      );
    }

    final puedeEnviar =
        _ctrl.text.trim().isNotEmpty || _anclaElegida != null;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_anclaElegida != null)
            Container(
              margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: colors.primary.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Row(children: [
                _miniatura(_anclaElegida!['imagen'], 34,
                    _anclaElegida!['tipo'] == 'servicio'),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('📌 ${_anclaElegida!['titulo'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _anclaElegida = null),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: colors.grayMid),
                ),
              ]),
            ),
          Row(
            children: [
              IconButton(
                onPressed: _elegirAncla,
                tooltip: 'Anclar lo que vendes',
                icon: Icon(Icons.push_pin_outlined,
                    size: 21, color: colors.grayMid),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => setState(() => _verEmojis = !_verEmojis),
                icon: Icon(
                    _verEmojis
                        ? Icons.keyboard_alt_outlined
                        : Icons.emoji_emotions_outlined,
                    size: 21,
                    color: _verEmojis ? colors.primary : colors.grayMid),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: colors.divider),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _foco,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 14, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Escribe a la comunidad…',
                      hintStyle:
                          TextStyle(fontSize: 14, color: colors.grayMid),
                      counterText: '',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: puedeEnviar ? _enviar : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: puedeEnviar ? colors.primary : colors.divider,
                    shape: BoxShape.circle,
                  ),
                  child: _enviando
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded,
                          size: 18, color: Colors.white),
                ),
              ),
              const SizedBox(width: 2),
            ],
          ),
        ],
      ),
    );
  }

  // ── Utilidades ──────────────────────────────────────────────────────────

  Widget _miniatura(dynamic url, double tam, bool esServicio) {
    final u = (url ?? '').toString();
    final fallback = Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
          esServicio ? Icons.handyman_outlined : Icons.shopping_bag_outlined,
          size: tam * 0.45,
          color: colors.grayMid),
    );
    if (u.isEmpty) return fallback;
    return NetImage(
      _url(u),
      width: tam,
      height: tam,
      borderRadius: BorderRadius.circular(8),
      errorWidget: fallback,
    );
  }

  static String _url(String u) =>
      u.startsWith('http') ? u : '${ApiService.baseUrl}$u';

  static String _precio(dynamic p) {
    final n = (p is num) ? p : num.tryParse('$p');
    if (n == null) return '';
    final s = n.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '\$$b';
  }

  /// El servidor guarda en UTC (CURRENT_TIMESTAMP de SQLite).
  static String _hora(dynamic ts) {
    if (ts == null) return '';
    final d = DateTime.tryParse('${ts.toString().replaceFirst(' ', 'T')}Z');
    if (d == null) return '';
    final l = d.toLocal();
    final hoy = DateTime.now();
    final hh = '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
    if (l.year == hoy.year && l.month == hoy.month && l.day == hoy.day) {
      return hh;
    }
    return '${l.day}/${l.month} $hh';
  }
}

/// Hoja para elegir qué anclar: mis productos y mis servicios.
class _SelectorAncla extends StatefulWidget {
  final int userId;
  const _SelectorAncla({required this.userId});

  @override
  State<_SelectorAncla> createState() => _SelectorAnclaState();
}

class _SelectorAnclaState extends State<_SelectorAncla> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    ApiService.obtenerAnclables(widget.userId).then((d) {
      if (mounted) setState(() => _data = d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pubs = List<Map<String, dynamic>>.from(_data?['publicaciones'] ?? []);
    final servs = List<Map<String, dynamic>>.from(_data?['servicios'] ?? []);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text('¿Qué quieres anclar?',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const SizedBox(height: 4),
              Text('Aparece como tarjeta en tu mensaje y arriba del chat.',
                  style: TextStyle(fontSize: 12, color: colors.grayMid)),
              const SizedBox(height: 10),
              if (_data == null)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Center(
                      child: CircularProgressIndicator(color: colors.primary)),
                )
              else if (pubs.isEmpty && servs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                        'Aún no tienes productos ni servicios publicados.\n'
                        'Usa "+ Publicar" en OkMarket u OkServicios.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.grayMid)),
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (pubs.isNotEmpty) _titulo('Mis productos'),
                      ...pubs.map(_fila),
                      if (servs.isNotEmpty) _titulo('Mis servicios'),
                      ...servs.map(_fila),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(t,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary)),
      );

  Widget _fila(Map<String, dynamic> a) {
    final img = (a['imagen'] ?? '').toString();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => Navigator.pop(context, a),
      leading: img.isEmpty
          ? Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(
                  a['tipo'] == 'servicio'
                      ? Icons.handyman_outlined
                      : Icons.shopping_bag_outlined,
                  color: colors.grayMid),
            )
          : NetImage(
              img.startsWith('http') ? img : '${ApiService.baseUrl}$img',
              width: 44,
              height: 44,
              borderRadius: BorderRadius.circular(8)),
      title: Text(a['titulo'] ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: colors.textPrimary)),
      subtitle: a['precio'] != null
          ? Text(_ComunidadScreenState._precio(a['precio']),
              style: TextStyle(fontSize: 12, color: colors.grayMid))
          : null,
      trailing: Icon(Icons.push_pin_outlined, size: 18, color: colors.primary),
    );
  }
}
