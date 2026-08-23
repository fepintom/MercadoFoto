import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/net_image.dart';

/// "Muro" de evaluaciones de un vendedor: sus calificaciones organizadas
/// por producto, más las reseñas de cada comprador. Se llega aquí tocando
/// la calificación del vendedor en cualquiera de sus publicaciones.
class EvaluacionesVendedorScreen extends StatefulWidget {
  final int vendedorId;
  final String nombreVendedor;

  const EvaluacionesVendedorScreen({
    super.key,
    required this.vendedorId,
    required this.nombreVendedor,
  });

  @override
  State<EvaluacionesVendedorScreen> createState() =>
      _EvaluacionesVendedorScreenState();
}

class _EvaluacionesVendedorScreenState
    extends State<EvaluacionesVendedorScreen> {
  bool _cargando = true;
  List<dynamic> _grupos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final grupos =
        await ApiService.obtenerEvaluacionesVendedor(widget.vendedorId);
    if (!mounted) return;
    setState(() {
      _grupos = grupos;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalEvaluaciones = _grupos.fold<int>(
        0, (acc, g) => acc + (g['evaluaciones'] as List).length);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Evaluaciones · ${widget.nombreVendedor}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _grupos.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Este vendedor todavía no tiene evaluaciones.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.grayMid),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        '$totalEvaluaciones '
                        '${totalEvaluaciones == 1 ? "evaluación" : "evaluaciones"} '
                        'en ${_grupos.length} '
                        '${_grupos.length == 1 ? "producto" : "productos"}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.grayMid,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      ..._grupos.map((g) => _GrupoProducto(grupo: g)),
                    ],
                  ),
      ),
    );
  }
}

class _GrupoProducto extends StatelessWidget {
  final dynamic grupo;
  const _GrupoProducto({required this.grupo});

  @override
  Widget build(BuildContext context) {
    final titulo = grupo['titulo']?.toString() ?? 'Producto';
    final imagenUrl = grupo['imagen_url']?.toString();
    final evaluaciones = List<dynamic>.from(grupo['evaluaciones'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (imagenUrl != null && imagenUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NetImage(
                    "${ApiService.baseUrl}$imagenUrl",
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 10),
          ...evaluaciones.map((e) => _EvaluacionTile(e: e)),
        ],
      ),
    );
  }
}

class _EvaluacionTile extends StatelessWidget {
  final dynamic e;
  const _EvaluacionTile({required this.e});

  @override
  Widget build(BuildContext context) {
    final estrellas = (e['estrellas'] as num?)?.toInt() ?? 0;
    final comentario = e['comentario']?.toString() ?? '';
    final nombre = e['nombre_comprador']?.toString() ?? 'Usuario';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                  5,
                  (i) => Icon(
                      i < estrellas
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 13,
                      color: AppColors.primary)),
              const SizedBox(width: 6),
              Text(nombre,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ),
          if (comentario.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(comentario,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4)),
          ],
        ],
      ),
    );
  }
}
