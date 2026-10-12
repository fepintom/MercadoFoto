import 'dart:io';

import 'package:flutter/material.dart';

import '../services/borradores_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'confirmacion_screen.dart';

/// Borradores: publicaciones que no se alcanzaron a terminar (el usuario
/// siguió mirando OkMarket mientras la IA analizaba, o salió de la
/// confirmación sin publicar). Tocar uno abre la confirmación para
/// terminarla; deslizar a la izquierda lo borra.
class BorradoresScreen extends StatefulWidget {
  const BorradoresScreen({super.key});

  @override
  State<BorradoresScreen> createState() => _BorradoresScreenState();
}

class _BorradoresScreenState extends State<BorradoresScreen> {
  @override
  void initState() {
    super.initState();
    BorradoresService.cargar();
  }

  String _hace(DateTime d) {
    final m = DateTime.now().difference(d).inMinutes;
    if (m < 1) return 'Recién';
    if (m < 60) return 'Hace $m min';
    if (m < 60 * 24) return 'Hace ${m ~/ 60} h';
    return 'Hace ${m ~/ (60 * 24)} d';
  }

  Future<void> _abrir(Borrador b) async {
    if (b.estado == 'analizando') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Todavía estamos analizando la foto…'),
          duration: Duration(seconds: 2)));
      return;
    }
    if (b.estado == 'error') {
      BorradoresService.reintentar(b);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmacionScreen(
          data: b.data,
          imagen: File(b.imagenes.first),
          imagenesExtra: [for (final p in b.imagenes.skip(1)) File(p)],
          borradorId: b.id,
        ),
      ),
    );
  }

  Future<bool> _confirmarBorrar(Borrador b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar este borrador?'),
        content: Text(b.titulo),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Borrar', style: TextStyle(color: colors.primary))),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        title: Text('Borradores',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
      ),
      body: ValueListenableBuilder<List<Borrador>>(
        valueListenable: BorradoresService.lista,
        builder: (context, lista, _) {
          if (lista.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset('assets/images/okventin_vender.png', height: 120),
                  const SizedBox(height: 14),
                  Text('No tienes borradores',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary)),
                  const SizedBox(height: 6),
                  Text(
                      'Si mientras publicas te vas a mirar OkMarket, '
                      'tu publicación te espera aquí para terminarla.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: colors.textPrimary)),
                ]),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: lista.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                  child: Text(
                      'Toca un borrador para terminar de publicarlo. '
                      'Desliza a la izquierda para borrarlo.',
                      style:
                          TextStyle(fontSize: 12.5, color: colors.textPrimary)),
                );
              }
              final b = lista[i - 1];
              return Dismissible(
                key: ValueKey(b.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmarBorrar(b),
                onDismissed: (_) => BorradoresService.borrar(b.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.white),
                ),
                child: _tarjeta(b),
              );
            },
          );
        },
      ),
    );
  }

  Widget _tarjeta(Borrador b) {
    final d = b.datos;
    final precioMin = (d['precio_usuario'] ?? d['precio_min']) as num?;
    final (Color colorEstado, String textoEstado, IconData iconoEstado) =
        switch (b.estado) {
      'analizando' => (
          const Color(0xFF8E8E93),
          'Analizando foto…',
          Icons.hourglass_top_rounded
        ),
      'error' => (
          colors.primary,
          'Falló el análisis · toca para reintentar',
          Icons.refresh_rounded
        ),
      _ => (
          colors.success,
          'Listo para publicar',
          Icons.check_circle_rounded
        ),
    };
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _abrir(b),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(b.imagenes.first),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  cacheWidth: 220,
                  errorBuilder: (_, __, ___) => Container(
                      width: 72, height: 72, color: colors.background)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.estado == 'listo' ? b.titulo : 'Nueva publicación',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary)),
                  if (b.estado == 'listo' &&
                      precioMin != null &&
                      precioMin > 0) ...[
                    const SizedBox(height: 2),
                    Text(formatPrecio(precioMin),
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: colors.primary)),
                  ],
                  const SizedBox(height: 5),
                  Row(children: [
                    if (b.estado == 'analizando')
                      const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.8))
                    else
                      Icon(iconoEstado, size: 14, color: colorEstado),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(textoEstado,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorEstado)),
                    ),
                    const SizedBox(width: 8),
                    Text(_hace(b.creado),
                        style: TextStyle(
                            fontSize: 11.5, color: colors.textPrimary)),
                  ]),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textPrimary),
          ]),
        ),
      ),
    );
  }
}
