import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';

import 'vender_screen.dart' as vender;
import 'marketplace_screen.dart';
import 'mi_cuenta_screen.dart';
import 'mis_publicaciones_screen.dart';
import '../widgets/registro_form_widget.dart';

// ---------------------------------------------------------------------------
// MODELO DE CATEGORÍAS
// ---------------------------------------------------------------------------

class Categoria {
  final String nombre;
  final IconData icono;
  final List<String> subcategorias;

  const Categoria({
    required this.nombre,
    required this.icono,
    required this.subcategorias,
  });
}

// ---------------------------------------------------------------------------
// HOME SCREEN
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Estado de navegación: 0=Inicio, 1=Alertas, 2=Buscar
  int _tab = 0;
  int? userId;
  String nombreUsuario = "";
  String? _categoriaSeleccionada;
  String? _subcategoriaSeleccionada;

  final _searchController = TextEditingController();

  // ── CATEGORÍAS ─────────────────────────────────────────────────────────────
  static const List<Categoria> _categorias = [
    Categoria(
      nombre: "Automotriz",
      icono: Icons.directions_car_rounded,
      subcategorias: ["Repuestos", "Autos", "Motos", "Camiones"],
    ),
    Categoria(
      nombre: "Electrónica",
      icono: Icons.devices_rounded,
      subcategorias: ["Computación", "Impresión 3D", "Celulares", "TV"],
    ),
    Categoria(
      nombre: "Hogar",
      icono: Icons.weekend_rounded,
      subcategorias: ["Muebles", "Decoración", "Electrodomésticos"],
    ),
    Categoria(
      nombre: "Ocio",
      icono: Icons.sports_soccer_rounded,
      subcategorias: ["Deportes", "Juguetes", "Entretenimiento"],
    ),
    Categoria(
      nombre: "Mascotas",
      icono: Icons.pets_rounded,
      subcategorias: ["Alimentos", "Accesorios", "Servicios"],
    ),
  ];

  // ── INIT ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    await _iniciarSesion();
    await _cargarUsuario();
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
    setState(() => _tab = index);
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
          const SizedBox(width: 10),

          // Barra de búsqueda
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = 2),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppColors.divider, width: 0.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded,
                        color: AppColors.grayMid, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "Buscar en OkVenta...",
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.grayMid,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

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

  // ── BARRA DE CATEGORÍAS ────────────────────────────────────────────────────
  Widget _buildCategoryBar() {
    final catActual = _categorias.where(
      (c) => c.nombre == _categoriaSeleccionada,
    );
    final subcats =
        catActual.isNotEmpty ? catActual.first.subcategorias : <String>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Categorías principales
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            itemCount: _categorias.length,
            itemBuilder: (_, i) {
              final cat = _categorias[i];
              final selected = _categoriaSeleccionada == cat.nombre;
              return GestureDetector(
                onTap: () => setState(() {
                  _categoriaSeleccionada =
                      selected ? null : cat.nombre;
                  _subcategoriaSeleccionada = null;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          selected ? AppColors.primary : AppColors.divider,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icono,
                        size: 13,
                        color: selected ? Colors.white : AppColors.grayMid,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        cat.nombre,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Subcategorías (cuando hay categoría seleccionada)
        if (_categoriaSeleccionada != null && subcats.isNotEmpty)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 36,
            color: AppColors.background,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: subcats.length,
              itemBuilder: (_, i) {
                final sub = subcats[i];
                final selected = _subcategoriaSeleccionada == sub;
                return GestureDetector(
                  onTap: () => setState(() {
                    _subcategoriaSeleccionada = selected ? null : sub;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.carbon : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.carbon : AppColors.divider,
                        width: 0.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        sub,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
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
              _navItem(1, Icons.notifications_outlined, "Alertas"),
              _navItem(2, Icons.search_rounded, "Buscar"),
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
            key: ValueKey(
                "$_categoriaSeleccionada-$_subcategoriaSeleccionada"),
            categoriaFiltro: _categoriaSeleccionada,
            subcategoriaFiltro: _subcategoriaSeleccionada,
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
                child: const Text("Ingresar"),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_outlined,
              size: 64, color: AppColors.grayMid),
          const SizedBox(height: 16),
          const Text(
            "Sin notificaciones",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Cuando tengas actividad, aparecerá aquí",
            style: TextStyle(fontSize: 14, color: AppColors.grayMid),
          ),
        ],
      ),
    );
  }

  Widget _buildBuscar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo búsqueda
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: AppColors.grayMid, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "Buscar productos, marcas...",
                      hintStyle:
                          TextStyle(color: AppColors.grayMid, fontSize: 15),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) {
                      // TODO: implementar búsqueda
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            "Categorías",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Grid de categorías
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categorias.map((cat) {
              return GestureDetector(
                onTap: () => setState(() {
                  _tab = 0;
                  _categoriaSeleccionada = cat.nombre;
                  _subcategoriaSeleccionada = null;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.divider, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icono,
                          size: 20, color: AppColors.carbon),
                      const SizedBox(width: 10),
                      Text(
                        cat.nombre,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _buildInicio(),
                  _buildAlertas(),
                  _buildBuscar(),
                ],
              ),
            ),
            if (_tab == 0) _buildCategoryBar(),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }
}
