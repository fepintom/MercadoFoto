import 'package:flutter/material.dart';

import '../screens/producto_detalle_screen.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../services/vistas_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'net_image.dart';

/// Franja "🔥 Más vendidos · Top 5 del mes" de Comunidad: tarjetitas
/// horizontales (#puesto, foto, nombre, precio) sobre un recuadro rojo
/// suave, con puntitos que indican la página. Si todavía no hay ventas en
/// el mes, el título pasa a "Lo más visto".
class MasVendidosFranja extends StatefulWidget {
  final int version;

  /// Sin encabezado ni recuadro (el título lo pone quien la usa, p. ej. la
  /// barra "🔥 TOP" de Comunidad): solo las tarjetitas, para ahorrar alto.
  final bool compacta;
  const MasVendidosFranja({super.key, this.version = 0, this.compacta = false});

  @override
  State<MasVendidosFranja> createState() => _MasVendidosFranjaState();
}

class _MasVendidosFranjaState extends State<MasVendidosFranja> {
  List<Map<String, dynamic>>? _items;
  final _scroll = ScrollController();
  int _pagina = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      final p = max <= 0
          ? 0
          : ((_scroll.offset / max) * (_paginas - 1)).round();
      if (p != _pagina) setState(() => _pagina = p);
    });
  }

  @override
  void didUpdateWidget(covariant MasVendidosFranja old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version) _cargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int get _paginas => ((_items?.length ?? 0) / 2).ceil().clamp(1, 10);

  Future<void> _cargar() async {
    // "Lo más buscado" de Comunidad: los 10 más vistos (empates: el que
    // llegó primero a esas vistas). La franja grande sigue con ventas.
    final l = widget.compacta
        ? await VistasService.topProductos(limite: 10)
        : await VistasService.masVendidos(limite: 5);
    if (mounted) setState(() => _items = l);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final porVentas = items.any((p) => p['origen'] == 'ventas');
    final tarjetas = SizedBox(
      height: widget.compacta ? TarjetaMini.alto : 62,
      child: LayoutBuilder(builder: (context, c) {
        // ~2,6 tarjetas a la vista: se nota que hay más.
        final ancho = widget.compacta
            ? TarjetaMini.anchoPara(c.maxWidth)
            : (c.maxWidth - 16) / 2.6;
        return ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: widget.compacta
              ? const EdgeInsets.symmetric(horizontal: 12)
              : EdgeInsets.zero,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => _tarjeta(items[i], i + 1, ancho),
        );
      }),
    );
    if (widget.compacta) {
      return Container(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        color: colors.background,
        child: tarjetas,
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: colors.primary.withValues(alpha: 0.45), width: 1.2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.primary.withValues(alpha: 0.13),
            colors.primary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.local_fire_department_rounded,
                color: colors.primary, size: 24),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(porVentas ? 'Más vendidos' : 'Lo más visto',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: colors.primary)),
                Text('Top ${items.length} del mes',
                    style:
                        TextStyle(fontSize: 11, color: colors.textPrimary)),
              ],
            ),
            const Spacer(),
            for (var i = 0; i < _paginas; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 4),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _pagina
                      ? colors.primary
                      : colors.textPrimary.withValues(alpha: 0.25),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          tarjetas,
        ],
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> p, int puesto, double ancho) {
    final img = (p['imagen_url'] ?? '').toString();
    if (widget.compacta) {
      return TarjetaMini(
        ancho: ancho,
        imagenUrl: img,
        titulo: (p['titulo'] ?? '').toString(),
        precio: formatPrecio(p['precio']),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: p)),
        ).then((_) => _cargar()),
      );
    }
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: p)),
      ).then((_) => _cargar()),
      child: Container(
        width: ancho,
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: puesto == 1
                      ? colors.primary
                      : const Color(0xFF3A3A3C),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('#$puesto',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(width: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: NetImage(
              img.startsWith('http') ? img : '${ApiService.baseUrl}$img',
              width: 38,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((p['titulo'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatPrecio(p['precio']),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: colors.primary)),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}


/// Tarjetita de la franja de Comunidad ("Lo más buscado" y "Fijados"):
/// mismo ancho y alto en las dos, para que se vean parejas. La foto va en
/// su recuadro; si está fijada, el pin va montado en la esquina de la foto
/// (no al lado, así no agranda la tarjeta).
class TarjetaMini extends StatelessWidget {
  static const double alto = 66;

  /// ~3 tarjetas a la vista (se nota que hay más).
  static double anchoPara(double anchoFranja) => (anchoFranja - 16) / 3.1;

  final double ancho;
  final String? imagenUrl;
  final Widget? imagen; // en vez de la foto (p. ej. un avatar)
  final IconData iconoSinFoto;
  final String titulo;
  final String? subtitulo;
  final String? precio;
  final bool fijado;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const TarjetaMini({
    super.key,
    required this.ancho,
    required this.titulo,
    required this.onTap,
    this.imagenUrl,
    this.imagen,
    this.iconoSinFoto = Icons.shopping_bag_outlined,
    this.subtitulo,
    this.precio,
    this.fijado = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final oscuro = ThemeService.isDarkMode;
    final url = (imagenUrl ?? '').trim();
    final fondoFoto =
        oscuro ? const Color(0xFF34363C) : const Color(0xFFF0F0F3);
    final foto = Container(
      width: 44,
      height: 52,
      decoration: BoxDecoration(
        color: fondoFoto,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: imagen ??
          (url.isEmpty
              ? Icon(iconoSinFoto, size: 20, color: colors.grayMid)
              : NetImage(
                  url.startsWith('http') ? url : '${ApiService.baseUrl}$url',
                  width: 44,
                  height: 52,
                  fit: BoxFit.cover,
                )),
    );
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: ancho,
        height: alto,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: oscuro ? const Color(0xFF25272C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: oscuro ? const Color(0xFF3A3D44) : const Color(0xFFEDEDF0),
              width: 0.8),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: oscuro ? 0.3 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            foto,
            if (fijado)
              Positioned(
                left: -4,
                top: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: oscuro ? const Color(0xFF25272C) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 3),
                    ],
                  ),
                  child: Icon(Icons.push_pin_rounded,
                      size: 12, color: colors.primary),
                ),
              ),
          ]),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    maxLines: precio == null && subtitulo == null ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: oscuro ? Colors.white : const Color(0xFF1C1C1E))),
                if (subtitulo != null && subtitulo!.isNotEmpty)
                  Text(subtitulo!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: oscuro ? Colors.white70 : colors.grayMid)),
                if (precio != null && precio!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.primary
                          .withValues(alpha: oscuro ? 0.22 : 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(precio!,
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: oscuro
                                  ? const Color(0xFFFF6B63)
                                  : colors.primary)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
