import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/historias_service.dart';
import '../widgets/avatar_usuario.dart';

/// Visor de historias a pantalla completa, como Instagram:
/// - barras de progreso arriba (5 s por historia), toca a la derecha para
///   avanzar y a la izquierda para volver; mantén presionado para pausar.
/// - Si la historia es tuya: corazón para dejarla DESTACADA en tu perfil
///   (rojo = destacada) y papelera para borrarla. Ves cuántas vistas tiene.
class HistoriaViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> historias;
  final String nombre;
  final String? fotoUrl;
  final bool esMio;
  final int? miUserId;
  final int inicio;

  const HistoriaViewerScreen({
    super.key,
    required this.historias,
    required this.nombre,
    this.fotoUrl,
    this.esMio = false,
    this.miUserId,
    this.inicio = 0,
  });

  @override
  State<HistoriaViewerScreen> createState() => _HistoriaViewerScreenState();
}

class _HistoriaViewerScreenState extends State<HistoriaViewerScreen>
    with SingleTickerProviderStateMixin {
  late final List<Map<String, dynamic>> _lista =
      widget.historias.map((h) => Map<String, dynamic>.from(h)).toList();
  late int _i = widget.inicio.clamp(0, widget.historias.length - 1).toInt();
  late final AnimationController _avance = AnimationController(
      vsync: this, duration: const Duration(seconds: 5))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _siguiente();
    });

  @override
  void initState() {
    super.initState();
    _empezar();
  }

  @override
  void dispose() {
    _avance.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _actual => _lista[_i];

  void _empezar() {
    _avance.forward(from: 0);
    final id = (_actual['id'] as num?)?.toInt();
    if (id != null && !widget.esMio) HistoriasService.contarVista(id);
  }

  void _siguiente() {
    if (_i < _lista.length - 1) {
      setState(() => _i++);
      _empezar();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _anterior() {
    if (_i > 0) setState(() => _i--);
    _empezar();
  }

  Future<void> _alternarDestacada() async {
    final uid = widget.miUserId;
    final id = (_actual['id'] as num?)?.toInt();
    if (uid == null || id == null) return;
    final nueva = _actual['destacada'] != true;
    setState(() => _actual['destacada'] = nueva);
    final ok = await HistoriasService.destacar(id, uid, nueva);
    if (!mounted) return;
    if (!ok) setState(() => _actual['destacada'] = !nueva);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(!ok
            ? 'No se pudo guardar'
            : nueva
                ? '❤️ Destacada: queda en tu perfil'
                : 'Ya no está destacada'),
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _borrar() async {
    final uid = widget.miUserId;
    final id = (_actual['id'] as num?)?.toInt();
    if (uid == null || id == null) return;
    _avance.stop();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar esta historia?'),
        content: const Text('Se borra también de tus destacadas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Borrar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) {
      _avance.forward();
      return;
    }
    final borrado = await HistoriasService.borrar(id, uid);
    if (!mounted) return;
    if (!borrado) {
      _avance.forward();
      return;
    }
    HistoriasService.cargarActivos();
    setState(() => _lista.removeAt(_i));
    if (_lista.isEmpty) {
      Navigator.maybePop(context);
      return;
    }
    if (_i >= _lista.length) _i = _lista.length - 1;
    _empezar();
  }

  String _hace(dynamic ts) {
    final d = DateTime.tryParse('${ts.toString().replaceFirst(' ', 'T')}Z');
    if (d == null) return '';
    final m = DateTime.now().toUtc().difference(d).inMinutes;
    if (m < 60) return 'hace ${m < 1 ? 1 : m} min';
    if (m < 60 * 24) return 'hace ${m ~/ 60} h';
    return 'hace ${m ~/ (60 * 24)} d';
  }

  @override
  Widget build(BuildContext context) {
    final url = (_actual['media_url'] ?? '').toString();
    final texto = (_actual['texto'] ?? '').toString();
    final destacada = _actual['destacada'] == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (d) {
          final ancho = MediaQuery.of(context).size.width;
          d.globalPosition.dx < ancho / 3 ? _anterior() : _siguiente();
        },
        onLongPressStart: (_) => _avance.stop(),
        onLongPressEnd: (_) => _avance.forward(),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.maybePop(context);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: CachedNetworkImage(
                imageUrl: url.startsWith('http') ? url : '${ApiService.baseUrl}$url',
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white54)),
                errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined, color: Colors.white54, size: 48),
              ),
            ),
            if (texto.isNotEmpty)
              Positioned(
                left: 20,
                right: 20,
                bottom: 120,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(texto,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            // Barras de progreso + encabezado
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Column(children: [
                  Row(children: [
                    for (var k = 0; k < _lista.length; k++) ...[
                      if (k > 0) const SizedBox(width: 3),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: AnimatedBuilder(
                            animation: _avance,
                            builder: (_, __) => LinearProgressIndicator(
                              minHeight: 2.5,
                              value: k < _i
                                  ? 1
                                  : k == _i
                                      ? _avance.value
                                      : 0,
                              backgroundColor: Colors.white24,
                              valueColor:
                                  const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    AvatarUsuario(
                        fotoUrl: widget.fotoUrl, nombre: widget.nombre, tamano: 34),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: widget.nombre,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          TextSpan(
                              text: '  ${_hace(_actual['created_at'])}',
                              style: const TextStyle(color: Colors.white70)),
                        ]),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ]),
                ]),
              ),
            ),
            // Acciones del dueño
            if (widget.esMio)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(children: [
                      const Icon(Icons.visibility_outlined,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 6),
                      Text('${_actual['vistas'] ?? 0}',
                          style: const TextStyle(color: Colors.white70)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Borrar',
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.white, size: 26),
                        onPressed: _borrar,
                      ),
                      const SizedBox(width: 6),
                      // ❤️ = destacada (queda en tu perfil, no vence).
                      GestureDetector(
                        onTap: _alternarDestacada,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: destacada
                                ? const Color(0xFFE53935)
                                : Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                                destacada
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: Colors.white,
                                size: 20),
                            const SizedBox(width: 6),
                            Text(destacada ? 'Destacada' : 'Destacar',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
