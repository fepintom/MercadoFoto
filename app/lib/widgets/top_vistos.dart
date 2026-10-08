import 'package:flutter/material.dart';

import '../screens/producto_detalle_screen.dart';
import '../services/api_service.dart';
import '../services/vistas_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'net_image.dart';

/// "Lo más visto": los 5 productos con más visualizaciones del último mes.
/// Va en la mitad de abajo de Comunidad. Tarjetas horizontales que ocupan
/// todo el alto disponible, con el puesto (#1…#5) y el 👁.
class TopVistos extends StatefulWidget {
  /// Cambiar el valor fuerza a recargar (p. ej. al volver a la pestaña).
  final int version;
  const TopVistos({super.key, this.version = 0});

  @override
  State<TopVistos> createState() => _TopVistosState();
}

class _TopVistosState extends State<TopVistos> {
  List<Map<String, dynamic>>? _items;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant TopVistos old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version) _cargar();
  }

  Future<void> _cargar() async {
    final l = await VistasService.topProductos(limite: 5);
    if (mounted) setState(() => _items = l);
  }

  void _abrir(Map<String, dynamic> p) {
    Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: p)))
        .then((_) => _cargar());
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(children: [
              Icon(Icons.local_fire_department_rounded,
                  size: 18, color: colors.primary),
              const SizedBox(width: 6),
              Text('Lo más visto',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary)),
              const SizedBox(width: 6),
              Text('· top 5 del mes',
                  style: TextStyle(fontSize: 12, color: colors.textPrimary)),
            ]),
          ),
          Expanded(
            child: items == null
                ? Center(
                    child: CircularProgressIndicator(color: colors.primary))
                : items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                              'Aún no hay productos vistos este mes.\n'
                              'Recorre OkMarket y aparecerán aquí.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: colors.textPrimary)),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, c) {
                          // Alto de la foto = lo que queda menos el texto.
                          const altoTexto = 58.0;
                          final altoFoto =
                              (c.maxHeight - altoTexto - 10).clamp(60.0, 400.0);
                          final ancho = (altoFoto * 0.85).clamp(110.0, 220.0);
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) => _tarjeta(
                                items[i], i + 1, ancho, altoFoto),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(
      Map<String, dynamic> p, int puesto, double ancho, double altoFoto) {
    final img = (p['imagen_url'] ?? '').toString();
    final vistas = (p['vistas'] as num?)?.toInt() ?? 0;
    return GestureDetector(
      onTap: () => _abrir(p),
      child: SizedBox(
        width: ancho,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: ancho,
                height: altoFoto,
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(
                    img.startsWith('http') ? img : '${ApiService.baseUrl}$img',
                    width: ancho,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: puesto == 1
                            ? colors.primary
                            : Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('#$puesto',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: EtiquetaVistas(vistas: vistas),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 5),
            Text((p['titulo'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary)),
            const SizedBox(height: 2),
            Text(formatPrecio(p['precio']),
                maxLines: 1,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: colors.primary)),
          ],
        ),
      ),
    );
  }
}
