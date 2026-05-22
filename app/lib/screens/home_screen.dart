import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';

import 'vender_screen.dart' as vender;
import 'marketplace_screen.dart';
import 'mi_cuenta_screen.dart';
import 'encontrar_screen.dart';
import 'favoritos_screen.dart';
import 'mensajes_screen.dart';
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
  // Estado de navegación: 0=Inicio, 1=Mensajes, 2=Encontrar, 3=Mi OkVenta, 4=Vender
  int _tab = 0;
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

  // ── INIT ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _inicializar();
    _cargarPrefsUbicacion();
    _obtenerUbicacion();
  }

  @override
  void dispose() {
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

  String _formatRadio(double km) =>
      km < 10 ? "${km.toStringAsFixed(1)} km" : "${km.toStringAsFixed(0)} km";

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
                color: AppColors.surface,
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
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // ── NAVEGACIÓN ──────────────────────────────────────────────────────────────
  void _onNavTap(int index) {
    if (index == 4) {
      // Vender
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const vender.VenderScreen()),
      ).then((_) => _inicializar());
      return;
    }
    if (index == 3) {
      // Mi OkVenta
      if (userId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MiCuentaScreen()),
        ).then((_) => _inicializar());
      } else {
        _abrirLoginModal();
      }
      return;
    }
    if (index == 2) {
      // Encontrar — mapa de productos cercanos
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EncontrarScreen()),
      );
      return;
    }
    if (index == 1) {
      // Al entrar a Mensajes, limpiar badge
      setState(() { _tab = 1; _notifCount = 0; });
      return;
    }
    setState(() => _tab = index);
  }

  void _abrirNotificaciones() {
    if (userId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NotificacionesSheet(userId: userId!),
    ).then((_) {
      // Marcar como leídas al cerrar
      setState(() => _notifCount = 0);
    });
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Image.asset('assets/images/logo.png', height: 44),

          const Spacer(),

          // Carrito
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: CartService.cartNotifier,
            builder: (_, cart, __) {
              return GestureDetector(
                onTap: () {
                  if (cart.isNotEmpty) _mostrarCarrito();
                },
                child: Stack(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cart.isNotEmpty
                            ? AppColors.primary.withOpacity(0.1)
                            : AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 20,
                        color: cart.isNotEmpty
                            ? AppColors.primary
                            : AppColors.grayMid,
                      ),
                    ),
                    if (cart.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
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

          // Campana de notificaciones
          if (userId != null)
            GestureDetector(
              onTap: () => _abrirNotificaciones(),
              child: Stack(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _notifCount > 0
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _notifCount > 0
                          ? Icons.notifications_rounded
                          : Icons.notifications_outlined,
                      size: 20,
                      color: _notifCount > 0
                          ? AppColors.primary
                          : AppColors.grayMid,
                    ),
                  ),
                  if (_notifCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _notifCount > 9 ? '9+' : '$_notifCount',
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
                  border: Border.all(color: AppColors.primary, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Entrar",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MiCuentaScreen()),
                ).then((_) => _inicializar());
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.carbon,
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
        ],
      ),
    );
  }

  // ── SLIDER DE RADIO (barra fija inferior, reemplaza categorías) ───────────
  Widget _buildSliderRadio() {
    final bool sinGps = _miPosicion == null && !_cargandoUbicacion;
    final bool activo = _filtroUbicacionActivo && !sinGps;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 50,
      child: Row(
        children: [
          // Icono-toggle
          GestureDetector(
            onTap: () {
              if (_cargandoUbicacion) return;
              if (sinGps) { Geolocator.openAppSettings(); return; }
              setState(() => _filtroUbicacionActivo = !_filtroUbicacionActivo);
              _guardarPrefsUbicacion();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: activo ? AppColors.primary.withValues(alpha: 0.10) : AppColors.background,
                shape: BoxShape.circle,
              ),
              child: _cargandoUbicacion
                  ? const Padding(
                      padding: EdgeInsets.all(7),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.grayMid),
                    )
                  : Icon(
                      sinGps ? Icons.location_off_outlined : Icons.near_me_rounded,
                      size: 15,
                      color: activo ? AppColors.primary : AppColors.grayMid,
                    ),
            ),
          ),

          const SizedBox(width: 8),

          // Slider o mensaje sin GPS
          Expanded(
            child: sinGps
                ? GestureDetector(
                    onTap: () => Geolocator.openAppSettings(),
                    child: const Text(
                      "GPS no disponible — toca para activar",
                      style: TextStyle(fontSize: 12, color: AppColors.grayMid),
                    ),
                  )
                : SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: activo ? AppColors.primary : AppColors.grayMid.withValues(alpha: 0.4),
                      inactiveTrackColor: AppColors.divider,
                      thumbColor: activo ? AppColors.primary : AppColors.grayMid,
                      overlayColor: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: Slider(
                      value: _radioKm,
                      min: 1,
                      max: 2000,
                      onChanged: (v) => setState(() {
                        _radioKm = v;
                        if (!_filtroUbicacionActivo) _filtroUbicacionActivo = true;
                      }),
                      onChangeEnd: (_) => _guardarPrefsUbicacion(),
                    ),
                  ),
          ),

          // Valor km
          if (!sinGps && !_cargandoUbicacion)
            SizedBox(
              width: 58,
              child: Text(
                _formatRadio(_radioKm),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: activo ? AppColors.primary : AppColors.grayMid,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── BARRA INFERIOR ─────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, "Inicio"),
              _navItemBadge(1, Icons.chat_bubble_outline_rounded, "Mensajes", _notifCount),
              _navItem(2, Icons.explore_outlined, "Encontrar"),
              _navItem(3, Icons.person_outline_rounded, "Mi OkVenta"),
              _navVender(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? AppColors.primary : AppColors.grayMid,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.primary : AppColors.grayMid,
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
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22,
                      color: selected ? AppColors.primary : AppColors.grayMid),
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
                    fontSize: 10,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppColors.primary : AppColors.grayMid)),
          ],
        ),
      ),
    );
  }

  Widget _navVender() {
    return GestureDetector(
      onTap: () => _onNavTap(4),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 1),
            const Text(
              "Vender",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── CONTENIDO POR TAB ──────────────────────────────────────────────────────
  Widget _buildInicio() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Banner
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            height: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.carbon,
              image: const DecorationImage(
                image: AssetImage("assets/images/banner_publicidad.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          MarketplaceScreen(
            miLat: _miPosicion?.latitude,
            miLng: _miPosicion?.longitude,
            radioKm: _radioKm,
            filtroUbicacionActivo: _filtroUbicacionActivo && _miPosicion != null,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAlertas() {
    if (userId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_off_outlined,
                  size: 64, color: AppColors.grayMid),
              const SizedBox(height: 20),
              const Text(
                "Inicia sesión para ver\ntus alertas",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _abrirLoginModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                ),
                child: const Text("Ingresar"),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accesos rápidos
          const Text(
            "Mis guardados",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _accesoRapido(
                  icono: Icons.favorite_outline,
                  label: "Favoritos",
                  sublabel: "Productos que guardaste",
                  color: AppColors.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FavoritosScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _accesoRapido(
                  icono: Icons.explore_outlined,
                  label: "Encontrar",
                  sublabel: "Productos cerca de ti",
                  color: AppColors.carbon,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EncontrarScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Notificaciones
          const Text(
            "Notificaciones",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(Icons.notifications_outlined,
                    size: 56, color: AppColors.grayMid.withOpacity(0.4)),
                const SizedBox(height: 12),
                const Text(
                  "Sin notificaciones",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Cuando tengas actividad, aparecerá aquí",
                  style: TextStyle(fontSize: 13, color: AppColors.grayMid),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accesoRapido({
    required IconData icono,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.grayMid),
            ),
          ],
        ),
      ),
    );
  }

  // ── CARRITO MODAL ──────────────────────────────────────────────────────────
  void _mostrarCarrito() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: CartService.cartNotifier,
          builder: (_, cart, __) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Mis ofertas",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          CartService.clear();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Vaciar",
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  ...cart.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.divider, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item["titulo"] ?? "",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Precio publicado: \$${item["precio"]}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.grayMid,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Oferta: \$${item["oferta"]}",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _buildInicio(),
                  const MensajesScreen(),
                ],
              ),
            ),
            if (_tab == 0) _buildSliderRadio(),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }
}

