import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Devuelve el `id` Blue Express seleccionado si el usuario confirma,
/// o `null` si cancela. Se usa como bottom sheet.
class BlueExpressSheet extends StatefulWidget {
  const BlueExpressSheet({super.key});

  @override
  State<BlueExpressSheet> createState() => _BlueExpressSheetState();
}

class _BlueExpressSheetState extends State<BlueExpressSheet> {
  final _comunaCtrl = TextEditingController();
  List<Map<String, dynamic>> _puntos = [];
  bool _buscando    = false;
  bool _buscado     = false;
  Map<String, dynamic>? _seleccionado;

  static const _azulBE  = Color(0xFF0057B8);
  static const _cianBE  = Color(0xFF00AEEF);

  @override
  void dispose() {
    _comunaCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final comuna = _comunaCtrl.text.trim();
    if (comuna.isEmpty) return;
    setState(() { _buscando = true; _buscado = false; _seleccionado = null; });
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/blue-express/puntos')
          .replace(queryParameters: {'comuna': comuna, 'limite': '5'});
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final puntos = List<Map<String, dynamic>>.from(data['puntos'] ?? []);
        if (mounted) setState(() { _puntos = puntos; _buscado = true; });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión')));
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _abrirMaps(Map<String, dynamic> p) async {
    final lat = p['lat'];
    final lng = p['lng'];
    if (lat == null || lng == null) return;
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        color: AppColors.surface,
        child: Column(
        children: [
          // Handle + header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_azulBE, _cianBE],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: _azulBE, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Blue Express',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900)),
                        Text('Encuentra tu punto de despacho',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              children: [
                // Buscador de comuna
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _comunaCtrl,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _buscar(),
                          decoration: const InputDecoration(
                            hintText: 'Ingresa tu comuna (ej: Providencia)',
                            prefixIcon: Icon(Icons.location_on_outlined,
                                color: _azulBE, size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _buscar,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _azulBE,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buscando
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Buscar',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Info box — siempre visible
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _azulBE.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _azulBE.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: _azulBE, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lleva tu paquete a la oficina Blue Express más '
                          'cercana para coordinar el despacho.',
                          style: TextStyle(
                              fontSize: 12,
                              color: _azulBE,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                // Resultados
                if (_buscado && _puntos.isEmpty)
                  _noResults()
                else if (_puntos.isNotEmpty) ...[
                  // Lista de puntos
                  ...List.generate(_puntos.length, (i) {
                    final p = _puntos[i];
                    final sel = _seleccionado != null &&
                        _seleccionado!['nombre'] == p['nombre'];
                    return GestureDetector(
                      onTap: () => setState(() => _seleccionado = p),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: sel
                              ? _azulBE.withOpacity(0.07)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? _azulBE : AppColors.divider,
                            width: sel ? 1.5 : 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: sel
                                    ? _azulBE.withOpacity(0.15)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.storefront_outlined,
                                  color: sel ? _azulBE : AppColors.grayMid,
                                  size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['nombre'] as String? ?? '',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: sel
                                              ? _azulBE
                                              : AppColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(p['direccion'] as String? ?? '',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.grayMid)),
                                  Text(
                                    '${p['comuna'] ?? ''} — ${p['region'] ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.grayMid),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                if (sel)
                                  const Icon(Icons.check_circle_rounded,
                                      color: _azulBE, size: 20),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () => _abrirMaps(p),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _cianBE.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.map_outlined,
                                            size: 12, color: _cianBE),
                                        SizedBox(width: 3),
                                        Text('Ver mapa',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: _cianBE,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],

                // Sin búsqueda aún
                if (!_buscado && _puntos.isEmpty && !_buscando)
                  _estadoInicial(),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // Botón confirmar
          if (_seleccionado != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border:
                    Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '📍 ${_seleccionado!['nombre']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, _seleccionado),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Confirmar punto Blue Express',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _azulBE,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
        ],
        ), // Column
      ), // Container
    );
  }

  Widget _estadoInicial() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.search_rounded,
                size: 56, color: _azulBE.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text(
              'Ingresa tu comuna para ver\nlos puntos Blue Express más cercanos',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.grayMid,
                  height: 1.5),
            ),
          ],
        ),
      );

  Widget _noResults() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.location_off_outlined,
                size: 40, color: AppColors.grayMid),
            const SizedBox(height: 10),
            const Text(
              'No encontramos puntos en esa comuna.\nPrueba con una ciudad cercana.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.grayMid),
            ),
          ],
        ),
      );
}
