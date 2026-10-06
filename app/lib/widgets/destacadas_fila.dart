import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/historias_service.dart';

/// Fila horizontal de historias DESTACADAS de un usuario (las que marcó con
/// el corazón). Se muestra en Mi OkVenta y en el perfil del vendedor.
/// Si no hay destacadas, no ocupa espacio.
class DestacadasFila extends StatefulWidget {
  final int userId;
  final String nombre;
  final String? fotoUrl;

  /// Cambiar este valor fuerza a recargar (p. ej. al volver del visor).
  final int version;

  const DestacadasFila({
    super.key,
    required this.userId,
    required this.nombre,
    this.fotoUrl,
    this.version = 0,
  });

  @override
  State<DestacadasFila> createState() => _DestacadasFilaState();
}

class _DestacadasFilaState extends State<DestacadasFila> {
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant DestacadasFila old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId || old.version != widget.version) _cargar();
  }

  Future<void> _cargar() async {
    final l = await HistoriasService.destacadas(widget.userId);
    if (mounted) setState(() => _items = l);
  }

  String _url(Map<String, dynamic> h) {
    final u = (h['media_url'] ?? '').toString();
    return u.startsWith('http') ? u : '${ApiService.baseUrl}$u';
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(Icons.favorite_rounded, size: 15, color: Color(0xFFE53935)),
            SizedBox(width: 6),
            Text('Historias destacadas',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () async {
                await HistoriasService.abrir(
                  context,
                  userId: widget.userId,
                  nombre: widget.nombre,
                  fotoUrl: widget.fotoUrl,
                  soloDestacadas: true,
                  historias: _items,
                  inicio: i,
                );
                _cargar();
              },
              child: Container(
                width: 66,
                height: 92,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE53935), width: 1.6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: CachedNetworkImage(
                    imageUrl: _url(_items[i]),
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.black12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