// ── Panel de notificaciones ──────────────────────────────────────────────────
class _NotificacionesSheet extends StatefulWidget {
  final int userId;
  const _NotificacionesSheet({required this.userId});

  @override
  State<_NotificacionesSheet> createState() => _NotificacionesSheetState();
}

class _NotificacionesSheetState extends State<_NotificacionesSheet> {
  List<Map<String, dynamic>> _notifs = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final data = await ApiService.obtenerNotificaciones(widget.userId);
      if (mounted) setState(() { _notifs = data; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  IconData _icono(String tipo) {
    switch (tipo) {
      case 'oferta':     return Icons.monetization_on_outlined;
      case 'pregunta':   return Icons.help_outline_rounded;
      case 'chat':       return Icons.chat_bubble_outline_rounded;
      case 'interes_compra': return Icons.favorite_outline;
      default:           return Icons.notifications_outlined;
    }
  }

  String _formatFecha(String? f) {
    if (f == null) return '';
    try {
      final dt = DateTime.parse(f).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24)   return 'Hace ${diff.inHours}h';
      return '${dt.day}/${dt.month}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: const [
                Icon(Icons.notifications_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Notificaciones',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          Divider(height: 0.5, color: AppColors.divider),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _notifs.isEmpty
                    ? const Center(
                        child: Text('Sin notificaciones aún',
                            style: TextStyle(color: AppColors.grayMid)))
                    : ListView.separated(
                        controller: ctrl,
                        itemCount: _notifs.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 0.5, color: AppColors.divider),
                        itemBuilder: (_, i) {
                          final n = _notifs[i];
                          final leida = n['leido'] == 1 || n['leido'] == true;
                          return Container(
                            color: leida ? Colors.transparent : AppColors.primary.withOpacity(0.05),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(_icono(n['tipo'] ?? ''),
                                      color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n['mensaje'] ?? '',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                              fontWeight: leida
                                                  ? FontWeight.w400
                                                  : FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text(_formatFecha(n['fecha']),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.grayMid)),
                                    ],
                                  ),
                                ),
                                if (!leida)
                                  Container(
                                    width: 8, height: 8,
                                    decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
