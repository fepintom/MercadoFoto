import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/contenido_oculto_service.dart';
import '../services/favoritos_service.dart';
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

  // ── @menciones y respuestas ──
  /// Menciones elegidas en el autocompletar: handle → id de usuario.
  final Map<String, int> _mencionesElegidas = {};
  List<Map<String, dynamic>> _sugerencias = [];
  Timer? _debounceMencion;
  Map<String, dynamic>? _respondiendoA;

  /// Lo que se dibuja: sin los mensajes ocultos ni los de bloqueados.
  List<Map<String, dynamic>> _vista = [];

  static final _reMencion =
      RegExp(r'@[0-9A-Za-zÁÉÍÓÚÜÑáéíóúüñ_]+');

  int get _ultimoId =>
      _mensajes.isEmpty ? 0 : (_mensajes.last['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_detectarMencion);
    ContenidoOcultoService.cargar().then((_) => _refrescar());
    ContenidoOcultoService.mensajes.addListener(_refrescar);
    ContenidoOcultoService.vendedores.addListener(_refrescar);
    _iniciar();
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  /// Si justo antes del cursor hay "@algo", busca usuarios para sugerir.
  void _detectarMencion() {
    final t = _ctrl.text;
    final sel = _ctrl.selection;
    final pos = sel.isValid ? sel.baseOffset : t.length;
    if (pos < 0 || pos > t.length) return;
    final m = RegExp(r'(^|\s)@([0-9A-Za-zÁÉÍÓÚÜÑáéíóúüñ_]{1,30})$')
        .firstMatch(t.substring(0, pos));
    _debounceMencion?.cancel();
    if (m == null) {
      if (_sugerencias.isNotEmpty) setState(() => _sugerencias = []);
      return;
    }
    final q = m.group(2)!;
    _debounceMencion = Timer(const Duration(milliseconds: 250), () async {
      List<Map<String, dynamic>> res = [];
      try {
        res = await ApiService.buscarUsuariosComunidad(q, excluir: _miId);
      } catch (_) {}
      if (!mounted) return;
      final bot = 'okventa'.startsWith(q.toLowerCase())
          ? [<String, dynamic>{'bot': true, 'handle': 'okventa', 'nombre': 'OkVenta (bot)'}]
          : <Map<String, dynamic>>[];
      setState(() => _sugerencias = [...bot, ...res]);
    });
  }

  void _elegirMencion(Map<String, dynamic> u) {
    final t = _ctrl.text;
    final pos = _ctrl.selection.isValid ? _ctrl.selection.baseOffset : t.length;
    final antes = t.substring(0, pos);
    final despues = t.substring(pos);
    final i = antes.lastIndexOf('@');
    if (i < 0) return;
    final handle = (u['handle'] ?? '').toString();
    final nuevo = '${antes.substring(0, i)}@$handle ';
    _ctrl.value = TextEditingValue(
      text: nuevo + despues,
      selection: TextSelection.collapsed(offset: nuevo.length),
    );
    final id = (u['id'] as num?)?.toInt();
    if (u['bot'] != true && id != null) _mencionesElegidas[handle] = id;
    setState(() => _sugerencias = []);
  }

  /// Escribe "@Handle " en la caja (desde el menú de un mensaje).
  void _mencionar(Map<String, dynamic> m) {
    final handle = (m['handle'] ?? '').toString();
    final id = (m['user_id'] as num?)?.toInt();
    if (handle.isEmpty || id == null) return;
    _mencionesElegidas[handle] = id;
    final t = _ctrl.text;
    final sep = t.isEmpty || t.endsWith(' ') ? '' : ' ';
    _ctrl.value = TextEditingValue(
      text: '$t$sep@$handle ',
      selection: TextSelection.collapsed(offset: '$t$sep@$handle '.length),
    );
    _foco.requestFocus();
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
    _debounceMencion?.cancel();
    ContenidoOcultoService.mensajes.removeListener(_refrescar);
    ContenidoOcultoService.vendedores.removeListener(_refrescar);
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
      final menciones = _mencionesElegidas.entries
          .where((e) => texto.contains('@${e.key}'))
          .map((e) => e.value)
          .toSet()
          .toList();
      final msg = await ApiService.enviarMensajeComunidad(
        userId: _miId!,
        texto: texto,
        anclaTipo: _anclaElegida?['tipo'],
        anclaId: (_anclaElegida?['id'] as num?)?.toInt(),
        menciones: menciones,
        respondeA: (_respondiendoA?['id'] as num?)?.toInt(),
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
        _respondiendoA = null;
        _mencionesElegidas.clear();
        _sugerencias = [];
      });
      _alFinal();
      // Si le habló al bot (o sigue una conversación con él), la respuesta
      // llega en unos segundos: se pide antes del siguiente ciclo.
      Future.delayed(const Duration(milliseconds: 1500), _traerNuevos);
      Future.delayed(const Duration(milliseconds: 4000), _traerNuevos);
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
                    child: Builder(builder: (_) {
                      _vista = _mensajes
                          .where((m) => !ContenidoOcultoService.mensajeOculto(m))
                          .toList();
                      return ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        itemCount: _vista.length,
                        itemBuilder: (_, i) => _burbuja(i),
                      );
                    }),
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
    final m = _vista[i];
    final esBot = m['es_bot'] == true;
    final mio = !esBot && _miId != null && m['user_id'] == _miId;
    final anterior = i > 0 ? _vista[i - 1] : null;
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
              if (m['responde_a'] != null) _cita(m, colorTexto),
              if ((m['texto'] ?? '').toString().isNotEmpty)
                _textoConMenciones(m['texto'].toString(), colorTexto,
                    (m['menciones'] as List?) ?? const []),
              if (m['ancla_tipo'] != null) ...[
                if ((m['texto'] ?? '').toString().isNotEmpty)
                  const SizedBox(height: 6),
                _tarjetaAncla(m),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 1, left: 4, right: 0),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_hora(m['created_at']),
                style: TextStyle(fontSize: 9, color: colors.textPrimary)),
            // Menú del mensaje: guardar, responder, denunciar, ocultar...
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _menuMensaje(m),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Icon(Icons.more_horiz_rounded,
                    size: 16, color: colors.textPrimary),
              ),
            ),
          ]),
        ),
      ],
    );

    return GestureDetector(
      onLongPress: () => _menuMensaje(m),
      child: Padding(
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

  /// Resalta las @menciones. Las de usuarios reales (las que el servidor
  /// confirmó) se pueden tocar y abren su perfil.
  Widget _textoConMenciones(String texto, Color color, List menciones) {
    final porHandle = <String, int>{
      for (final x in menciones)
        if (x is Map && x['handle'] != null && x['id'] is num)
          x['handle'].toString().toLowerCase(): (x['id'] as num).toInt(),
    };
    final estilo = TextStyle(fontSize: 14, height: 1.3, color: color);
    final spans = <InlineSpan>[];
    var i = 0;
    for (final m in _reMencion.allMatches(texto)) {
      if (m.start > i) spans.add(TextSpan(text: texto.substring(i, m.start)));
      final token = m.group(0)!;
      final handle = token.substring(1).toLowerCase();
      final uid = porHandle[handle];
      final esBot = handle == 'okventa';
      final resaltado = TextStyle(
          fontWeight: FontWeight.w800,
          color: color,
          decoration: uid != null ? TextDecoration.underline : null,
          decorationColor: color);
      if (uid != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => _abrirPerfil({'user_id': uid}, token.substring(1)),
            child: Text(token, style: estilo.merge(resaltado)),
          ),
        ));
      } else if (esBot || porHandle.isEmpty) {
        spans.add(TextSpan(text: token, style: resaltado));
      } else {
        spans.add(TextSpan(text: token));
      }
      i = m.end;
    }
    if (i < texto.length) spans.add(TextSpan(text: texto.substring(i)));
    return Text.rich(TextSpan(children: spans), style: estilo);
  }

  /// Cita del mensaje al que se responde (una línea, arriba del texto).
  Widget _cita(Map<String, dynamic> m, Color color) {
    final orig = _mensajes.firstWhere((x) => x['id'] == m['responde_a'],
        orElse: () => const <String, dynamic>{});
    if (orig.isEmpty) return const SizedBox.shrink();
    final quien = orig['es_bot'] == true
        ? 'OkVenta'
        : (orig['nombre'] ?? 'Usuario').toString().split(' ').first;
    final texto = (orig['texto'] ?? '').toString().isNotEmpty
        ? orig['texto'].toString()
        : (orig['ancla_titulo'] ?? '📌').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.fromLTRB(7, 4, 7, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 2.5)),
      ),
      child: Text('$quien: $texto',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: color)),
    );
  }

  // ── Menú ⋯ de cada mensaje ───────────────────────────────────────────────

  Future<void> _menuMensaje(Map<String, dynamic> m) async {
    final esBot = m['es_bot'] == true;
    final autorId = (m['user_id'] as num?)?.toInt();
    final mio = !esBot && _miId != null && autorId == _miId;
    final id = (m['id'] as num?)?.toInt();
    final nombre = esBot
        ? 'OkVenta'
        : (m['nombre'] ?? 'Usuario').toString().split(' ').first;
    final anclaTipo = m['ancla_tipo']?.toString();
    final anclaId = (m['ancla_id'] as num?)?.toInt();
    if (id == null) return;

    void aviso(String t, {SnackBarAction? accion}) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
            content: Text(t),
            backgroundColor: colors.carbon,
            behavior: SnackBarBehavior.floating,
            action: accion));
    }

    Widget opcion(IconData i, String t, VoidCallback f, {bool rojo = false}) =>
        ListTile(
          dense: true,
          leading: Icon(i, color: rojo ? colors.primary : colors.textPrimary),
          title: Text(t,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: rojo ? colors.primary : colors.textPrimary)),
          onTap: f,
        );

    await showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        void cerrarY(VoidCallback f) {
          Navigator.pop(ctx);
          f();
        }

        final guardado = anclaTipo == 'servicio'
            ? FavoritosService.esServicio(anclaId)
            : FavoritosService.es(anclaId);
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 6),
            if (_miId != null)
              opcion(Icons.reply_rounded, 'Responder',
                  () => cerrarY(() {
                        setState(() => _respondiendoA = m);
                        _foco.requestFocus();
                      })),
            if (!mio && !esBot && _miId != null)
              opcion(Icons.alternate_email_rounded, 'Mencionar a $nombre',
                  () => cerrarY(() => _mencionar(m))),
            if (!mio && !esBot && autorId != null)
              opcion(Icons.person_outline_rounded, 'Ver perfil de $nombre',
                  () => cerrarY(() => _abrirPerfil(m, nombre))),
            if (anclaTipo != null && anclaId != null && !mio)
              opcion(
                  guardado
                      ? Icons.bookmark_remove_outlined
                      : Icons.bookmark_add_outlined,
                  guardado ? 'Quitar de guardados' : 'Guardar publicación',
                  () => cerrarY(() async {
                        final uid = _miId;
                        if (uid == null) {
                          widget.onPedirLogin?.call();
                          return;
                        }
                        final ahora = anclaTipo == 'servicio'
                            ? await FavoritosService.alternarServicio(uid, anclaId)
                            : await FavoritosService.alternar(uid, anclaId);
                        if (mounted) {
                          aviso(ahora ? 'Guardada en favoritos' : 'Quitada de favoritos');
                        }
                      })),
            if (anclaTipo != null && anclaId != null && !mio)
              opcion(Icons.visibility_off_outlined, 'No me interesa',
                  () => cerrarY(() {
                        if (anclaTipo == 'servicio') {
                          ContenidoOcultoService.ocultarServicio(anclaId);
                        } else {
                          ContenidoOcultoService.ocultarPublicacion(anclaId);
                        }
                        ContenidoOcultoService.ocultarMensaje(id);
                        aviso('No volverás a ver esta publicación');
                      })),
            opcion(Icons.delete_outline_rounded, 'Eliminar para mí',
                () => cerrarY(() {
                      ContenidoOcultoService.ocultarMensaje(id);
                      aviso('Mensaje eliminado para ti',
                          accion: SnackBarAction(
                              label: 'Deshacer',
                              textColor: Colors.white,
                              onPressed: () =>
                                  ContenidoOcultoService.mostrarMensaje(id)));
                    })),
            if (mio)
              opcion(Icons.delete_forever_outlined, 'Eliminar para todos',
                  () => cerrarY(() async {
                        final ok = await ApiService.borrarMensajeComunidad(id, _miId!);
                        if (!mounted) return;
                        if (ok) {
                          setState(() => _mensajes.removeWhere((x) => x['id'] == id));
                        }
                        aviso(ok ? 'Mensaje eliminado' : 'No se pudo eliminar');
                      }),
                  rojo: true),
            if (!mio && !esBot)
              opcion(Icons.flag_outlined, 'Denunciar mensaje',
                  () => cerrarY(() => _denunciar(m)), rojo: true),
            if (!mio && !esBot && autorId != null)
              opcion(Icons.block_rounded, 'Bloquear a $nombre',
                  () => cerrarY(() {
                        ContenidoOcultoService.bloquearVendedor(autorId);
                        aviso('Bloqueaste a $nombre: no verás sus mensajes ni publicaciones',
                            accion: SnackBarAction(
                                label: 'Deshacer',
                                textColor: Colors.white,
                                onPressed: () =>
                                    ContenidoOcultoService.desbloquearVendedor(autorId)));
                      }),
                  rojo: true),
            const SizedBox(height: 6),
          ]),
        );
      },
    );
  }

  Future<void> _denunciar(Map<String, dynamic> m) async {
    final uid = _miId;
    if (uid == null) {
      widget.onPedirLogin?.call();
      return;
    }
    const motivos = [
      'Spam o publicidad engañosa',
      'Acoso o insultos',
      'Estafa o fraude',
      'Contenido inapropiado',
      'Otro motivo',
    ];
    final motivo = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text('¿Por qué lo denuncias?',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary)),
          for (final x in motivos)
            ListTile(
              title: Text(x, style: TextStyle(color: colors.textPrimary)),
              onTap: () => Navigator.pop(ctx, x),
            ),
        ]),
      ),
    );
    if (motivo == null || !mounted) return;
    try {
      await ApiService.crearTicketAyuda(
        userId: uid,
        tipo: 'reporte',
        numeroReferencia: 'Comunidad mensaje #${m['id']}',
        detalle: 'Denuncia de mensaje de ${m['nombre'] ?? 'usuario'} '
            '(id ${m['user_id']}): "${m['texto'] ?? ''}" — $motivo',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Gracias. El equipo de OkVenta lo va a revisar.'),
        backgroundColor: colors.carbon,
      ));
    } catch (_) {}
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
          // Sugerencias de @menciones mientras se escribe.
          if (_sugerencias.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                itemCount: _sugerencias.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final u = _sugerencias[i];
                  final esBot = u['bot'] == true;
                  final nombre = esBot
                      ? 'OkVenta'
                      : [u['nombre'], u['apellido']]
                          .where((x) => x != null && '$x'.trim().isNotEmpty)
                          .join(' ');
                  return GestureDetector(
                    onTap: () => _elegirMencion(u),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(4, 2, 10, 2),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.divider),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        esBot
                            ? _avatarBot()
                            : AvatarUsuario(
                                fotoUrl: u['foto_url'], nombre: nombre, tamano: 26),
                        const SizedBox(width: 6),
                        Text('@${u['handle']}',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          // Respondiendo a un mensaje.
          if (_respondiendoA != null)
            Container(
              margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border(left: BorderSide(color: colors.primary, width: 3)),
              ),
              child: Row(children: [
                Icon(Icons.reply_rounded, size: 16, color: colors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      'Respondiendo a ${_respondiendoA!['es_bot'] == true ? 'OkVenta' : (_respondiendoA!['nombre'] ?? 'Usuario').toString().split(' ').first}: '
                      '${(_respondiendoA!['texto'] ?? _respondiendoA!['ancla_titulo'] ?? '').toString()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: colors.textPrimary)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _respondiendoA = null),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: colors.textPrimary),
                ),
              ]),
            ),
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
                      hintText: 'Escribe… usa @ para mencionar',
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
          esServicio ? Icons.handyman_outlined : Icons.shopping_cart_outlined,
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
                      : Icons.shopping_cart_outlined,
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
