import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/registro_form_widget.dart';
import 'chat_screen.dart';
import 'editar_publicacion_screen.dart';
import 'perfil_publico_screen.dart';

// ── Modelo para opciones de compartir (fácil de extender) ─────────────────
class _OpcionCompartir {
  final IconData icon;
  final Color color;
  final String label;
  final String sublabel;
  final Future<void> Function(BuildContext ctx) accion;

  const _OpcionCompartir({
    required this.icon,
    required this.color,
    required this.label,
    required this.sublabel,
    required this.accion,
  });
}

class ProductoDetalleScreen extends StatefulWidget {
  final Map producto;

  const ProductoDetalleScreen({super.key, required this.producto});

  @override
  State<ProductoDetalleScreen> createState() =>
      _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen> {
  int? userId;
  bool _esFavorito = false;
  bool _toggleandoFavorito = false;
  bool _registrandoInteres = false;
  bool _campoEstado = false;
  bool _campoCodigo = false;
  bool _campoSKU = false;
  bool _campoStock = false;

  final _estadoController = TextEditingController();
  final _codigoController = TextEditingController();
  final _skuController = TextEditingController();
  final _stockController = TextEditingController();
  final _ofertaController = TextEditingController();

  // Galería multi-imagen
  int _imgPagina = 0;
  late PageController _imgPageController;

  @override
  void initState() {
    super.initState();
    _imgPageController = PageController();
    _cargarSesion();
  }

  @override
  void dispose() {
    _imgPageController.dispose();
    _estadoController.dispose();
    _codigoController.dispose();
    _skuController.dispose();
    _stockController.dispose();
    _ofertaController.dispose();
    super.dispose();
  }

  Future<void> _cargarSesion() async {
    final id = await SessionService.obtenerUser();
    if (!mounted) return;
    setState(() => userId = id);
    if (id != null) {
      final pubId = widget.producto["id"] as int?;
      if (pubId != null) {
        final fav = await ApiService.esFavorito(id, pubId);
        if (!mounted) return;
        setState(() => _esFavorito = fav);
      }
    }
  }

  Future<void> _toggleFavorito() async {
    if (userId == null) {
      _abrirRegistroModal();
      return;
    }
    final pubId = widget.producto["id"] as int?;
    if (pubId == null || _toggleandoFavorito) return;
    setState(() => _toggleandoFavorito = true);
    try {
      if (_esFavorito) {
        await ApiService.quitarFavorito(userId!, pubId);
      } else {
        await ApiService.guardarFavorito(userId!, pubId);
      }
      if (!mounted) return;
      setState(() => _esFavorito = !_esFavorito);
    } catch (e) {
      debugPrint("ERROR favorito: $e");
    } finally {
      if (mounted) setState(() => _toggleandoFavorito = false);
    }
  }

  void _abrirChat() {
    if (userId == null) {
      _abrirRegistroModal();
      return;
    }
    final pubId = widget.producto["id"] as int? ?? 0;
    final vendedorId = widget.producto["user_id"] as int? ?? 0;
    final titulo = _safeDecode(widget.producto["titulo"] ?? "Producto");
    final imagenUrl = widget.producto["imagen_url"]?.toString() ?? "";
    final nombreVendedor =
        widget.producto["nombre_vendedor"]?.toString() ?? "Vendedor";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          publicacionId: pubId,
          tituloProducto: titulo,
          imagenUrl: imagenUrl,
          vendedorId: vendedorId,
          nombreVendedor: nombreVendedor,
        ),
      ),
    );
  }

  Future<void> _registrarInteres() async {
    if (userId == null) {
      _abrirRegistroModal();
      return;
    }
    final pubId = widget.producto["id"] as int?;
    if (pubId == null || _registrandoInteres) return;

    setState(() => _registrandoInteres = true);
    try {
      await ApiService.registrarInteres(
        publicacionId: pubId,
        compradorId: userId!,
      );
      if (!mounted) return;
      _mostrarConfirmacionInteres();
    } catch (e) {
      debugPrint("ERROR interes: $e");
    } finally {
      if (mounted) setState(() => _registrandoInteres = false);
    }
  }

  void _mostrarConfirmacionInteres() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  size: 32, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 16),
            const Text(
              "¡Interés registrado!",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              "Le avisamos al vendedor que quieres este producto. Puedes coordinar los detalles por chat.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.grayMid, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _abrirChat();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Ir al chat",
                    style: TextStyle(
                        color: AppColors.textOnPrimary,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _safeDecode(String text) {
    try {
      return utf8.decode(text.codeUnits);
    } catch (_) {
      return text;
    }
  }

  // ── Imágenes del producto ─────────────────────────────────────────────
  List<String> _getImagenes() {
    final urls = <String>[];
    final main = widget.producto["imagen_url"]?.toString() ?? "";
    if (main.isNotEmpty) urls.add(main);

    final extra = widget.producto["imagenes_extra"];
    if (extra != null && extra.toString().isNotEmpty) {
      try {
        final list = jsonDecode(extra.toString()) as List;
        urls.addAll(
          list.map((e) => e.toString()).where((s) => s.isNotEmpty),
        );
      } catch (_) {}
    }
    return urls;
  }

  // ── VISOR FOTO COMPLETA ───────────────────────────────────────────────
  // ── Perfil público del vendedor ──────────────────────────────────────────
  void _irAPerfilVendedor(
      BuildContext context, int userId, String nombre) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Perfil del vendedor',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            children: [
              const TextSpan(text: '¿Ir al perfil de '),
              TextSpan(
                text: nombre,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.grayMid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PerfilPublicoScreen(
                    userId: userId,
                    nombre: nombre,
                  ),
                ),
              );
            },
            child: const Text('Ver perfil'),
          ),
        ],
      ),
    );
  }

  void _verFotoCompleta(List<String> imagenes, int indiceInicial) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        barrierDismissible: false,
        pageBuilder: (_, animation, __) {
          return _FotoViewer(
            imagenes: imagenes,
            indiceInicial: indiceInicial,
            baseUrl: ApiService.baseUrl,
            animation: animation,
          );
        },
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  // ── COMPARTIR ─────────────────────────────────────────────────────────
  void _abrirCompartir() {
    final titulo = _safeDecode(widget.producto["titulo"] ?? "Producto");
    final id = widget.producto["id"];
    // URL base — reemplazar con dominio real en producción
    final link = "https://okventa.app/producto/$id";
    final msgCompleto = "¡Mira este producto en OkVenta!\n$titulo\n$link";

    // Lista extensible de opciones — agregar nuevas aquí en el futuro
    final opciones = <_OpcionCompartir>[
      _OpcionCompartir(
        icon: Icons.link_rounded,
        color: AppColors.carbon,
        label: "Copiar enlace",
        sublabel: "Copia el link del producto",
        accion: (ctx) async {
          Navigator.pop(ctx);
          await Clipboard.setData(ClipboardData(text: link));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Enlace copiado al portapapeles"),
              backgroundColor: AppColors.carbon,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
      ),
      _OpcionCompartir(
        icon: Icons.chat_rounded,
        color: const Color(0xFF25D366), // WhatsApp green
        label: "WhatsApp",
        sublabel: "Envía el producto por WhatsApp",
        accion: (ctx) async {
          Navigator.pop(ctx);
          // Copia el mensaje — integrar url_launcher aquí en el futuro:
          // final url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(msgCompleto)}");
          // await launchUrl(url, mode: LaunchMode.externalApplication);
          await Clipboard.setData(ClipboardData(text: msgCompleto));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  "Mensaje copiado · Pégalo en WhatsApp"),
              backgroundColor: const Color(0xFF25D366),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
      ),
      _OpcionCompartir(
        icon: Icons.person_search_rounded,
        color: AppColors.primary,
        label: "Usuario OkVenta",
        sublabel: "Envía a un usuario de la app",
        accion: (ctx) async {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Próximamente disponible"),
              backgroundColor: AppColors.grayMid,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
      ),
      // ↑ Agregar más opciones aquí (Instagram, Telegram, email, etc.)
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
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

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Compartir producto",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _safeDecode(titulo),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.grayMid),
              ),
            ),

            const SizedBox(height: 20),

            ...opciones.map(
              (op) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => op.accion(sheetCtx),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.divider, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: op.color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(op.icon,
                              color: op.color, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                op.label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                op.sublabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grayMid,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 13, color: AppColors.grayMid),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PREGUNTAR ──────────────────────────────────────────────────────────
  void _abrirPreguntar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "¿Qué deseas preguntar?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _preguntaOpcion(
                  "¿Sigue disponible?", Icons.check_circle_outline_rounded),
              const SizedBox(height: 8),
              _preguntaOpcion(
                  "¿Aceptas trueque?", Icons.swap_horiz_rounded),
            ],
          ),
        );
      },
    );
  }

  Widget _preguntaOpcion(String mensaje, IconData icono) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        await _enviarPregunta(mensaje);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icono, color: AppColors.carbon, size: 22),
            const SizedBox(width: 14),
            Text(
              mensaje,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.grayMid),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarPregunta(String mensaje) async {
    try {
      final id = widget.producto["id"];
      await http.post(
        Uri.parse("${ApiService.baseUrl}/preguntar"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "publicacion_id": id,
          "mensaje": mensaje,
          "user_id": userId,
        }),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Pregunta enviada: \"$mensaje\""),
          backgroundColor: AppColors.carbon,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint("ERROR pregunta: $e");
    }
  }

  // ── OFERTAR ────────────────────────────────────────────────────────────
  void _abrirOfertar() {
    _ofertaController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Hacer una oferta",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Precio publicado: ${formatPrecio(widget.producto["precio"])}",
              style: const TextStyle(
                  fontSize: 13, color: AppColors.grayMid),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ofertaController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: "0",
                prefixText: "\$ ",
                prefixStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                hintStyle: const TextStyle(
                    color: AppColors.grayMid, fontSize: 22),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.divider, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.divider, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar",
                style: TextStyle(color: AppColors.grayMid)),
          ),
          ElevatedButton(
            onPressed: () async {
              final t = _ofertaController.text.trim();
              if (t.isEmpty) return;
              final oferta = double.tryParse(t);
              if (oferta == null || oferta <= 0) return;
              Navigator.pop(context);
              try {
                await http.post(
                  Uri.parse("${ApiService.baseUrl}/ofertar"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "publicacion_id": widget.producto["id"],
                    "comprador_id": userId,
                    "monto": oferta,
                  }),
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Oferta de \$$t enviada al vendedor"),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              } catch (e) {
                debugPrint("ERROR oferta: $e");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Ofertar",
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── MODAL REGISTRO ─────────────────────────────────────────────────────
  void _abrirRegistroModal() {
    showDialog(
      context: context,
      barrierColor: AppColors.carbon.withOpacity(0.4),
      builder: (_) => GestureDetector(
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
                  onSubmit: (email, password) async {
                    try {
                      await AuthService.registrarConEmail(email, password);
                      if (!mounted) return;
                      Navigator.pop(context);
                      await _cargarSesion();
                    } catch (e) {
                      final msg = AuthService.mensajeError(e);
                      if (msg.isNotEmpty && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    }
                  },
                  onGoogleSignIn: () async {
                    try {
                      await AuthService.loginConGoogle();
                      if (!mounted) return;
                      Navigator.pop(context);
                      await _cargarSesion();
                    } catch (e) {
                      final msg = AuthService.mensajeError(e);
                      if (msg.isNotEmpty && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── CAMPO EXPANDIBLE ───────────────────────────────────────────────────
  Widget _campoExpandible({
    required String titulo,
    required bool abierto,
    required VoidCallback toggle,
    TextEditingController? controller,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: toggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Icon(
                  abierto ? Icons.remove_rounded : Icons.add_rounded,
                  color: AppColors.grayMid,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (abierto)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: controller,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.divider, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.divider, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        const Divider(height: 1, thickness: 0.5),
      ],
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final imagenes = _getImagenes();
    final titulo =
        _safeDecode(widget.producto["titulo"] ?? "");
    final descripcion =
        _safeDecode(widget.producto["descripcion"] ?? "");
    final precio = widget.producto["precio"] ?? 0;
    final dimensiones = widget.producto["dimensiones"];
    final categoria = widget.producto["categoria"];
    final subcategoria = widget.producto["subcategoria"];
    final vendedor =
        widget.producto["nombre_vendedor"] ?? "Usuario invitado";

    final int? ownerId = widget.producto["user_id"];
    final bool esInvitado = userId == null;
    final bool esDueno =
        userId != null && userId == ownerId && ownerId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Detalle del producto",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.carbon),
        actions: [
          // Botón favorito
          _toggleandoFavorito
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    _esFavorito ? Icons.favorite : Icons.favorite_border,
                    color: _esFavorito ? AppColors.primary : AppColors.carbon,
                  ),
                  onPressed: _toggleFavorito,
                  tooltip: _esFavorito ? "Quitar de favoritos" : "Guardar",
                ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.carbon),
            onPressed: _abrirCompartir,
            tooltip: "Compartir",
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppColors.divider, height: 0.5),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Galería de imágenes ─────────────────────────────────
            if (imagenes.length > 1)
              Column(
                children: [
                  SizedBox(
                    height: 300,
                    child: PageView.builder(
                      controller: _imgPageController,
                      itemCount: imagenes.length,
                      onPageChanged: (i) =>
                          setState(() => _imgPagina = i),
                      itemBuilder: (ctx, i) => GestureDetector(
                        onTap: () => _verFotoCompleta(imagenes, i),
                        child: Image.network(
                          "${ApiService.baseUrl}${imagenes[i]}",
                          height: 300,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 300,
                            color: AppColors.background,
                            child: const Icon(Icons.image_not_supported,
                                color: AppColors.grayMid, size: 48),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Dots de paginación
                  Container(
                    color: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(imagenes.length, (i) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _imgPagina ? 20 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _imgPagina
                                ? AppColors.primary
                                : AppColors.divider,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: () => _verFotoCompleta(imagenes, 0),
                child: Image.network(
                  "${ApiService.baseUrl}${imagenes.isNotEmpty ? imagenes[0] : ''}",
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 300,
                    color: AppColors.background,
                    child: const Icon(Icons.image_not_supported,
                        color: AppColors.grayMid, size: 48),
                  ),
                ),
              ),

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categoría badge
                  if (categoria != null &&
                      categoria.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoria.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          if (subcategoria != null &&
                              subcategoria.toString().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppColors.divider,
                                    width: 0.5),
                              ),
                              child: Text(
                                subcategoria.toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Título
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Vendedor — tappable si tiene user_id
                  GestureDetector(
                    onTap: ownerId != null
                        ? () => _irAPerfilVendedor(
                            context, ownerId!, vendedor)
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ownerId != null
                              ? Icons.verified_user_rounded
                              : Icons.person_outline_rounded,
                          size: 14,
                          color: ownerId != null
                              ? AppColors.carbon
                              : AppColors.grayMid,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          vendedor,
                          style: TextStyle(
                            fontSize: 13,
                            color: ownerId != null
                                ? AppColors.carbon
                                : AppColors.grayMid,
                            decoration: ownerId != null
                                ? TextDecoration.underline
                                : TextDecoration.none,
                            decorationColor: AppColors.carbon,
                          ),
                        ),
                        if (ownerId != null) ...[
                          const SizedBox(width: 3),
                          Icon(Icons.chevron_right_rounded,
                              size: 14,
                              color: AppColors.carbon.withOpacity(0.5)),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Precio
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.divider, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatPrecio(precio),
                          style: const TextStyle(
                            fontSize: 28,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 16),

                  // Descripción
                  Text(
                    descripcion,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Dimensiones (usuarios registrados)
                  if (!esInvitado &&
                      dimensiones != null &&
                      dimensiones.toString().isNotEmpty &&
                      dimensiones.toString() != "No determinado")
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.divider, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.straighten_rounded,
                              size: 18, color: AppColors.grayMid),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Dimensiones estimadas",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.grayMid,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dimensiones.toString(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  if (esInvitado &&
                      dimensiones != null &&
                      dimensiones.toString().isNotEmpty &&
                      dimensiones.toString() != "No determinado")
                    GestureDetector(
                      onTap: _abrirRegistroModal,
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.divider, width: 0.5),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                size: 18, color: AppColors.grayMid),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Regístrate para ver las dimensiones del producto",
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.grayMid),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Info adicional — solo visible para el dueño
                  if (esDueno) ...[
                    const Text(
                      "Información adicional",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _campoExpandible(
                      titulo: "Nuevo / Usado",
                      abierto: _campoEstado,
                      controller: _estadoController,
                      toggle: () =>
                          setState(() => _campoEstado = !_campoEstado),
                    ),
                    _campoExpandible(
                      titulo: "Código universal",
                      abierto: _campoCodigo,
                      controller: _codigoController,
                      toggle: () =>
                          setState(() => _campoCodigo = !_campoCodigo),
                    ),
                    _campoExpandible(
                      titulo: "SKU",
                      abierto: _campoSKU,
                      controller: _skuController,
                      toggle: () =>
                          setState(() => _campoSKU = !_campoSKU),
                    ),
                    _campoExpandible(
                      titulo: "Stock",
                      abierto: _campoStock,
                      controller: _stockController,
                      toggle: () =>
                          setState(() => _campoStock = !_campoStock),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── BOTONES ACCIÓN ─────────────────────────────────

                  // Invitado
                  if (esInvitado)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _abrirRegistroModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.surface,
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                            "Registrarse para contactar",
                            style: TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),

                  // Comprador registrado
                  if (!esInvitado && !esDueno)
                    Column(
                      children: [
                        // Fila: Chat + Preguntar + Ofertar
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _abrirChat,
                                icon: const Icon(Icons.chat_rounded, size: 16),
                                label: const Text("Chat"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.carbon,
                                  side: const BorderSide(
                                      color: AppColors.carbon, width: 1),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _abrirPreguntar,
                                icon: const Icon(
                                    Icons.help_outline_rounded, size: 16),
                                label: const Text("Preguntar"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.carbon,
                                  side: const BorderSide(
                                      color: AppColors.carbon, width: 1),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _abrirOfertar,
                                icon: const Icon(
                                    Icons.local_offer_rounded, size: 16),
                                label: const Text("Ofertar"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.carbon,
                                  foregroundColor: AppColors.surface,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Botón principal: Quiero comprar
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _registrandoInteres ? null : _registrarInteres,
                            icon: _registrandoInteres
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Icon(
                                    Icons.shopping_cart_checkout_rounded,
                                    size: 18),
                            label: const Text("Quiero comprar"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.surface,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Dueño
                  if (esDueno)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditarPublicacionScreen(
                                    producto: Map<String, dynamic>.from(
                                        widget.producto),
                                  ),
                                ),
                              );
                              if (result == true) {
                                if (!mounted) return;
                                Navigator.pop(context, true);
                              }
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text("Editar publicación"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.carbon,
                              foregroundColor: AppColors.surface,
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final confirmar =
                                  await showModalBottomSheet<bool>(
                                context: context,
                                backgroundColor: AppColors.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20)),
                                ),
                                builder: (_) => Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 40, height: 4,
                                        decoration: BoxDecoration(
                                          color: AppColors.divider,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      const Icon(Icons.delete_outline,
                                          size: 44, color: AppColors.primary),
                                      const SizedBox(height: 12),
                                      const Text(
                                        "¿Eliminar esta publicación?",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        "Esta acción no se puede deshacer.",
                                        style: TextStyle(
                                            color: AppColors.grayMid,
                                            fontSize: 13),
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                    color: AppColors.divider),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 14),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                              ),
                                              child: const Text("Cancelar",
                                                  style: TextStyle(
                                                      color: AppColors
                                                          .textSecondary)),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.primary,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 14),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                              ),
                                              child: const Text("Eliminar",
                                                  style: TextStyle(
                                                      color: AppColors
                                                          .textOnPrimary)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              if (confirmar != true || !mounted) return;
                              final nav = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await ApiService.eliminarPublicacion(
                                  widget.producto["id"] as int,
                                  userId: userId,
                                );
                              } catch (e) {
                                // Mostramos el error pero igualmente volvemos
                                // — el producto ya no existe o hay error de red
                                if (mounted) {
                                  messenger.showSnackBar(SnackBar(
                                    content: Text("Aviso: $e"),
                                    backgroundColor: AppColors.carbon,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ));
                                }
                              } finally {
                                // Siempre salimos y recargamos la lista
                                if (mounted) nav.pop(true);
                              }
                            },
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18),
                            label: const Text("Eliminar publicación"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                  color: AppColors.primary, width: 1),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISOR DE FOTO A PANTALLA COMPLETA
// ─────────────────────────────────────────────────────────────────────────────

class _FotoViewer extends StatefulWidget {
  final List<String> imagenes;
  final int indiceInicial;
  final String baseUrl;
  final Animation<double> animation;

  const _FotoViewer({
    required this.imagenes,
    required this.indiceInicial,
    required this.baseUrl,
    required this.animation,
  });

  @override
  State<_FotoViewer> createState() => _FotoViewerState();
}

class _FotoViewerState extends State<_FotoViewer> {
  late PageController _pageCtrl;
  late int _paginaActual;
  // TransformationController por página para resetear el zoom al cambiar
  final Map<int, TransformationController> _transformControllers = {};

  @override
  void initState() {
    super.initState();
    _paginaActual = widget.indiceInicial;
    _pageCtrl     = PageController(initialPage: widget.indiceInicial);
    // Ocultar barra de estado para inmersión total
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _transformControllers.values) {
      c.dispose();
    }
    // Restaurar UI del sistema al salir
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  TransformationController _ctrlForPage(int index) {
    return _transformControllers.putIfAbsent(
        index, () => TransformationController());
  }

  void _cerrar() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── PageView con InteractiveViewer por foto ──────────────────
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.imagenes.length,
            onPageChanged: (i) {
              // Resetear zoom de la página anterior
              _ctrlForPage(_paginaActual).value = Matrix4.identity();
              setState(() => _paginaActual = i);
            },
            itemBuilder: (_, i) {
              return InteractiveViewer(
                transformationController: _ctrlForPage(i),
                minScale: 0.8,
                maxScale: 5.0,
                child: Center(
                  child: Image.network(
                    "${widget.baseUrl}${widget.imagenes[i]}",
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: Colors.white54,
                          strokeWidth: 2,
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white38, size: 64),
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Botón cerrar ──────────────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: _cerrar,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),

          // ── Contador (solo si hay más de 1 foto) ─────────────────────
          if (widget.imagenes.length > 1)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${_paginaActual + 1} / ${widget.imagenes.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Dots de navegación ────────────────────────────────────────
          if (widget.imagenes.length > 1)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.imagenes.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _paginaActual ? 20 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _paginaActual
                          ? Colors.white
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
