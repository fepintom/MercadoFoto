import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_router.dart';
import '../services/navigation_service.dart';
import '../services/session_service.dart';
import '../services/cart_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';

import 'carrito_screen.dart';

import 'vender_screen.dart' as vender;
import 'marketplace_screen.dart';
import 'mi_cuenta_screen.dart';
import 'encontrar_screen.dart';
import 'favoritos_screen.dart';
import 'mensajes_screen.dart';
import 'chat_screen.dart';
import 'oferta_screen.dart';
import 'servicios_screen.dart';
import 'comunidad_screen.dart';
import 'notificaciones_screen.dart';
import 'mis_direcciones_screen.dart';
import '../widgets/registro_form_widget.dart';

// ---------------------------------------------------------------------------
// HOME SCREEN
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Pestaña visible del IndexedStack: 0=OkMarket, 2=OkServicios,
  // 3=Comunidad (el 1 queda reservado: Alertas abre como hoja).
  int _tab = 0;

  static const int _kTabOkMarket = 0;
  static const int _kTabAlertas = 1;
  static const int _kTabOkServicios = 2;
  static const int _kTabComunidad = 3;
  static const int _kTabEncontrar = 4;
  static const int _kTabCuenta = 5;

  /// Pestañas ya abiertas alguna vez. Las demás no se construyen hasta que
  /// se visitan (el mapa y Mi OkVenta cargan datos al crearse).
  final Set<int> _visitadas = {_kTabOkMarket};

  /// Sube cada vez que se entra a Mi OkVenta: la pantalla se recrea y lee
  /// los datos frescos (antes se abría encima y se recargaba al volver).
  int _versionCuenta = 0;

  /// Navegador de adentro: todo lo que se abre desde las pestañas se apila
  /// aquí, así la barra de menú de abajo queda siempre visible.
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  /// Contexto para navegar dentro del área de contenido (sobre la barra).
  BuildContext get _ctxNav => _navKey.currentContext ?? context;

  // Códigos de los botones de la barra (no son pestañas: algunos abren
  // pantallas encima). 3 = Encontrar, 4 = Mi OkVenta, 1 = Alertas.
  static const int _kNavComunidad = 10;
  static const int _kNavOkMarket = 5;
  static const int _kNavOkServicios = 6;
  int? userId;
  String nombreUsuario = "";
  int _notifCount = 0;
  Timer? _notifTimer;

  // ── UBICACIÓN / RADIO ──────────────────────────────────────────────────────
  Position? _miPosicion;
  bool _cargandoUbicacion = false;
  double _radioKm = 50.0;
  bool _filtroUbicacionActivo = false;

  static const _kRadio  = 'mkt_radio_km';
  static const _kActivo = 'mkt_ubicacion_activo';

  // ── DIRECCIONES ───────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _misDirections = [];
  Map<String, dynamic>? _direccionActual;

  // ── INIT ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    shellNavigatorKey = _navKey;
    _inicializar();
    _cargarPrefsUbicacion();
    _obtenerUbicacion();
  }

  @override
  void dispose() {
    if (identical(shellNavigatorKey, _navKey)) shellNavigatorKey = null;
    _notifTimer?.cancel();
    super.dispose();
  }

  Future<void> _inicializar() async {
    await _iniciarSesion();
    await _cargarUsuario();
    _notifTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _cargarNotifCount(),
    );
    _cargarNotifCount();
  }

  Future<void> _cargarNotifCount() async {
    if (userId == null) return;
    try {
      final data = await ApiService.obtenerNotificaciones(userId!);
      final noLeidas = data.where((n) => n['leido'] == 0 || n['leido'] == false).length;
      if (mounted) setState(() => _notifCount = noLeidas);
    } catch (_) {}
  }

  // ── Preferencias de ubicación ─────────────────────────────────────────────
  Future<void> _cargarPrefsUbicacion() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _radioKm = prefs.getDouble(_kRadio) ?? 50.0;
      _filtroUbicacionActivo = prefs.getBool(_kActivo) ?? false;
    });
  }

  Future<void> _guardarPrefsUbicacion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kRadio, _radioKm);
    await prefs.setBool(_kActivo, _filtroUbicacionActivo);
  }

  // ── GPS ───────────────────────────────────────────────────────────────────
  Future<void> _obtenerUbicacion() async {
    setState(() => _cargandoUbicacion = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _cargandoUbicacion = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      if (!mounted) return;
      setState(() { _miPosicion = pos; _cargandoUbicacion = false; });
    } catch (_) {
      if (mounted) setState(() => _cargandoUbicacion = false);
    }
  }


  Future<void> _iniciarSesion() async {
    final user = await SessionService.obtenerUser();
    if (user != null) return;
    final guest = await SessionService.obtenerGuest();
    if (guest != null && guest.isNotEmpty) return;
    try {
      final res = await http.get(Uri.parse("${ApiService.baseUrl}/guest"));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final guestId = data["guest_id"]?.toString();
        if (guestId != null && guestId.isNotEmpty) {
          await SessionService.guardarGuest(guestId);
        }
      }
    } catch (_) {}
  }

  Future<void> _cargarUsuario() async {
    final id = await SessionService.obtenerUser();
    final nombre = await SessionService.obtenerNombre();
    if (!mounted) return;
    setState(() {
      userId = id;
      nombreUsuario = nombre ?? "";
    });
    if (id != null) _cargarDirecciones(id);
  }

  Future<void> _cargarDirecciones(int uid) async {
    try {
      final data = await ApiService.obtenerDirecciones(uid);
      if (!mounted) return;
      setState(() {
        _misDirections = data;
        _direccionActual = data.firstWhere(
          (d) => (d['es_principal'] as int? ?? 0) == 1,
          orElse: () => data.isNotEmpty ? data.first : {},
        );
        if (_direccionActual!.isEmpty) _direccionActual = null;
      });
    } catch (_) {}
  }

  void _mostrarSelectorDireccion() {
    if (userId == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DireccionSelectorSheet(
        misDirections: _misDirections,
        direccionActual: _direccionActual,
        onSeleccionada: (d) async {
          Navigator.pop(context);
          if (d == null) {
            // → editar
            await Navigator.push(
              _ctxNav,
              MaterialPageRoute(
                builder: (_) => MisDireccionesScreen(
                    userId: userId!, mostrarBotonMarketplace: true),
              ),
            );
            _cargarDirecciones(userId!);
            return;
          }
          final id = d['id'] as int;
          try {
            await ApiService.establecerPrincipal(userId!, id);
          } catch (_) {}
          setState(() => _direccionActual = d);
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.location_on_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Dirección cambiada a: ${d['etiqueta']}',
                  style: const TextStyle(fontSize: 13),
                )),
              ]),
              backgroundColor: colors.carbon,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            ));
          }
          _cargarDirecciones(userId!);
        },
      ),
    );
  }

  // ── AUTH MODALS ────────────────────────────────────────────────────────────
  Future<void> _abrirLoginModal() async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => _buildAuthModal(isLogin: true),
    );
  }

  Future<void> _abrirRegistroModal() async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => _buildAuthModal(isLogin: false),
    );
  }

  Widget _buildAuthModal({required bool isLogin}) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: RegistroFormWidget(
                isLogin: isLogin,
                onToggle: () {
                  Navigator.pop(context);
                  if (isLogin) {
                    _abrirRegistroModal();
                  } else {
                    _abrirLoginModal();
                  }
                },
                onSubmit: (email, password) async {
                  if (isLogin) {
                    await _handleLogin(email, password);
                  } else {
                    await _handleRegistro(email, password);
                  }
                },
                onGoogleSignIn: () async {
                  await _handleGoogle();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin(String email, String password) async {
    try {
      await AuthService.loginConEmail(email, password);
      if (!mounted) return;
      Navigator.pop(context);
      await _inicializar();
    } catch (e) {
      final msg = AuthService.mensajeError(e);
      if (msg.isNotEmpty) _mostrarError(msg);
    }
  }

  Future<void> _handleRegistro(String email, String password) async {
    try {
      await AuthService.registrarConEmail(email, password);
      if (!mounted) return;
      Navigator.pop(context);
      await _inicializar();
    } catch (e) {
      final msg = AuthService.mensajeError(e);
      if (msg.isNotEmpty) _mostrarError(msg);
    }
  }

  Future<void> _handleGoogle() async {
    try {
      await AuthService.loginConGoogle();
      if (!mounted) return;
      Navigator.pop(context);
      await _inicializar();
    } catch (e) {
      final msg = AuthService.mensajeError(e);
      if (msg.isNotEmpty) _mostrarError(msg);
    }
  }

  void _mostrarError(String? msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg ?? "Error"),
        backgroundColor: colors.primary,
      ),
    );
  }

  // ── NAVEGACIÓN ──────────────────────────────────────────────────────────────
  /// "+ Publicar" de OkMarket: lo que antes hacía el botón "Vender" de la
  /// barra inferior.
  void _abrirVender() {
    Navigator.push(
      _ctxNav,
      MaterialPageRoute(builder: (_) => const vender.VenderScreen()),
    ).then((_) => _inicializar());
  }

  /// Cambia de pestaña. Si había pantallas abiertas encima (un producto,
  /// un chat…), se cierran: tocar el menú lleva a la raíz de esa sección.
  void _irATab(int tab) {
    _navKey.currentState?.popUntil((r) => r.isFirst);
    if (_tab == _kTabCuenta && tab != _kTabCuenta) _inicializar();
    setState(() {
      if (tab == _kTabCuenta && _tab != _kTabCuenta) _versionCuenta++;
      _tab = tab;
      _visitadas.add(tab);
    });
  }

  void _onNavTap(int index) {
    if (index == _kNavOkMarket) return _irATab(_kTabOkMarket);
    if (index == _kNavOkServicios) return _irATab(_kTabOkServicios);
    if (index == _kNavComunidad) return _irATab(_kTabComunidad);
    if (index == 4) {
      // Mi OkVenta
      if (userId != null) {
        _irATab(_kTabCuenta);
      } else {
        _abrirLoginModal();
      }
      return;
    }
    if (index == 3) return _irATab(_kTabEncontrar);
    if (index == 1) return _irATab(_kTabAlertas);
    _irATab(index);
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Logo: celular en modo claro (agrandado 30%, 44 → 57), okventin
          // en modo oscuro, misma altura.
          ValueListenableBuilder<bool>(
            valueListenable: ThemeService.isDarkNotifier,
            builder: (_, isDark, __) {
              return Image.asset(
                isDark ? 'assets/images/okventin.png' : 'assets/images/home.png',
                height: 57,
              );
            },
          ),

          const SizedBox(width: 8),

          // Dirección (centro, solo para usuarios registrados)
          if (userId != null)
            Expanded(child: _buildDireccionInline())
          else
            const Spacer(),

          const SizedBox(width: 4),

          // El toggle de modo claro/oscuro se movió a Mi cuenta > MODO —
          // ya no vive como ícono en este header.

          // Carrito
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: CartService.cartNotifier,
            builder: (_, cart, __) {
              return GestureDetector(
                // Antes solo abría si ya tenía algo — con el carro vacío
                // no hacía nada al tocarlo. Ahora siempre abre la
                // pantalla del carro (que ya maneja su propio estado vacío).
                onTap: _mostrarCarrito,
                child: Stack(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cart.isNotEmpty
                            ? colors.primary.withOpacity(0.1)
                            : colors.background,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        size: 20,
                        color: cart.isNotEmpty
                            ? colors.primary
                            : colors.grayMid,
                      ),
                    ),
                    if (cart.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              "${cart.length}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(width: 8),

          // Mensajes (ahora en el header)
          if (userId != null)
            GestureDetector(
              onTap: () => Navigator.push(
                _ctxNav,
                MaterialPageRoute(builder: (_) => const MensajesScreen()),
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: colors.grayMid,
                ),
              ),
            ),

          const SizedBox(width: 8),

          // Avatar / Entrar
          if (userId == null)
            GestureDetector(
              onTap: _abrirRegistroModal,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.primary, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Entrar",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => _irATab(_kTabCuenta),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.carbon,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    nombreUsuario.isNotEmpty
                        ? nombreUsuario[0].toUpperCase()
                        : "U",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],   // Row children
      ),     // Row
    );
  }

  Widget _buildDireccionInline() {
    final dir = _direccionActual;
    final etiqueta = dir?['etiqueta'] as String? ?? '';
    final direccion = dir?['direccion'] as String? ?? '';
    final texto = dir == null
        ? 'Agregar dirección'
        : [etiqueta, direccion].where((s) => s.isNotEmpty).join(' · ');

    // En negro (texto principal), no en rojo: el rojo queda para
    // acciones y filtros; la dirección es un dato.
    return GestureDetector(
      onTap: _mostrarSelectorDireccion,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            dir == null ? Icons.add_location_alt_outlined : Icons.location_on_rounded,
            size: 14,
            color: colors.textPrimary,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: colors.textPrimary),
        ],
      ),
    );
  }

  // ── BARRA INFERIOR ─────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.divider, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              // Comunidad (antes "Inicio"; el marketplace pasó a OkMarket)
              Expanded(
                  child: _navItem(_kNavComunidad, Icons.groups_outlined,
                      "Comunidad",
                      seleccionado: _tab == _kTabComunidad)),
              // Notificaciones
              Expanded(child: _navItemBadge(1, Icons.notifications_outlined, "Alertas", _notifCount)),
              // OkServicios + OkMarket — CENTRO destacados
              _navDobleDestacado(),
              // Encontrar
              Expanded(
                  child: _navItem(3, Icons.explore_outlined, "Encontrar",
                      seleccionado: _tab == _kTabEncontrar)),
              // Mi OkVenta
              Expanded(
                  child: _navItem(4, Icons.person_outline_rounded, "Mi OkVenta",
                      seleccionado: _tab == _kTabCuenta)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label,
      {bool? seleccionado}) {
    final selected = seleccionado ?? _tab == index;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? colors.primary.withOpacity(0.1)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? colors.primary : colors.grayMid,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? colors.primary : colors.grayMid,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItemBadge(int index, IconData icon, String label, int badge) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20,
                      color: selected ? colors.primary : colors.grayMid),
                ),
                if (badge > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 1),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? colors.primary : colors.grayMid)),
          ],
        ),
      ),
    );
  }

  Widget _navDobleDestacado() {
    final selServ = _tab == _kTabOkServicios;
    final selMarket = _tab == _kTabOkMarket;
    return SizedBox(
      width: 140,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── OkServicios ────────────────────────────────────
          GestureDetector(
            onTap: () => _onNavTap(_kNavOkServicios),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -10),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: colors.carbon,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surface, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: colors.carbon.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      // Siempre el ícono de llave y martillo, igual que el
                      // resto de la barra: el círculo es pequeño y el
                      // mascotín no se distinguía a ese tamaño.
                      child: Icon(
                        Icons.handyman_rounded,
                        color: Colors.white,
                        size: selServ ? 22 : 20,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -8),
                    child: Text(
                      "OkServicios",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: selServ ? colors.textPrimary : colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── OkMarket (antes "Vender") ─────────────────────
          // Mismo diseño que tenía Vender; ahora lleva al marketplace. La
          // lógica de vender pasó al "+ Publicar" de arriba a la derecha.
          GestureDetector(
            onTap: () => _onNavTap(_kNavOkMarket),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -10),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.surface, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withOpacity(0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      // Bolsa + etiqueta de precio: dos elementos, igual
                      // que la llave y el martillo de OkServicios, para que
                      // los dos botones del centro se lean como un par.
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: Icon(Icons.shopping_bag_outlined,
                                color: Colors.white,
                                size: selMarket ? 24 : 22),
                          ),
                          Positioned(
                            right: 7,
                            bottom: 7,
                            child: Transform.rotate(
                              angle: -0.35,
                              child: Container(
                                padding: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.sell_rounded,
                                    color: Colors.white, size: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -8),
                    child: Text(
                      "OkMarket",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: selMarket ? FontWeight.w800 : FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CONTENIDO POR TAB ──────────────────────────────────────────────────────
  Widget _buildInicio() {
    return MarketplaceScreen(
      // Sin "const": mismo motivo que ServiciosScreen — el banner usa
      // colors.carbon como color de fondo de sus placeholders y necesita
      // poder redibujarse en vivo con el toggle de modo oscuro.
      banner: _BannerCarrusel(),
      miLat: _miPosicion?.latitude,
      miLng: _miPosicion?.longitude,
      radioKm: _radioKm,
      filtroUbicacionActivo: _filtroUbicacionActivo && _miPosicion != null,
      // El estado de la ubicación sigue viviendo aquí (lo comparten todas
      // las pestañas); el marketplace solo dibuja la barra y avisa.
      sinGps: _miPosicion == null && !_cargandoUbicacion,
      cargandoUbicacion: _cargandoUbicacion,
      onRadioChanged: (v) => setState(() {
        _radioKm = v;
        if (!_filtroUbicacionActivo) _filtroUbicacionActivo = true;
      }),
      onRadioSoltado: (_) => _guardarPrefsUbicacion(),
      onToggleUbicacion: () {
        setState(() => _filtroUbicacionActivo = !_filtroUbicacionActivo);
        _guardarPrefsUbicacion();
      },
      onPublicar: _abrirVender,
    );
  }

  // ── CARRITO: navega a la pantalla dedicada (antes era un modal) ─────────
  void _mostrarCarrito() {
    Navigator.push(
      _ctxNav,
      MaterialPageRoute(builder: (_) => const CarritoScreen()),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // El ícono de ojo del header vive en esta misma pantalla — sin este
    // ValueListenableBuilder, el resto del home (fondo, cards, textos) no
    // se redibujaba al tocarlo y quedaba con los colores del modo
    // anterior hasta la próxima reconstrucción por otro motivo.
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkNotifier,
      builder: (context, _, __) {
        final teclado = MediaQuery.of(context).viewInsets.bottom > 0;
        return Scaffold(
          backgroundColor: colors.background,
          // El teclado lo maneja cada pantalla de adentro (la raíz de las
          // pestañas es un Scaffold propio); aquí solo se esconde la barra.
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  // Navegador de adentro: productos, chats, perfiles, el
                  // mapa… se abren aquí y la barra de abajo nunca se pierde.
                  child: MediaQuery.removePadding(
                    context: context,
                    removeBottom: !teclado,
                    child: NavigatorPopHandler(
                      onPop: () => _navKey.currentState?.maybePop(),
                      child: Navigator(
                        key: _navKey,
                        pages: [
                          MaterialPage(
                            key: const ValueKey('raiz'),
                            child: _raiz(),
                          ),
                        ],
                        onDidRemovePage: (_) {},
                      ),
                    ),
                  ),
                ),
                // La barra de distancia ya no va aquí abajo: pegada al menú
                // se tocaba sin querer con la palma al sostener el teléfono.
                // Con el teclado abierto (escribiendo en la Comunidad o en
                // un buscador) la barra se esconde: si no, sube pegada al
                // teclado y le quita media pantalla al chat.
                if (!teclado) _buildBottomNav(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// La raíz del navegador de adentro: encabezado (en las secciones de
  /// publicaciones y Comunidad) + las pestañas.
  Widget _raiz() {
    final conEncabezado = _tab == _kTabOkMarket ||
        _tab == _kTabOkServicios ||
        _tab == _kTabComunidad;
    Widget perezosa(int tab, Widget Function() crear) =>
        _visitadas.contains(tab) ? crear() : const SizedBox.shrink();
    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          if (conEncabezado) _buildHeader(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _buildInicio(),
                perezosa(
                  _kTabAlertas,
                  () => NotificacionesScreen(
                    userId: userId,
                    activa: _tab == _kTabAlertas,
                    onLeidas: () {
                      if (mounted && _notifCount != 0) {
                        setState(() => _notifCount = 0);
                      }
                    },
                    onPedirLogin: _abrirLoginModal,
                    onIrAComunidad: () => _irATab(_kTabComunidad),
                  ),
                ),
                // Sin "const": para que el modo oscuro se redibuje en
                // vivo cuando se toca el ícono de ojo estando en esta
                // pestaña (un widget const idéntico se "saltea" en el
                // rebuild y quedaba con los colores del modo anterior).
                ServiciosScreen(),
                ComunidadScreen(
                  activa: _tab == _kTabComunidad,
                  onPedirLogin: _abrirLoginModal,
                ),
                perezosa(_kTabEncontrar,
                    () => EncontrarScreen(esPestana: true)),
                perezosa(
                  _kTabCuenta,
                  () => MiCuentaScreen(
                    key: ValueKey('cuenta-$_versionCuenta'),
                    esPestana: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selector de dirección (bottom sheet) ─────────────────────────────────────

class _DireccionSelectorSheet extends StatelessWidget {
  final List<Map<String, dynamic>> misDirections;
  final Map<String, dynamic>? direccionActual;
  final void Function(Map<String, dynamic>? d) onSeleccionada;

  const _DireccionSelectorSheet({
    required this.misDirections,
    required this.onSeleccionada,
    this.direccionActual,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: colors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Mis direcciones',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
            ),
          ),
          const SizedBox(height: 12),

          if (misDirections.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Text('No tienes direcciones guardadas.',
                  style: TextStyle(color: colors.grayMid, fontSize: 14)),
            )
          else
            ...misDirections.map((d) {
              final esPrincipal = (d['es_principal'] as int? ?? 0) == 1;
              final esActual = direccionActual != null && d['id'] == direccionActual!['id'];
              final etiqueta = d['etiqueta'] as String? ?? 'Casa';
              final direccion = d['direccion'] as String? ?? '';
              final comuna = d['comuna'] as String? ?? '';
              return ListTile(
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: esActual
                        ? colors.primary.withOpacity(0.1)
                        : colors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    etiqueta.toLowerCase().contains('trabajo')
                        ? Icons.work_outline
                        : etiqueta.toLowerCase().contains('otro')
                            ? Icons.place_outlined
                            : Icons.home_outlined,
                    size: 18,
                    color: esActual ? colors.primary : colors.grayMid,
                  ),
                ),
                title: Row(children: [
                  Text(etiqueta,
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: esActual ? colors.primary : colors.textPrimary,
                      )),
                  if (esPrincipal) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('Principal',
                          style: TextStyle(fontSize: 10, color: colors.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
                subtitle: Text(
                  [if (direccion.isNotEmpty) direccion, if (comuna.isNotEmpty) comuna]
                      .join(', '),
                  style: TextStyle(fontSize: 12, color: colors.grayMid),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                trailing: esActual
                    ? Icon(Icons.check_rounded, color: colors.primary, size: 20)
                    : null,
                onTap: () => onSeleccionada(d),
              );
            }),

          const Divider(height: 1),

          // Opción editar
          ListTile(
            leading: Icon(Icons.edit_location_alt_outlined, color: colors.textPrimary),
            title: Text('Editar mis direcciones',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: colors.textPrimary)),
            onTap: () => onSeleccionada(null),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Banner animado ────────────────────────────────────────────────────────────

class _BannerCarrusel extends StatefulWidget {
  const _BannerCarrusel();

  @override
  State<_BannerCarrusel> createState() => _BannerCarruselState();
}

class _BannerCarruselState extends State<_BannerCarrusel> {
  final _controller = PageController();
  int _paginaActual = 0;
  Timer? _timer;

  static const _duracion = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_duracion, (_) {
      if (!mounted) return;
      final siguiente = (_paginaActual + 1) % 5;
      _controller.animateToPage(
        siguiente,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Proporción de los banners (1600×640 = 2,5:1): se ven completos,
        // sin franjas a los lados ni recortes.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: AspectRatio(
            aspectRatio: 2.5,
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _paginaActual = i),
              children: const [
                _BannerImagen('assets/images/banner1.jpg'),
                _BannerImagen('assets/images/banner2.jpg'),
                _BannerImagen('assets/images/banner3.jpg'),
                _BannerImagen('assets/images/banner4.jpg'),
                _BannerImagen('assets/images/banner5.jpg'),
              ],
            ),
          ),
        ),
        // Indicadores de página
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final activo = i == _paginaActual;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: activo ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: activo ? colors.primary : colors.grayMid.withOpacity(0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Banner genérico por imagen (banner1/2/3.jpg) ───────────────────────────────

class _BannerImagen extends StatelessWidget {
  final String asset;
  const _BannerImagen(this.asset);

  @override
  Widget build(BuildContext context) {
    // Mantiene el recuadro del carrusel en su tamaño original: la imagen
    // se achica para entrar completa (BoxFit.contain) en vez de recortarse.
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: colors.carbon,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Container(color: colors.carbon),
        ),
      ),
    );
  }
}

// ── Banner Blue Express ────────────────────────────────────────────────────────

class _BannerBlueExpress extends StatelessWidget {
  const _BannerBlueExpress();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0057B8), Color(0xFF00AEEF)],
          ),
        ),
        child: Stack(
          children: [
            // Círculos decorativos
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),

            // Contenido
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo simulado (texto)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.local_shipping_rounded,
                                color: Color(0xFF0057B8), size: 16),
                            SizedBox(width: 5),
                            Text(
                              'Blue Express',
                              style: TextStyle(
                                color: Color(0xFF0057B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Despacho a todo Chile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Envía tu producto al comprador\ndesde el punto más cercano',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Ícono grande derecha
            const Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white,
                  size: 52,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
