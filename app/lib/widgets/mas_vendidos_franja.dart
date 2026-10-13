import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../screens/producto_detalle_screen.dart';
import '../services/api_service.dart';
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

class _MasVendidosFranjaState extends State<MasVendidosFranja>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>>? _items;
  // Llamitas que flamean en la esquina de cada tarjeta (versión compacta).
  late final AnimationController _llama = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();
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
    _llama.dispose();
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
      height: 62,
      child: LayoutBuilder(builder: (context, c) {
        // ~2,6 tarjetas a la vista: se nota que hay más.
        final ancho = (c.maxWidth - 16) / (widget.compacta ? 3.1 : 2.6);
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
        padding: const EdgeInsets.only(top: 8, bottom: 8),
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

  /// Llamita que flamea con el puesto adentro (1 al 10). Cada una con su
  /// propio desfase, para que no se muevan todas iguales.
  Widget _llamita(int puesto) {
    final fase = puesto * 0.37;
    return AnimatedBuilder(
      animation: _llama,
      builder: (_, child) {
        final t = (_llama.value + fase) * 2 * math.pi;
        final escala = 1 + 0.07 * math.sin(t * 2) + 0.03 * math.sin(t * 5);
        final giro = 0.06 * math.sin(t * 3);
        return Transform.rotate(
          angle: giro,
          alignment: Alignment.bottomCenter,
          child: Transform.scale(
            scale: escala,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: 26,
        height: 28,
        child: Stack(alignment: Alignment.center, children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xFFD32F2F), Color(0xFFFF6D00), Color(0xFFFFC107)],
              stops: [0.15, 0.6, 1],
            ).createShader(r),
            child: const Icon(Icons.local_fire_department_rounded, size: 28),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Text('$puesto',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: Color(0x88000000), blurRadius: 2),
                    ])),
          ),
        ]),
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> p, int puesto, double ancho) {
    final img = (p['imagen_url'] ?? '').toString();
    if (widget.compacta) {
      // Como la maqueta: foto y precio, nada más.
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: p)),
        ).then((_) => _cargar()),
        child: Container(
          width: ancho,
          padding: const EdgeInsets.fromLTRB(8, 7, 10, 5),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NetImage(
                    img.startsWith('http') ? img : '${ApiService.baseUrl}$img',
                    width: 44,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(left: -6, top: -6, child: _llamita(puesto)),
            ]),
            const Spacer(),
            Flexible(
              flex: 4,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(formatPrecio(p['precio']),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: colors.primary)),
              ),
            ),
          ]),
        ),
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
