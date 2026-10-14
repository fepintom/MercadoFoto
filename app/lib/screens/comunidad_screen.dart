import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/contenido_oculto_service.dart';
import '../services/favoritos_service.dart';
import '../services/session_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_usuario.dart';
import '../widgets/net_image.dart';
import '../widgets/fondo_pixel_okventin.dart';
import '../widgets/mas_vendidos_franja.dart';
import '../widgets/compartir_ubicacion.dart';
import '../widgets/mapa_mini.dart';
import 'chat_privado_screen.dart';
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
  /// Sube cada vez que se vuelve a la pestaña: recarga "Lo más visto".
  int _versionTop = 0;
  static const _kIntervalo = Duration(seconds: 4);
  static const _kEmojis = [
    '😀', '😂', '😍', '🥳', '😎', '🤔', '😅', '😢', '😡', '👍', '👏', '🙏',
    '🙌', '💪', '🔥', '❤️', '💯', '🎉', '👋', '✅', '💰', '🛒', '📦', '🛠️',
  ];

  final _mensajes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _anclados = [];

  /// Comentarios que el usuario fijó (solo en su teléfono).
  List<Map<String, dynamic>> _fijados = [];
  static const _kFijados = 'comunidad_fijados_v1';

  /// "🔥 TOP" a la vista (el ojo lo esconde; se recuerda) y Fijados
  /// desplegado o no (parte cerrado: el chat es lo importante).
  bool _verTop = true;
  bool _fijadosAbiertos = false;
  static const _kVerTop = 'comunidad_ver_top';

  /// Buscar en el chat, como Ctrl+F: no esconde mensajes, resalta lo que
  /// coincide y se recorre con ▲▼ ("3/12"). Cada palabra confirmada queda
  /// como pastilla a la derecha del campo (p. ej. "@fernando" + "parrilla").
  bool _buscando = false;
  final List<String> _terminos = [];
  List<_Coincidencia> _hits = const [];
  int _hitActual = -1;
  final Map<int, GlobalKey> _llaves = {};
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
    _foco.addListener(_cambioFoco);
    _ctrl.addListener(_detectarMencion);
    ContenidoOcultoService.cargar().then((_) => _refrescar());
    ContenidoOcultoService.mensajes.addListener(_refrescar);
    ContenidoOcultoService.vendedores.addListener(_refrescar);
    _cargarFijados();
    _iniciar();
  }

  // ── Fijados ────────────────────────────────────────────────────────────
  Future<void> _alternarTop() async {
    setState(() => _verTop = !_verTop);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kVerTop, _verTop);
    } catch (_) {}
  }

  Future<void> _cargarFijados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ver = prefs.getBool(_kVerTop);
      if (ver != null && mounted) setState(() => _verTop = ver);
      final raw = prefs.getString(_kFijados);
      if (raw == null) return;
      final l = (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _fijados = l);
    } catch (_) {}
  }

  bool _estaFijado(int? id) =>
      id != null && _fijados.any((f) => f['id'] == id);

  Future<void> _alternarFijado(Map<String, dynamic> m) async {
    final id = (m['id'] as num?)?.toInt();
    if (id == null) return;
    setState(() {
      if (_estaFijado(id)) {
        _fijados = _fijados.where((f) => f['id'] != id).toList();
      } else {
        _fijados = [
          {
            'id': id,
            'nombre': m['es_bot'] == true ? 'OkVenta' : (m['nombre'] ?? 'Usuario'),
            'foto_url': m['foto_url'],
            'texto': (m['texto'] ?? m['ancla_titulo'] ?? '').toString(),
            'es_bot': m['es_bot'] == true,
          },
          ..._fijados,
        ].take(20).toList();
      }
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFijados, jsonEncode(_fijados));
    } catch (_) {}
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

  void _cambioFoco() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ComunidadScreen old) {
    super.didUpdateWidget(old);
    if (widget.activa != old.activa) {
      if (widget.activa) {
        _versionTop++;
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
    _scrollChips.dispose();
    _foco.removeListener(_cambioFoco);
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

  int _vueltas = 0;

  Future<void> _traerNuevos() async {
    // Cada 4 vueltas revisa si taparon algún mensaje ya cargado.
    if (++_vueltas % 4 == 0) _revisarCensurados();
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

  /// Deja un mensaje como censurado (sin su contenido).
  void _tapar(Map<String, dynamic> m) {
    m['censurado'] = true;
    m['texto'] = '';
    m['ubicacion'] = null;
    m['menciones'] = const [];
    m['ancla_tipo'] = null;
  }

  /// Tapa los mensajes que alguien denunció mientras estaban en pantalla.
  Future<void> _revisarCensurados() async {
    try {
      final ids = await ApiService.obtenerCensuradosComunidad();
      if (!mounted || ids.isEmpty) return;
      var cambio = false;
      for (final m in _mensajes) {
        final id = (m['id'] as num?)?.toInt();
        if (id != null && ids.contains(id) && m['censurado'] != true) {
          _tapar(m);
          cambio = true;
        }
      }
      if (cambio) setState(() {});
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
    // Escribiendo: se esconden las franjas de arriba para darle espacio al
    // chat (el teclado ya ocupa media pantalla).
    final escribiendo = _foco.hasFocus;
    final hayFijados = _fijados.isNotEmpty || _anclados.isNotEmpty;
    return Container(
      color: colors.background,
      child: Column(
        children: [
          // Sin título "Comunidad" (ya lo dice el menú): todo el alto posible
          // para el chat. Una barra fina con 🔥 TOP (ojo para esconder) y
          // 📌 Fijados (desplegable).
          if (!escribiendo) _barraSuperior(hayFijados),
          if (!escribiendo && _verTop)
            MasVendidosFranja(version: _versionTop, compacta: true),
          if (!escribiendo && hayFijados && _fijadosAbiertos)
            _franjaFijados(),
          Expanded(
            child: _cargando
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary))
                : GestureDetector(
                    onTap: () {
                      _foco.unfocus();
                      if (_verEmojis) setState(() => _verEmojis = false);
                    },
                    child: Stack(
                      children: [
                        // Okventín caminando en pixel art, detrás del chat.
                        Positioned.fill(
                          child: FondoPixelOkventin(
                              activo: widget.activa,
                              opacidad: ThemeService.isDarkMode ? 0.45 : 0.6),
                        ),
                        Builder(builder: (_) {
                          _vista = _mensajes
                              .where((m) =>
                                  !ContenidoOcultoService.mensajeOculto(m))
                              .toList();
                          _hits = _calcularHits();
                          if (_hitActual >= _hits.length) {
                            _hitActual = _hits.length - 1;
                          }
                          return ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                            itemCount: _vista.length,
                            itemBuilder: (_, i) => _burbuja(i),
                          );
                        }),
                        // Contador x/n con ▲▼ (como Ctrl+F), flotando.
                        if (_buscando)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _contadorFlotante(),
                          ),
                      ],
                    ),
                  ),
          ),
          if (_verEmojis) _barraEmojis(),
          _cajaTexto(),
        ],
      ),
    );
  }

  final _scrollChips = ScrollController();

  /// Fila de pastillas como la maqueta:
  ///   [🔥 Lo más buscado] [📌 Fijados] [👤 @fernando ⊗] [🔍] ›
  /// Tocar "Lo más buscado" o "Fijados" muestra/esconde su franja.
  Widget _barraSuperior(bool hayFijados) {
    Widget chip({
      required IconData icono,
      required String texto,
      required bool activo,
      VoidCallback? onTap,
      VoidCallback? onQuitar,
      GlobalKey? llave,
    }) {
      return GestureDetector(
        key: llave,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 38,
          padding: EdgeInsets.fromLTRB(12, 0, onQuitar != null ? 6 : 14, 0),
          decoration: BoxDecoration(
            color: activo
                ? colors.primary.withValues(alpha: 0.12)
                : colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: activo
                    ? colors.primary.withValues(alpha: 0.5)
                    : colors.divider,
                width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icono, size: 19, color: colors.primary),
            const SizedBox(width: 6),
            Text(texto,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
                    color: activo ? colors.primary : colors.textPrimary)),
            if (onQuitar != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onQuitar,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                      color: colors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: Colors.white),
                ),
              ),
            ],
          ]),
        ),
      );
    }

    final llaveLupa = GlobalKey();
    return Container(
      color: colors.surface,
      height: 52,
      child: Row(children: [
        Expanded(
          child: ListView(
            controller: _scrollChips,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
            children: [
              chip(
                  icono: Icons.local_fire_department_rounded,
                  texto: 'Lo más buscado',
                  activo: _verTop,
                  onTap: _alternarTop),
              if (hayFijados) ...[
                const SizedBox(width: 8),
                chip(
                    icono: Icons.push_pin_rounded,
                    texto: 'Fijados',
                    activo: _fijadosAbiertos,
                    onTap: () =>
                        setState(() => _fijadosAbiertos = !_fijadosAbiertos)),
              ],
              for (final t in _terminos) ...[
                const SizedBox(width: 8),
                chip(
                    icono: t.startsWith('@')
                        ? Icons.person_outline_rounded
                        : Icons.search_rounded,
                    texto: t,
                    activo: false,
                    onTap: () => _irAlUltimoHit(),
                    onQuitar: () => setState(() {
                          _terminos.remove(t);
                          _buscando = _terminos.isNotEmpty;
                          _hitActual = -1;
                        })),
              ],
              const SizedBox(width: 8),
              Builder(
                builder: (ctx) => chip(
                    llave: llaveLupa,
                    icono: Icons.search_rounded,
                    texto: _terminos.isEmpty ? '@' : '+',
                    activo: false,
                    onTap: () => _abrirNubeBusqueda(ctx)),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            if (!_scrollChips.hasClients) return;
            final p = _scrollChips.position;
            _scrollChips.animateTo(
                (p.pixels + 160).clamp(0.0, p.maxScrollExtent),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 8, 0),
            child: Icon(Icons.chevron_right_rounded,
                size: 26, color: colors.textPrimary),
          ),
        ),
      ]),
    );
  }

  /// Nube flotante para buscar / filtrar por @usuario: sale desde la lupa
  /// (como los avisos de OkMarket), con sugerencias de personas al
  /// escribir "@".
  Future<void> _abrirNubeBusqueda(BuildContext ancla) async {
    final box = ancla.findRenderObject() as RenderBox?;
    final pantalla = MediaQuery.of(context).size;
    final pos = box?.localToGlobal(Offset.zero) ??
        Offset(pantalla.width / 2, 120);
    final tam = box?.size ?? const Size(40, 38);
    final ancho = pantalla.width - 24 < 320 ? pantalla.width - 24 : 320.0;
    final left = (pos.dx + tam.width / 2 - ancho / 2)
        .clamp(12.0, pantalla.width - ancho - 12);
    final top = pos.dy + tam.height + 6;
    final flechaX = (pos.dx + tam.width / 2 - left).clamp(18.0, ancho - 18);

    final t = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Buscar',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dctx, _, __) => Stack(children: [
        Positioned(
          left: left,
          top: top,
          width: ancho,
          child: _NubeBusqueda(flechaX: flechaX, miId: _miId),
        ),
      ]),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          alignment: Alignment((flechaX / ancho) * 2 - 1, -1),
          child: child,
        ),
      ),
    );
    final termino = (t ?? '').trim();
    if (termino.isEmpty || !mounted) return;
    _agregarTermino(termino);
  }

  Widget _contadorFlotante() {
    final total = _hits.length;
    Widget flecha(IconData i, int paso) => GestureDetector(
          onTap: total == 0 ? null : () => _moverHit(paso),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(i,
                size: 22,
                color: total == 0 ? Colors.white38 : Colors.white),
          ),
        );
    return Material(
      color: const Color(0xE61C1C1E),
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
              total == 0
                  ? '0/0'
                  : '${_hitActual < 0 ? total : _hitActual + 1}/$total',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(width: 4),
          flecha(Icons.keyboard_arrow_up_rounded, -1),
          flecha(Icons.keyboard_arrow_down_rounded, 1),
          GestureDetector(
            onTap: _cerrarBusqueda,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 18, color: Colors.white70),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Buscar en el chat (Ctrl+F) ─────────────────────────────────────────

  /// Minúsculas y sin tildes, letra por letra (mismo largo que el original,
  /// así las posiciones sirven para resaltar).
  static String _norm(String t) {
    const de = 'áàäâéèëêíìïîóòöôúùüûñÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑ';
    const a = 'aaaaeeeeiiiioooouuuunaaaaeeeeiiiioooouuuun';
    final b = StringBuffer();
    for (final ch in t.split('')) {
      final i = de.indexOf(ch);
      b.write(i >= 0 ? a[i] : ch.toLowerCase());
    }
    return b.toString();
  }

  List<String> get _terminosActivos =>
      _terminos.map(_norm).where((t) => t.isNotEmpty).toList();

  /// Todas las apariciones de los términos, en orden del chat.
  List<_Coincidencia> _calcularHits() {
    if (!_buscando) return const [];
    final ts = _terminosActivos;
    if (ts.isEmpty) return const [];
    final out = <_Coincidencia>[];
    for (final m in _vista) {
      final id = (m['id'] as num?)?.toInt();
      if (id == null) continue;
      for (final r in _rangos(_norm((m['texto'] ?? '').toString()), ts)) {
        out.add(_Coincidencia(id, r.start));
      }
    }
    return out;
  }

  /// Rangos [inicio, fin) donde aparece algún término (sin superponerse).
  static List<TextRange> _rangos(String textoNorm, List<String> ts) {
    final r = <TextRange>[];
    for (final t in ts) {
      var i = textoNorm.indexOf(t);
      while (i >= 0) {
        r.add(TextRange(start: i, end: i + t.length));
        i = textoNorm.indexOf(t, i + t.length);
      }
    }
    r.sort((x, y) => x.start.compareTo(y.start));
    final limpio = <TextRange>[];
    for (final x in r) {
      if (limpio.isNotEmpty && x.start < limpio.last.end) continue;
      limpio.add(x);
    }
    return limpio;
  }

  void _agregarTermino(String t) {
    if (t.isEmpty) return;
    setState(() {
      if (!_terminos.contains(t)) _terminos.add(t);
      _buscando = true;
      _hitActual = -1;
    });
    _irAlUltimoHit();
  }

  void _irAlUltimoHit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hits.isEmpty) return;
      setState(() => _hitActual = _hits.length - 1);
      _irAHit();
    });
  }

  void _moverHit(int paso) {
    if (_hits.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _hitActual = ((_hitActual < 0 ? _hits.length : _hitActual) + paso) %
          _hits.length;
    });
    _irAHit();
  }

  /// Lleva el chat hasta el mensaje de la coincidencia actual.
  void _irAHit() {
    if (_hitActual < 0 || _hitActual >= _hits.length) return;
    final id = _hits[_hitActual].mensajeId;
    final idx = _vista.indexWhere((m) => m['id'] == id);
    if (idx < 0) return;
    final llave = _llaves[id];
    if (llave?.currentContext != null) {
      Scrollable.ensureVisible(llave!.currentContext!,
          alignment: 0.4, duration: const Duration(milliseconds: 250));
      return;
    }
    // No está construido: se salta a la zona aproximada y luego se ajusta.
    if (_scroll.hasClients && _vista.length > 1) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent * idx / (_vista.length - 1));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _llaves[id]?.currentContext;
      if (c != null) {
        Scrollable.ensureVisible(c,
            alignment: 0.4, duration: const Duration(milliseconds: 200));
      }
    });
  }

  void _cerrarBusqueda() => setState(() {
        _buscando = false;
        _terminos.clear();
        _hitActual = -1;
      });

  /// Texto con las coincidencias de la búsqueda resaltadas (amarillo; la
  /// actual en naranjo). [idMsg] y [desplaz] ubican cada trozo en el
  /// mensaje para saber cuál es la coincidencia actual.
  List<InlineSpan> _resaltar(String trozo, int? idMsg, int desplaz,
      {TextStyle? estilo}) {
    final ts = _buscando ? _terminosActivos : const <String>[];
    if (ts.isEmpty || idMsg == null) {
      return [TextSpan(text: trozo, style: estilo)];
    }
    final actual = (_hitActual >= 0 && _hitActual < _hits.length)
        ? _hits[_hitActual]
        : null;
    final out = <InlineSpan>[];
    var i = 0;
    for (final r in _rangos(_norm(trozo), ts)) {
      if (r.start > i) {
        out.add(TextSpan(text: trozo.substring(i, r.start), style: estilo));
      }
      final esActual = actual != null &&
          actual.mensajeId == idMsg &&
          actual.inicio == desplaz + r.start;
      out.add(TextSpan(
        text: trozo.substring(r.start, r.end),
        style: (estilo ?? const TextStyle()).copyWith(
          backgroundColor:
              esActual ? const Color(0xFFFF9F0A) : const Color(0xFFFFE08A),
          color: const Color(0xFF1C1C1E),
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFF1C1C1E),
        ),
      ));
      i = r.end;
    }
    if (i < trozo.length) {
      out.add(TextSpan(text: trozo.substring(i), style: estilo));
    }
    return out;
  }

  // ── Fijados: comentarios fijados + lo que la gente ancló ───────────────
  List<Map<String, dynamic>> get _itemsFijados => [
        for (final f in _fijados) {...f, '_tipo': 'comentario'},
        for (final a in _anclados) {...a, '_tipo': 'ancla'},
      ];

  Widget _franjaFijados() {
    final items = _itemsFijados;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(12, 0, 0, 8),
      child: SizedBox(
        height: 66,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 12),
          itemCount: items.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            if (i == items.length) {
              return GestureDetector(
                onTap: _verTodosFijados,
                child: Container(
                  width: 72,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.divider, width: 0.6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_rounded, color: colors.primary),
                      Text('Ver todos',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary)),
                    ],
                  ),
                ),
              );
            }
            return SizedBox(
                width: items[i]['_tipo'] == 'comentario' ? 210 : 180,
                child: _tarjetaFijado(items[i]));
          },
        ),
      ),
    );
  }

  void _abrirFijado(Map<String, dynamic> f) {
    if (f['_tipo'] == 'ancla') {
      _abrirAncla(f['ancla_tipo'], (f['ancla_id'] as num?)?.toInt());
      return;
    }
    // Comentario: se busca en el chat y se lleva hasta él.
    final i = _vista.indexWhere((m) => m['id'] == f['id']);
    if (i >= 0 && _scroll.hasClients) {
      final pos = (_scroll.position.maxScrollExtent * i /
              (_vista.length - 1).clamp(1, 1 << 30))
          .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(pos,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  Widget _tarjetaFijado(Map<String, dynamic> f) {
    final comentario = f['_tipo'] == 'comentario';
    return GestureDetector(
      onTap: () => _abrirFijado(f),
      onLongPress: comentario ? () => _alternarFijado(f) : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider, width: 0.6),
        ),
        child: Row(children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.push_pin_rounded, size: 14, color: colors.primary),
              if (comentario)
                f['es_bot'] == true
                    ? _avatarBot()
                    : AvatarUsuario(
                        fotoUrl: f['foto_url']?.toString(),
                        nombre: (f['nombre'] ?? 'U').toString(),
                        tamano: 26),
            ],
          ),
          const SizedBox(width: 6),
          if (!comentario) ...[
            _miniatura(f['ancla_imagen'], 46, f['ancla_tipo'] == 'servicio'),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: comentario
                  ? [
                      Row(children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 13, color: colors.textPrimary),
                        const SizedBox(width: 4),
                        Text('Comentario',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary)),
                      ]),
                      Text((f['nombre'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5, color: colors.grayMid)),
                      Text((f['texto'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: colors.textPrimary)),
                    ]
                  : [
                      Text(
                          f['ancla_tipo'] == 'servicio'
                              ? 'Servicio'
                              : 'Producto',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary)),
                      Text((f['ancla_titulo'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: colors.textPrimary)),
                      if (f['ancla_precio'] != null)
                        Text(_precio(f['ancla_precio']),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: colors.primary)),
                    ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: colors.textPrimary),
        ]),
      ),
    );
  }

  void _verTodosFijados() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7),
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
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.push_pin_rounded, color: colors.primary),
                  const SizedBox(width: 6),
                  Text('Fijados',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary)),
                ]),
                const SizedBox(height: 4),
                Text(
                    'Fija un comentario desde su menú ⋯. Mantén presionado '
                    'un comentario fijado para quitarlo.',
                    style: TextStyle(fontSize: 12, color: colors.textPrimary)),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _itemsFijados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final f = _itemsFijados[i];
                      return SizedBox(
                        height: 66,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _abrirFijado(f);
                          },
                          child: AbsorbPointer(child: _tarjetaFijado(f)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
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

    // Colores como WhatsApp: cada persona con su color de nombre; el
    // nombre va DENTRO de la burbuja, del mismo tamaño que el texto, y la
    // hora abajo a la derecha. En modo oscuro las burbujas son gris
    // claro-oscuro (se separan del fondo negro) y las mías un rojo apagado.
    final oscuro = ThemeService.isDarkMode;
    // Como la maqueta: los demás en blanco (gris en modo oscuro), OkVenta
    // en negro, lo mío en verde suave; nombres de color.
    final fondo = esBot
        ? (oscuro ? const Color(0xFF17181B) : const Color(0xFF1F1F22))
        : mio
            ? (oscuro ? const Color(0xFF1E4A2B) : const Color(0xFFDDF6D2))
            : (oscuro ? const Color(0xFF25272C) : Colors.white);
    final borde = esBot
        ? (oscuro ? const Color(0xFF34363C) : null)
        : mio
            ? (oscuro ? const Color(0xFF2E7A45) : const Color(0xFFC3E8B5))
            : (oscuro ? const Color(0xFF3A3D44) : const Color(0xFFE6E6EA));
    final colorTexto = esBot || oscuro ? Colors.white : const Color(0xFF1C1C1E);
    final colorHora = esBot || oscuro
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1C1C1E).withValues(alpha: 0.5);
    final colorNombre = esBot
        ? (oscuro ? const Color(0xFFFF5A52) : const Color(0xFFFF4D44))
        : _colorDeUsuario((m['user_id'] as num?)?.toInt() ?? 0);

    final censurado = m['censurado'] == true;
    // Burbujas compactas (como WhatsApp): dejan ver el fondo animado.
    final contenido = Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.68),
      padding: const EdgeInsets.fromLTRB(9, 5, 8, 3),
      decoration: BoxDecoration(
        color: censurado
            ? (oscuro ? const Color(0xFF26272B) : const Color(0xFFE9E9EC))
            : fondo,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(!mio && !mismoAutor ? 4 : 14),
          topRight: Radius.circular(mio && !mismoAutor ? 4 : 14),
          bottomLeft: const Radius.circular(14),
          bottomRight: const Radius.circular(14),
        ),
        border: borde == null ? null : Border.all(color: borde, width: 0.8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: oscuro ? 0.35 : 0.07),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre de color, en la burbuja (solo el primero de la tanda y
          // nunca en lo mío, como WhatsApp).
          if (!mio && !mismoAutor)
            GestureDetector(
              onTap: esBot ? null : () => _menuUsuario(m, nombre),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text(nombre.isEmpty ? 'Usuario' : nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: colorNombre)),
                  ),
                  if (esBot) ...[
                    const SizedBox(width: 3),
                    // Sello de verificado: ✓ en círculo blanco con aro rojo.
                    Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: colorNombre, width: 1.6),
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 10, color: Color(0xFF1C1C1E)),
                    ),
                  ],
                ]),
              ),
            ),
          if (censurado) _mascaraCensura(oscuro),
          if (!censurado && m['responde_a'] != null) _cita(m, colorTexto),
          if (!censurado && m['ubicacion'] is Map) ...[
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.location_on_rounded, size: 15, color: colorTexto),
              const SizedBox(width: 3),
              Text('Estoy por aquí',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colorTexto)),
            ]),
            const SizedBox(height: 5),
            MapaMini(
                lat: ((m['ubicacion'] as Map)['lat'] as num).toDouble(),
                lng: ((m['ubicacion'] as Map)['lng'] as num).toDouble(),
                alto: 120,
                ancho: 230),
            if ((m['texto'] ?? '').toString().isNotEmpty)
              const SizedBox(height: 6),
          ],
          if (!censurado && (m['texto'] ?? '').toString().isNotEmpty)
            _textoConMenciones(m['texto'].toString(), colorTexto,
                (m['menciones'] as List?) ?? const [],
                idMsg: (m['id'] as num?)?.toInt()),
          if (!censurado && m['ancla_tipo'] != null) ...[
            if ((m['texto'] ?? '').toString().isNotEmpty)
              const SizedBox(height: 6),
            _tarjetaAncla(m),
          ],
          // Hora abajo a la derecha (y el ⌄ del menú), dentro de la burbuja.
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _menuMensaje(m),
              child: Padding(
                padding: const EdgeInsets.only(top: 1, left: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_hora(m['created_at']),
                      style: TextStyle(fontSize: 10, color: colorHora)),
                  Icon(Icons.expand_more_rounded, size: 14, color: colorHora),
                ]),
              ),
            ),
          ),
        ],
      ),
    );

    final idMsg = (m['id'] as num?)?.toInt();
    return GestureDetector(
      key: idMsg == null
          ? null
          : _llaves.putIfAbsent(idMsg, () => GlobalKey()),
      onLongPress: () => _menuMensaje(m),
      child: Padding(
      padding: EdgeInsets.only(top: mismoAutor ? 2 : 6),
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

  /// Lo que queda de un mensaje denunciado: una máscara con el aviso.
  Widget _mascaraCensura(bool oscuro) {
    final c = oscuro ? Colors.white70 : const Color(0xFF55565C);
    return Padding(
      padding: const EdgeInsets.only(top: 1, bottom: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.block_rounded, size: 16, color: c),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Censurado',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                        color: c)),
                const SizedBox(height: 2),
                Text(
                    'El equipo de OkVenta revisará este mensaje y '
                    'contactará al vendedor.',
                    style: TextStyle(
                        fontSize: 12, height: 1.3, color: c)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Foto del autor (solo en el primer mensaje de cada tanda). Tocarla
  /// abre su perfil, igual que tocar el nombre.
  Widget _columnaAvatar(
      Map<String, dynamic> m, bool esBot, bool mismoAutor, String nombre) {
    return SizedBox(
      width: 28,
      child: mismoAutor
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: esBot
                  ? _avatarBot()
                  : GestureDetector(
                      onTap: () => _menuUsuario(m, nombre),
                      child: AvatarUsuario(
                          fotoUrl: m['foto_url'], nombre: nombre, tamano: 26),
                    ),
            ),
    );
  }

  /// Tocar a alguien: mensaje privado, perfil o mencionar.
  void _menuUsuario(Map<String, dynamic> m, String nombre) {
    final uid = (m['user_id'] as num?)?.toInt();
    if (uid == null) return;
    final n = nombre.isEmpty ? 'Usuario' : nombre;
    final primero = n.split(' ').first;
    final esYo = uid == _miId;
    _foco.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        Widget op(IconData i, String t, VoidCallback f) => ListTile(
              leading: Icon(i, color: colors.textPrimary),
              title: Text(t,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                f();
              },
            );
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 14),
            AvatarUsuario(
                fotoUrl: m['foto_url']?.toString(), nombre: n, tamano: 58),
            const SizedBox(height: 8),
            Text(n,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary)),
            if ((m['handle'] ?? '').toString().isNotEmpty)
              Text('@${m['handle']}',
                  style: TextStyle(fontSize: 12.5, color: colors.grayMid)),
            const SizedBox(height: 8),
            if (!esYo)
              op(Icons.mail_outline_rounded, 'Enviar mensaje privado a $primero',
                  () => _abrirPrivado(uid, n, m['foto_url']?.toString())),
            op(Icons.person_outline_rounded, 'Ver perfil',
                () => _abrirPerfil(m, nombre)),
            if (!esYo && _miId != null)
              op(Icons.alternate_email_rounded, 'Mencionar en el chat',
                  () => _mencionar(m)),
            const SizedBox(height: 6),
          ]),
        );
      },
    );
  }

  void _abrirPrivado(int uid, String nombre, String? foto) {
    if (_miId == null) {
      widget.onPedirLogin?.call();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatPrivadoScreen(otroId: uid, nombre: nombre, fotoUrl: foto),
      ),
    );
  }

  /// "+" de la caja de texto: más opciones sin quitarle espacio al texto.
  void _masOpciones() {
    _foco.unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        Widget op(IconData i, String t, String d, VoidCallback f) => ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle),
                child: Icon(i, color: colors.primary),
              ),
              title: Text(t,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              subtitle: Text(d,
                  style: TextStyle(fontSize: 12, color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                f();
              },
            );
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            op(Icons.location_on_outlined, 'Enviar mi ubicación',
                '"Estoy aquí, necesito…" (aproximada)', _enviarUbicacion),
            op(Icons.push_pin_outlined, 'Anclar lo que vendes',
                'Un producto o servicio tuyo en el mensaje', _elegirAncla),
            op(Icons.search_rounded, 'Buscar en el chat',
                'Encuentra un mensaje o filtra por @persona',
                () => _abrirNubeBusqueda(context)),
            const SizedBox(height: 6),
          ]),
        );
      },
    );
  }

  Future<void> _enviarUbicacion() async {
    if (_miId == null) {
      widget.onPedirLogin?.call();
      return;
    }
    final u = await pedirUbicacionCompartida(context);
    if (u == null || !mounted) return;
    setState(() => _enviando = true);
    try {
      final msg = await ApiService.enviarMensajeComunidad(
          userId: _miId!, texto: u.texto, lat: u.lat, lng: u.lng);
      if (!mounted) return;
      setState(() {
        if (!_mensajes.any((x) => x['id'] == msg['id'])) _mensajes.add(msg);
      });
      _alFinal();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo enviar la ubicación')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
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
  Widget _textoConMenciones(String texto, Color color, List menciones,
      {int? idMsg}) {
    final porHandle = <String, int>{
      for (final x in menciones)
        if (x is Map && x['handle'] != null && x['id'] is num)
          x['handle'].toString().toLowerCase(): (x['id'] as num).toInt(),
    };
    final estilo = TextStyle(fontSize: 14, height: 1.25, color: color);
    final spans = <InlineSpan>[];
    var i = 0;
    for (final m in _reMencion.allMatches(texto)) {
      if (m.start > i) {
        spans.addAll(_resaltar(texto.substring(i, m.start), idMsg, i));
      }
      final token = m.group(0)!;
      final handle = token.substring(1).toLowerCase();
      final uid = porHandle[handle];
      final esBot = handle == 'okventa';
      // La @mención va del color de esa persona (como su nombre).
      final colorMencion = uid != null ? _colorDeUsuario(uid) : color;
      final resaltado = TextStyle(
          fontWeight: FontWeight.w700,
          color: colorMencion);
      if (uid != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => _abrirPerfil({'user_id': uid}, token.substring(1)),
            child: Text.rich(
                TextSpan(
                    children: _resaltar(token, idMsg, m.start,
                        estilo: estilo.merge(resaltado))),
                style: estilo.merge(resaltado)),
          ),
        ));
      } else if (esBot || porHandle.isEmpty) {
        spans.addAll(_resaltar(token, idMsg, m.start, estilo: resaltado));
      } else {
        spans.addAll(_resaltar(token, idMsg, m.start));
      }
      i = m.end;
    }
    if (i < texto.length) {
      spans.addAll(_resaltar(texto.substring(i), idMsg, i));
    }
    return Text.rich(TextSpan(children: spans), style: estilo);
  }

  /// Cita del mensaje al que se responde (una línea, arriba del texto).
  Widget _cita(Map<String, dynamic> m, Color color) {
    final orig = _mensajes.firstWhere((x) => x['id'] == m['responde_a'],
        orElse: () => const <String, dynamic>{});
    if (orig.isEmpty) return const SizedBox.shrink();
    final quien = orig['es_bot'] == true
        ? 'OkVenta'
        : [orig['nombre'], orig['apellido']]
            .where((x) => x != null && '$x'.trim().isNotEmpty)
            .join(' ');
    final texto = orig['censurado'] == true
        ? '🚫 Censurado'
        : (orig['texto'] ?? '').toString().isNotEmpty
            ? orig['texto'].toString()
            : (orig['ancla_titulo'] ?? '📌').toString();
    final colorQuien = orig['es_bot'] == true
        ? const Color(0xFFFF8A80)
        : _colorDeUsuario((orig['user_id'] as num?)?.toInt() ?? 0);
    // Cita como WhatsApp: fondo un poco más oscuro, barra del color de quien
    // escribió el original, su nombre en ese color y el texto en gris.
    return Container(
      margin: const EdgeInsets.only(bottom: 5, top: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: colorQuien,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(quien.isEmpty ? 'Usuario' : quien,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: colorQuien)),
                  const SizedBox(height: 1),
                  Text(texto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, color: color.withValues(alpha: 0.75))),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// Color fijo de cada persona (como WhatsApp). En modo oscuro tonos
  /// claros; en claro, más intensos para leerse sobre blanco.
  Color _colorDeUsuario(int id) {
    const claros = [
      Color(0xFFF48FB1), Color(0xFFFFAB91), Color(0xFF81D4FA),
      Color(0xFFA5D6A7), Color(0xFFCE93D8), Color(0xFFFFCC80),
      Color(0xFF80CBC4), Color(0xFFB39DDB),
    ];
    const intensos = [
      Color(0xFFD81B60), Color(0xFFE65100), Color(0xFF0277BD),
      Color(0xFF2E7D32), Color(0xFF8E24AA), Color(0xFFB26A00),
      Color(0xFF00796B), Color(0xFF5E35B1),
    ];
    final lista = ThemeService.isDarkMode ? claros : intensos;
    return lista[id.abs() % lista.length];
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
            opcion(
                _estaFijado(id)
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                _estaFijado(id) ? 'Quitar de fijados' : 'Fijar comentario',
                () => cerrarY(() => _alternarFijado(m))),
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
    // Se tapa al tiro (aquí y, en el servidor, para todos).
    final idMsg = (m['id'] as num?)?.toInt();
    setState(() => _tapar(m));
    if (idMsg != null) {
      ApiService.denunciarMensajeComunidad(idMsg, uid, motivo)
          .catchError((_) => false);
    }
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
        content: const Text(
            'Mensaje censurado. El equipo de OkVenta lo revisará.'),
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // "+": ubicación, anclar, buscar (así la pastilla es más ancha)
              IconButton(
                onPressed: _masOpciones,
                tooltip: 'Más opciones',
                icon: Icon(Icons.add_circle_outline_rounded,
                    size: 26, color: colors.primary),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _foco,
                          minLines: 1,
                          maxLines: 5,
                          maxLength: 500,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(
                              fontSize: 15.5, color: colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Escribe… usa @ para mencionar',
                            hintStyle: TextStyle(
                                fontSize: 15, color: colors.grayMid),
                            counterText: '',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.fromLTRB(16, 14, 4, 14),
                          ),
                        ),
                      ),
                      // Emojis dentro de la pastilla
                      IconButton(
                        onPressed: () =>
                            setState(() => _verEmojis = !_verEmojis),
                        icon: Icon(
                            _verEmojis
                                ? Icons.keyboard_alt_outlined
                                : Icons.emoji_emotions_outlined,
                            size: 22,
                            color: _verEmojis
                                ? colors.primary
                                : colors.grayMid),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: puedeEnviar ? _enviar : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48,
                  height: 48,
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
                          size: 21, color: Colors.white),
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

/// Una aparición de lo buscado: en qué mensaje y en qué posición del texto.
class _Coincidencia {
  final int mensajeId;
  final int inicio;
  const _Coincidencia(this.mensajeId, this.inicio);
}

/// La nube flotante de búsqueda: campo + sugerencias de @personas. Devuelve
/// (con Navigator.pop) lo que se va a buscar.
class _NubeBusqueda extends StatefulWidget {
  final double flechaX;
  final int? miId;
  const _NubeBusqueda({required this.flechaX, this.miId});

  @override
  State<_NubeBusqueda> createState() => _NubeBusquedaState();
}

class _NubeBusquedaState extends State<_NubeBusqueda> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _gente = [];
  Timer? _espera;

  @override
  void dispose() {
    _espera?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _cambio(String v) {
    setState(() {});
    _espera?.cancel();
    if (!v.startsWith('@') || v.length < 2) {
      if (_gente.isNotEmpty) setState(() => _gente = []);
      return;
    }
    _espera = Timer(const Duration(milliseconds: 250), () async {
      try {
        final l = await ApiService.buscarUsuariosComunidad(v.substring(1),
            excluir: widget.miId);
        if (mounted) setState(() => _gente = l.take(5).toList());
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(left: widget.flechaX - 8),
            child: CustomPaint(
                size: const Size(16, 8), painter: _PiquitoArriba(colors.surface)),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Icon(Icons.search_rounded, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    onChanged: _cambio,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (v) => Navigator.pop(context, v.trim()),
                    style: TextStyle(fontSize: 15, color: colors.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Buscar palabra o @persona',
                      hintStyle: TextStyle(color: colors.grayMid),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context, _ctrl.text.trim()),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Text('Buscar',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
              for (final u in _gente)
                InkWell(
                  onTap: () => Navigator.pop(context, '@${u['handle']}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      AvatarUsuario(
                          fotoUrl: u['foto_url']?.toString(),
                          nombre: '${u['nombre'] ?? ''}',
                          tamano: 30),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('@${u['handle']}',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary)),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _PiquitoArriba extends CustomPainter {
  final Color color;
  _PiquitoArriba(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PiquitoArriba old) => old.color != color;
}
