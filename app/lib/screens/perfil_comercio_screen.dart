import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/comercio_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mapa_mini.dart';
import '../widgets/net_image.dart';
import 'perfil_publico_screen.dart';

/// Perfil de un comercio verificado (se abre al tocar la insignia
/// "Verificado"): quién es, fotos del local, indicadores de confianza y qué
/// revisó OkVenta.
class PerfilComercioScreen extends StatefulWidget {
  final int userId;
  const PerfilComercioScreen({super.key, required this.userId});

  @override
  State<PerfilComercioScreen> createState() => _PerfilComercioScreenState();
}

class _PerfilComercioScreenState extends State<PerfilComercioScreen> {
  Map<String, dynamic>? _p;
  bool _cargando = true;
  int _foto = 0;

  static const _azul = Color(0xFF1E88E5);

  @override
  void initState() {
    super.initState();
    ComercioService.perfil(widget.userId).then((p) {
      if (mounted) {
        setState(() {
          _p = p;
          _cargando = false;
        });
      }
    });
  }

  String _url(String u) =>
      u.startsWith('http') ? u : '${ApiService.baseUrl}$u';

  String _anios(num a) {
    if (a < 1) {
      final meses = (a * 12).round();
      return meses <= 1 ? 'Nuevo' : '$meses meses';
    }
    final n = a.floor();
    return '$n año${n == 1 ? '' : 's'}';
  }

  String _fecha(dynamic f) {
    final t = DateTime.tryParse('${f ?? ''}'.replaceFirst(' ', 'T'));
    if (t == null) return '';
    const m = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep',
        'oct', 'nov', 'dic'];
    return '${t.day} ${m[t.month - 1]} ${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: const Text('Perfil del comercio'),
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : p == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Este vendedor no es un comercio verificado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textSecondary)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    _encabezado(p),
                    _fotos(p),
                    _indicadores(p),
                    _verificado(p),
                    _datos(p),
                  ],
                ),
    );
  }

  Widget _encabezado(Map<String, dynamic> p) {
    final rep = (p['reputacion'] as num?)?.toDouble() ?? 0;
    final partes = <String>[
      if ((p['total_resenas'] ?? 0) > 0) '${rep.toStringAsFixed(1)}/5',
      _anios((p['anios_en_okventa'] as num?) ?? 0),
      if ((p['comuna'] ?? '').toString().isNotEmpty) p['comuna'].toString(),
    ];
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.verified_rounded, color: _azul, size: 20),
          const SizedBox(width: 5),
          const Text('Verificado',
              style: TextStyle(
                  color: _azul, fontWeight: FontWeight.w800, fontSize: 15)),
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                color: _azul, borderRadius: BorderRadius.circular(4)),
            child: const Text('OkVenta',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic)),
          ),
          const SizedBox(width: 8),
          Text('Comercio verificado',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: colors.textPrimary)),
        ]),
        const SizedBox(height: 8),
        Text((p['nombre_comercial'] ?? '').toString(),
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary)),
        const SizedBox(height: 4),
        Text(partes.join(' · '),
            style: TextStyle(fontSize: 14, color: colors.textSecondary)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PerfilPublicoScreen(
                  userId: widget.userId,
                  nombre: (p['nombre_comercial'] ?? '').toString(),
                ),
              ),
            ),
            icon: const Icon(Icons.storefront_rounded, size: 18),
            label: Text('Ver productos (${p['productos_activos'] ?? 0})'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.textPrimary,
              side: BorderSide(color: colors.divider),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _fotos(Map<String, dynamic> p) {
    final fotos = [for (final f in (p['fotos'] as List? ?? [])) '$f'];
    if (fotos.isEmpty) return const SizedBox.shrink();
    const etiquetas = ['Fachada', 'Letrero', 'Interior'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 230,
          child: Stack(children: [
            PageView.builder(
              itemCount: fotos.length,
              onPageChanged: (i) => setState(() => _foto = i),
              itemBuilder: (_, i) => NetImage(_url(fotos[i]),
                  width: double.infinity, height: 230, fit: BoxFit.cover),
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified_rounded, size: 14, color: _azul),
                  SizedBox(width: 4),
                  Text('Fotos verificadas por OkVenta',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E))),
                ]),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                    _foto < etiquetas.length ? etiquetas[_foto] : 'Foto',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_foto + 1}/${fotos.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _indicadores(Map<String, dynamic> p) {
    String pct(dynamic v) =>
        v == null ? '—' : '${(v as num).toStringAsFixed(v % 1 == 0 ? 0 : 1)}%';
    final rep = (p['reputacion'] as num?)?.toDouble() ?? 0;
    final items = <(String, String)>[
      (
        (p['total_resenas'] ?? 0) > 0 ? rep.toStringAsFixed(1) : '—',
        'Reseñas (${p['total_resenas'] ?? 0})'
      ),
      (pct(p['tasa_recompra']), 'Tasa de recompra'),
      (pct(p['tasa_entregas_exitosas']), 'Ventas sin problemas'),
      ('${p['ventas_completadas'] ?? 0}', 'Ventas completadas'),
      (_anios((p['anios_en_okventa'] as num?) ?? 0), 'En OkVenta'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Row(children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(width: 0.6, height: 40, color: colors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(items[i].$1,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary)),
                  Text(items[i].$2,
                      style: TextStyle(
                          fontSize: 12.5, color: colors.textSecondary)),
                ],
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _verificado(Map<String, dynamic> p) {
    final cosas = [
      ('RUT de la empresa', Icons.badge_outlined),
      ('Razón social', Icons.business_outlined),
      ('Representante legal', Icons.person_outline),
      ('Dirección del local', Icons.location_on_outlined),
      ('Fotos del local', Icons.photo_camera_outlined),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Verificado',
              style: TextStyle(
                  color: _azul, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(width: 6),
          Text('por OkVenta',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary)),
          const Spacer(),
          if (_fecha(p['verificado_en']).isNotEmpty)
            Text(_fecha(p['verificado_en']),
                style: TextStyle(fontSize: 12, color: colors.grayMid)),
        ]),
        const SizedBox(height: 8),
        for (final (t, i) in cosas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(i, size: 20, color: colors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(t,
                      style: TextStyle(
                          fontSize: 14.5, color: colors.textPrimary))),
              const Icon(Icons.check_circle_rounded, size: 20, color: _azul),
            ]),
          ),
      ]),
    );
  }

  Widget _datos(Map<String, dynamic> p) {
    final lat = (p['lat'] as num?)?.toDouble();
    final lng = (p['lng'] as num?)?.toDouble();
    Widget fila(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 110,
              child: Text(k,
                  style: TextStyle(fontSize: 13, color: colors.grayMid)),
            ),
            Expanded(
              child: Text(v,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary)),
            ),
          ]),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Datos del comercio',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
        const SizedBox(height: 6),
        fila('Razón social', '${p['razon_social'] ?? ''}'),
        fila('RUT', '${p['rut'] ?? ''}'),
        fila('Dirección', '${p['direccion'] ?? ''}'),
        fila('Productos', '${p['productos_activos'] ?? 0} activos'),
        if ((p['servicios'] ?? 0) > 0)
          fila('Servicios', '${p['servicios']} publicados'),
        if (lat != null && lng != null) ...[
          const SizedBox(height: 10),
          MapaMini(lat: lat, lng: lng, alto: 140, zoom: 15),
        ],
      ]),
    );
  }
}
