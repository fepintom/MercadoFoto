import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/registro_form_widget.dart';
import 'chat_screen.dart';
import 'compra_protegida_screen.dart';
import 'editar_publicacion_screen.dart';
import 'evaluaciones_vendedor_screen.dart';
import 'perfil_publico_screen.dart';
import 'soporte_chat_screen.dart';
import '../widgets/net_image.dart';
import '../widgets/reputacion_vendedor.dart';

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
  bool _comprando = false;
  final _ofertaController = TextEditingController();

  // Galería multi-imagen
  int _imgPagina = 0;
  late PageController _imgPageController;

  // Reputación del vendedor (estrellas junto al nombre)
  double _promedioVendedor = 0;
  int _totalReviewsVendedor = 0;
  int _productosVendidosVendedor = 0;

  // Productos relacionados (misma categoría), al final de la publicación
  List<dynamic> _relacionados = [];

  // Estimación de entrega según distancia comprador-vendedor
  String? _mensajeEntrega;

  @override
  void initState() {
    super.initState();
    _imgPageController = PageController();
    _cargarSesion();
    _cargarReputacionVendedor();
    _cargarRelacionados();
  }

  Future<void> _cargarRelacionados() async {
    final pubId = widget.producto["id"] as int?;
    if (pubId == null) return;
    final rel = await ApiService.obtenerProductosRelacionados(pubId);
    if (!mounted) return;
    setState(() => _relacionados = rel);
  }

  Future<void> _cargarReputacionVendedor() async {
    final vendedorId = widget.producto["user_id"] as int?;
    if (vendedorId == null) return;
    final rep = await ApiService.obtenerReputacion(vendedorId);
    if (!mounted) return;
    setState(() {
      _promedioVendedor = (rep['promedio'] as num?)?.toDouble() ?? 0;
      _totalReviewsVendedor = (rep['total_reviews'] as num?)?.toInt() ?? 0;
      _productosVendidosVendedor =
          (rep['productos_vendidos'] as num?)?.toInt() ?? 0;
    });
  }

  @override
  void dispose() {
    _imgPageController.dispose();
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
      _cargarEstimacionEntrega(id);
    }
  }

  // ── Estimación de entrega según distancia comprador-vendedor ────────────
  // Usa la ubicación principal guardada del comprador (no pide GPS en vivo)
  // y la ubicación de la publicación. < 20 km: puede recibirlo hoy;
  // >= 20 km: a partir de mañana. Si falta algún dato, no se muestra nada.
  Future<void> _cargarEstimacionEntrega(int compradorId) async {
    final pubLat = (widget.producto["lat"] as num?)?.toDouble();
    final pubLng = (widget.producto["lng"] as num?)?.toDouble();
    if (pubLat == null || pubLng == null) return;

    final ubicacion = await ApiService.obtenerUbicacionUsuario(compradorId);
    if (ubicacion == null || !mounted) return;
    final compradorLat = (ubicacion["lat"] as num?)?.toDouble();
    final compradorLng = (ubicacion["lng"] as num?)?.toDouble();
    if (compradorLat == null || compradorLng == null) return;

    final distanciaKm =
        _distanciaKm(compradorLat, compradorLng, pubLat, pubLng);
    setState(() {
      _mensajeEntrega = distanciaKm < 20
          ? "Puedes recibirlo hoy"
          : "Puedes recibirlo a partir de mañana";
    });
  }

  double _distanciaKm(double lat1, double lng1, double lat2, double lng2) {
    const radioTierraKm = 6371.0;
    double rad(double deg) => deg * (3.141592653589793 / 180);
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(rad(lat1)) * cos(rad(lat2)) * (sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return radioTierraKm * c;
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
        title: Text(
          'Perfil del vendedor',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary),
        ),
        content: RichText(
          text: TextSpan(
            style: TextStyle(
                fontSize: 14, color: colors.textSecondary, height: 1.4),
            children: [
              const TextSpan(text: '¿Ir al perfil de '),
              TextSpan(
                text: nombre,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary),
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
            child: Text('Cancelar',
                style: TextStyle(color: colors.grayMid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
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
        color: colors.textPrimary,
        label: "Copiar enlace",
        sublabel: "Copia el link del producto",
        accion: (ctx) async {
          Navigator.pop(ctx);
          await Clipboard.setData(ClipboardData(text: link));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Enlace copiado al portapapeles"),
              backgroundColor: colors.carbon,
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
          final waUrl = Uri.parse(
              "https://wa.me/?text=${Uri.encodeComponent(msgCompleto)}");
          try {
            await launchUrl(waUrl,
                mode: LaunchMode.externalApplication);
          } catch (_) {
            // Fallback: copiar al portapapeles
            await Clipboard.setData(ClipboardData(text: msgCompleto));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Mensaje copiado · Pégalo en WhatsApp"),
                backgroundColor: const Color(0xFF25D366),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
      ),
      _OpcionCompartir(
        icon: Icons.person_search_rounded,
        color: colors.primary,
        label: "Usuario OkVenta",
        sublabel: "Envía a un usuario de la app",
        accion: (ctx) async {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Próximamente disponible"),
              backgroundColor: colors.grayMid,
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
      backgroundColor: colors.surface,
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
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Compartir producto",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
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
                style: TextStyle(
                    fontSize: 13, color: colors.grayMid),
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
                      color: colors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: colors.divider, width: 0.5),
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
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                op.sublabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.grayMid,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 13, color: colors.grayMid),
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
      backgroundColor: colors.surface,
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
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "¿Qué deseas preguntar?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
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
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icono, color: colors.textPrimary, size: 22),
            const SizedBox(width: 14),
            Text(
              mensaje,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: colors.grayMid),
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
          backgroundColor: colors.carbon,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint("ERROR pregunta: $e");
    }
  }

  // ── COMPRAR CON MERCADOPAGO ────────────────────────────────────────────
  Future<void> _comprarConMP() async {
    if (userId == null) {
      _abrirRegistroModal();
      return;
    }
    if (_comprando) return;

    final pubId = widget.producto["id"] as int? ?? 0;
    final vendedorId = widget.producto["user_id"] as int? ?? 0;
    final titulo =
        _safeDecode(widget.producto["titulo"] as String? ?? "Producto");
    final monto =
        ((widget.producto["precio"] as num?)?.toDouble() ?? 0).toDouble();
    final imagenUrl = widget.producto["imagen_url"]?.toString() ?? "";

    if (monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('El precio del producto no es válido'),
            backgroundColor: colors.carbon),
      );
      return;
    }

    setState(() => _comprando = true);
    try {
      final data = await ApiService.crearPreferencia(
        compradorId: userId!,
        vendedorId: vendedorId,
        tipo: 'producto',
        titulo: titulo,
        monto: monto,
        publicacionId: pubId,
        imagenUrl: imagenUrl,
      );

      // ── Modo prueba: el pago ya quedó simulado como aprobado en el backend.
      // No hay checkout real que abrir — solo avisamos y listo.
      if (data['test_mode'] == true) {
        if (!mounted) return;
        await _mostrarConfirmacionTestMode();
        return;
      }

      final initPoint = data['init_point'] as String? ??
          data['sandbox_init_point'] as String? ??
          '';

      if (initPoint.isEmpty) throw Exception('No se obtuvo el link de pago');

      final uri = Uri.parse(initPoint);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir el navegador');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar el pago: $e'),
          backgroundColor: colors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _comprando = false);
    }
  }

  // ── Confirmación visual de compra simulada (modo prueba) ────────────────
  Future<void> _mostrarConfirmacionTestMode() {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.science_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Compra simulada (modo prueba)')),
          ],
        ),
        content: const Text(
          'No se realizó ningún cobro real. El vendedor ya fue notificado '
          'como si el pago hubiera sido aprobado, para que pruebes el flujo '
          'completo de entrega.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ── OFERTAR ────────────────────────────────────────────────────────────
  void _abrirOfertar() {
    _ofertaController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Hacer una oferta",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Precio publicado: ${formatPrecio(widget.producto["precio"])}",
              style: TextStyle(
                  fontSize: 13, color: colors.grayMid),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ofertaController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: "0",
                prefixText: "\$ ",
                prefixStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
                hintStyle: TextStyle(
                    color: colors.grayMid, fontSize: 22),
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: colors.divider, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: colors.divider, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: colors.primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar",
                style: TextStyle(color: colors.grayMid)),
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
                    backgroundColor: colors.primary,
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
              backgroundColor: colors.primary,
              foregroundColor: colors.textOnPrimary,
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
      barrierColor: colors.carbon.withOpacity(0.4),
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
                  color: colors.surface,
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
                            backgroundColor: colors.primary,
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
                            backgroundColor: colors.primary,
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

  // ── "Devolución gratis" — resumen corto con link a la política completa ──
  void _mostrarDevolucionGratis() {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.assignment_return_outlined,
                      size: 20, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Devolución gratis',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _puntoDevolucion(
                '10 días para arrepentirte', 'sin dar explicaciones, desde que recibes el producto.'),
            _puntoDevolucion('¿Te arrepentiste?',
                'el envío de vuelta lo pagas tú, como comprador.'),
            _puntoDevolucion('¿Llegó con defectos?',
                'el envío de vuelta lo paga el vendedor, sin costo para ti.'),
            _puntoDevolucion('Nuestros repartidores siempre cobran',
                'un viaje ejecutado se paga completo, sin importar quién asuma el costo del envío.'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CompraProtegidaScreen()),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Ver política completa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _puntoDevolucion(String titulo, String detalle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_circle_rounded,
                size: 14, color: Color(0xFF34C759)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 13, height: 1.4, color: colors.textPrimary),
                children: [
                  TextSpan(
                      text: '$titulo: ',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: detalle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Medios de pago aceptados ─────────────────────────────────────────────
  // Mini-tarjetas con la paleta de color de cada red y una marca gráfica
  // propia (no se reproduce el archivo/vector oficial de ninguna marca):
  // Mastercard usa sus dos círculos superpuestos —un símbolo genérico y muy
  // reconocible—, Visa un rótulo en itálica sobre su azul característico,
  // y Mercado Pago / Webpay su color de marca con su propio ícono.
  // "Transferencia" se sacó de esta lista a pedido — no es un medio con
  // logo propio y no aporta a esta sección.
  Widget _mediosDePago() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Medios de pago',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _tarjetaVisa(),
            _tarjetaMastercard(),
            _tarjetaMercadoPago(),
            _tarjetaWebpay(),
          ],
        ),
      ],
    );
  }

  BoxDecoration _decoracionMedioPago(Color color) => BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
        ),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      );

  // Tarjetas de medios de pago achicadas (~35-40% más chicas que antes) —
  // se dejó algo de margen sobre el 60% pedido porque a ese tamaño el
  // texto (VISA, Mercado/Pago, webpay) dejaba de leerse bien.
  Widget _tarjetaVisa() {
    const azulVisa = Color(0xFF1A1F71);
    return Container(
      width: 34,
      height: 24,
      alignment: Alignment.center,
      decoration: _decoracionMedioPago(azulVisa),
      child: const Text('VISA',
          style: TextStyle(
              fontSize: 9,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: Colors.white)),
    );
  }

  Widget _tarjetaMastercard() {
    return Container(
      width: 34,
      height: 24,
      alignment: Alignment.center,
      decoration: _decoracionMedioPago(const Color(0xFF232323)),
      child: SizedBox(
        width: 20,
        height: 12,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                    color: Color(0xFFEB001B), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: const Color(0xFFFF5F00).withOpacity(0.92),
                    shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaMercadoPago() {
    const azulMP = Color(0xFF00AEEF);
    return Container(
      width: 38,
      height: 28,
      alignment: Alignment.center,
      decoration: _decoracionMedioPago(azulMP),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // El logo real de Mercado Pago son dos manos dándose la mano.
          Icon(Icons.handshake_rounded, size: 10, color: Color(0xFFFFE600)),
          Text('Mercado',
              style: TextStyle(
                  fontSize: 6,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          Text('Pago',
              style: TextStyle(
                  fontSize: 6,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _tarjetaWebpay() {
    const azulWebpay = Color(0xFF2E3092);
    return Container(
      width: 38,
      height: 24,
      alignment: Alignment.center,
      decoration: _decoracionMedioPago(azulWebpay),
      child: const Text('webpay',
          style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
              color: Colors.white)),
    );
  }

  // ── Productos relacionados (misma categoría) ────────────────────────────
  Widget _productosRelacionados() {
    if (_relacionados.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('También te puede interesar',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _relacionados.length,
              itemBuilder: (_, i) {
                final p = _relacionados[i] as Map;
                final imagenUrl = p['imagen_url']?.toString() ?? '';
                final titulo = p['titulo']?.toString() ?? '';
                final precio = p['precio'];
                return GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductoDetalleScreen(
                          producto: Map<String, dynamic>.from(p),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: colors.divider, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: imagenUrl.isNotEmpty
                                ? NetImage(
                                    "${ApiService.baseUrl}$imagenUrl",
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                  )
                                : Container(
                                    color: colors.surface,
                                    child: Icon(Icons.image_outlined,
                                        color: colors.grayMid),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(titulo,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary)),
                              const SizedBox(height: 2),
                              if (precio != null)
                                Text(formatPrecio((precio as num).toDouble()),
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: colors.primary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Fila de información adicional (solo lectura) ───────────────────────
  Widget _filaInfoAdicional(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5, color: colors.grayMid)),
          ),
          Expanded(
            child: Text(valor,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary)),
          ),
        ],
      ),
    );
  }


  // ── Talla del paquete: badge compacto sobre la esquina de la foto ────────
  // Reemplaza la tarjeta grande de "dimensiones estimadas" (se sentía muy
  // invasiva) por una sola etiqueta chica, igual que "Principal"/"Nueva" en
  // otras pantallas.
  // Solo la ve el vendedor (dueño de la publicación): es un dato para
  // cuando le toque despachar el envío, no algo que el comprador necesite.
  Widget _tallaPaqueteBadge(dynamic dimensiones, bool esInvitado,
      {required bool esDueno}) {
    if (!esDueno) return const SizedBox.shrink();
    final tieneDimensiones = dimensiones != null &&
        dimensiones.toString().isNotEmpty &&
        dimensiones.toString() != "No determinado";
    if (!tieneDimensiones) return const SizedBox.shrink();

    return Positioned(
      bottom: 10,
      right: 12,
      child: GestureDetector(
        onTap: esInvitado ? _abrirRegistroModal : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: colors.carbon.withOpacity(0.78),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                esInvitado ? Icons.lock_outline_rounded : Icons.straighten_rounded,
                size: 12, color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                esInvitado ? "Talla del paquete" : dimensiones.toString(),
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
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
    final String condicion =
        widget.producto["condicion"] as String? ?? 'nuevo';
    final bool aceptaOfertas =
        (widget.producto["acepta_ofertas"] as int? ?? 1) == 1;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          "Detalle del producto",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          // Ayuda: agente de soporte
          IconButton(
            icon: Icon(Icons.help_outline_rounded,
                color: colors.textPrimary),
            tooltip: 'Ayuda',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SoporteChatScreen()),
              );
            },
          ),
          // Botón favorito
          _toggleandoFavorito
              ? Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.primary),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    _esFavorito ? Icons.favorite : Icons.favorite_border,
                    color: _esFavorito ? colors.primary : colors.textPrimary,
                  ),
                  onPressed: _toggleFavorito,
                  tooltip: _esFavorito ? "Quitar de favoritos" : "Guardar",
                ),
          IconButton(
            icon: Icon(Icons.share_outlined, color: colors.textPrimary),
            onPressed: _abrirCompartir,
            tooltip: "Compartir",
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: colors.divider, height: 0.5),
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
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: PageView.builder(
                          controller: _imgPageController,
                          itemCount: imagenes.length,
                          onPageChanged: (i) =>
                              setState(() => _imgPagina = i),
                          itemBuilder: (ctx, i) => GestureDetector(
                            onTap: () => _verFotoCompleta(imagenes, i),
                            child: ColoredBox(
                              color: Colors.white,
                              child: NetImage(
                                "${ApiService.baseUrl}${imagenes[i]}",
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _tallaPaqueteBadge(dimensiones, esInvitado, esDueno: esDueno),
                    ],
                  ),
                  // Dots de paginación
                  Container(
                    color: colors.background,
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
                                ? colors.primary
                                : colors.divider,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              )
            else
              Stack(
                children: [
                  GestureDetector(
                    onTap: () => _verFotoCompleta(imagenes, 0),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ColoredBox(
                        color: Colors.white,
                        child: NetImage(
                          "${ApiService.baseUrl}${imagenes.isNotEmpty ? imagenes[0] : ''}",
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  _tallaPaqueteBadge(dimensiones, esInvitado, esDueno: esDueno),
                ],
              ),

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges: condición + categoría + subcategoría
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // Condición
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: condicion == 'nuevo'
                                ? const Color(0xFF34C759).withOpacity(0.12)
                                : Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                condicion == 'nuevo'
                                    ? Icons.star_outline_rounded
                                    : Icons.recycling_rounded,
                                size: 11,
                                color: condicion == 'nuevo'
                                    ? const Color(0xFF34C759)
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                condicion == 'nuevo' ? 'Nuevo' : 'Usado',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: condicion == 'nuevo'
                                      ? const Color(0xFF34C759)
                                      : Colors.orange,
                                  shadows: const [
                                    Shadow(
                                        color: Colors.black26,
                                        blurRadius: 1.5,
                                        offset: Offset(0, 0.4)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Categoría
                        if (categoria != null &&
                            categoria.toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoria.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                                shadows: [
                                  Shadow(
                                      color: Colors.black26,
                                      blurRadius: 1.5,
                                      offset: Offset(0, 0.4)),
                                ],
                              ),
                            ),
                          ),
                        // Subcategoría — "Otros" no aporta nada como chip
                        // (p.ej. bajo "General"), así que se oculta.
                        if (subcategoria != null &&
                            subcategoria.toString().isNotEmpty &&
                            subcategoria.toString() != "Otros")
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: colors.divider, width: 0.5),
                            ),
                            child: Text(
                              subcategoria.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        // No acepta ofertas
                        if (!aceptaOfertas)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.grayMid.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.handshake_outlined,
                                    size: 11, color: colors.grayMid),
                                SizedBox(width: 4),
                                Text(
                                  'Sin ofertas/canjes',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: colors.grayMid,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Título
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
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
                              ? colors.textPrimary
                              : colors.grayMid,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          vendedor,
                          style: TextStyle(
                            fontSize: 13,
                            color: ownerId != null
                                ? colors.textPrimary
                                : colors.grayMid,
                            decoration: ownerId != null
                                ? TextDecoration.underline
                                : TextDecoration.none,
                            decorationColor: colors.textPrimary,
                          ),
                        ),
                        if (ownerId != null) ...[
                          const SizedBox(width: 3),
                          Icon(Icons.chevron_right_rounded,
                              size: 14,
                              color: colors.textPrimary.withOpacity(0.5)),
                        ],
                        if (ownerId != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: GestureDetector(
                              onTap: () {
                                final vendedorId =
                                    widget.producto["user_id"] as int?;
                                if (vendedorId == null) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EvaluacionesVendedorScreen(
                                      vendedorId: vendedorId,
                                      nombreVendedor: vendedor,
                                    ),
                                  ),
                                );
                              },
                              child: EstrellasResumen(
                                promedio: _promedioVendedor,
                                totalReviews: _totalReviewsVendedor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Productos vendidos por el vendedor + stock disponible
                  if ((ownerId != null && _productosVendidosVendedor > 0) ||
                      widget.producto['stock'] != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (ownerId != null && _productosVendidosVendedor > 0)
                          Text(
                            '$_productosVendidosVendedor '
                            '${_productosVendidosVendedor == 1 ? "producto vendido" : "productos vendidos"}',
                            style: TextStyle(
                                fontSize: 12, color: colors.grayMid),
                          ),
                        if (ownerId != null &&
                            _productosVendidosVendedor > 0 &&
                            widget.producto['stock'] != null)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text('|',
                                style: TextStyle(
                                    fontSize: 12, color: colors.divider)),
                          ),
                        if (widget.producto['stock'] != null)
                          Text(
                            'Stock: ${widget.producto['stock']}',
                            style: TextStyle(
                                fontSize: 12, color: colors.grayMid),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Precio
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: colors.divider, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatPrecio(precio),
                          style: TextStyle(
                            fontSize: 28,
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_mensajeEntrega != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded,
                            size: 15, color: Color(0xFF34C759)),
                        const SizedBox(width: 5),
                        Text(_mensajeEntrega!,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF34C759))),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 16),

                  // Descripción
                  Text(
                    descripcion,
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.textSecondary,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Medios de pago aceptados
                  _mediosDePago(),

                  const SizedBox(height: 16),

                  // Devolución gratis + Compra protegida
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _mostrarDevolucionGratis,
                          child: Row(
                            children: [
                              Icon(Icons.assignment_return_outlined,
                                  size: 15, color: colors.grayMid),
                              SizedBox(width: 5),
                              Flexible(
                                child: Text("Devolución gratis",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: colors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                        decoration:
                                            TextDecoration.underline,
                                        decorationColor:
                                            colors.grayMid)),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded,
                                  size: 15, color: colors.grayMid),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CompraProtegidaScreen()),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_outlined,
                                size: 15, color: colors.primary),
                            SizedBox(width: 5),
                            Text("Compra protegida",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline)),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right_rounded,
                                size: 15, color: colors.primary),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Información adicional — siempre de solo lectura aquí.
                  // El dueño la edita desde "Editar publicación" (un solo
                  // lugar para editar, en vez de duplicar la edición aquí).
                  if ((((widget.producto['sku']?.toString() ?? '').isNotEmpty) ||
                          widget.producto['stock'] != null ||
                          ((widget.producto['codigo_universal']?.toString() ?? '')
                              .isNotEmpty)))
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: colors.divider, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 16, color: colors.grayMid),
                              SizedBox(width: 6),
                              Text(
                                "Información adicional",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if ((widget.producto['codigo_universal']
                                      ?.toString() ??
                                  '')
                              .isNotEmpty)
                            _filaInfoAdicional("Código universal",
                                widget.producto['codigo_universal'].toString()),
                          if ((widget.producto['sku']?.toString() ?? '')
                              .isNotEmpty)
                            _filaInfoAdicional(
                                "SKU", widget.producto['sku'].toString()),
                          if (widget.producto['stock'] != null)
                            _filaInfoAdicional("Stock disponible",
                                widget.producto['stock'].toString()),
                        ],
                      ),
                    ),

                  const SizedBox(height: 28),

                  // ── BOTONES ACCIÓN ─────────────────────────────────

                  // Invitado
                  if (esInvitado)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _abrirRegistroModal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.textOnPrimary,
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
                                  foregroundColor: colors.textPrimary,
                                  side: BorderSide(
                                      color: colors.textPrimary, width: 1),
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
                                  foregroundColor: colors.textPrimary,
                                  side: BorderSide(
                                      color: colors.textPrimary, width: 1),
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
                            if (aceptaOfertas) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _abrirOfertar,
                                  icon: const Icon(
                                      Icons.local_offer_rounded, size: 16),
                                  label: const Text("Ofertar"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.carbon,
                                    foregroundColor: colors.textOnPrimary,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Botón de compra — antes decía "Pagar con
                        // MercadoPago" en el azul de esa marca; ahora usa
                        // el rojo principal de OkVenta y el texto es
                        // "Comprar" (MercadoPago sigue siendo el medio de
                        // pago por debajo, solo que ya no hace falta
                        // nombrarlo en el botón). Se sacó el botón "Quiero
                        // comprar": llevaba al mismo chat que el botón
                        // "Chat" de arriba, era redundante.
                        Row(
                          children: [
                            Expanded(
                              child: ValueListenableBuilder<
                                  List<Map<String, dynamic>>>(
                                valueListenable: CartService.cartNotifier,
                                builder: (_, __, ___) {
                                  final pubId =
                                      widget.producto["id"] as int?;
                                  final enCarro =
                                      CartService.contiene(pubId);
                                  return OutlinedButton.icon(
                                    onPressed: () {
                                      final agregado = CartService.addProducto(
                                          Map<String, dynamic>.from(
                                              widget.producto));
                                      ScaffoldMessenger.of(context)
                                          .clearSnackBars();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(agregado
                                            ? "Agregado al carro"
                                            : "Ya estaba en tu carro"),
                                        backgroundColor: colors.carbon,
                                        behavior: SnackBarBehavior.floating,
                                        duration:
                                            const Duration(seconds: 2),
                                      ));
                                    },
                                    icon: Icon(
                                        enCarro
                                            ? Icons.check_rounded
                                            : Icons.add_shopping_cart_rounded,
                                        size: 17),
                                    label: Text(enCarro
                                        ? "En tu carro"
                                        : "Agregar al carro"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: colors.primary,
                                      side: BorderSide(
                                          color: colors.primary),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      textStyle: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _comprando ? null : _comprarConMP,
                                icon: _comprando
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.shopping_bag_rounded,
                                        size: 18),
                                label: const Text("Comprar"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
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
                              backgroundColor: colors.carbon,
                              foregroundColor: colors.textOnPrimary,
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
                                backgroundColor: colors.surface,
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
                                          color: colors.divider,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Icon(Icons.delete_outline,
                                          size: 44, color: colors.primary),
                                      const SizedBox(height: 12),
                                      Text(
                                        "¿Eliminar esta publicación?",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: colors.textPrimary),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Esta acción no se puede deshacer.",
                                        style: TextStyle(
                                            color: colors.grayMid,
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
                                                side: BorderSide(
                                                    color: colors.divider),
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
                                                    colors.primary,
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
                                    backgroundColor: colors.carbon,
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
                              foregroundColor: colors.primary,
                              side: BorderSide(
                                  color: colors.primary, width: 1),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Productos relacionados: fuera del padding de 20px para que
            // el carrusel horizontal pueda usar todo el ancho.
            _productosRelacionados(),
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
