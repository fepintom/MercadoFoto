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

  int get _paginas => ((_items?.length ?? 0) / 2).ceil().clamp(1, 5);

  Future<void> _cargar() async {
    final l = await VistasService.masVendidos(limite: 5);
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
        final ancho = (c.maxWidth - 16) / 2.6;
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
        padding: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.surface,
              colors.primary.withValues(alpha: 0.06),
            ],
          ),
        ),
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
