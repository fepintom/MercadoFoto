import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class MisDireccionesScreen extends StatefulWidget {
  final int userId;
  final bool mostrarBotonMarketplace;

  const MisDireccionesScreen({
    super.key,
    required this.userId,
    this.mostrarBotonMarketplace = false,
  });

  @override
  State<MisDireccionesScreen> createState() => _MisDireccionesScreenState();
}

class _MisDireccionesScreenState extends State<MisDireccionesScreen> {
  List<Map<String, dynamic>> _direcciones = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await ApiService.obtenerDirecciones(widget.userId);
      if (mounted) setState(() { _direcciones = data; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _establecerPrincipal(int id) async {
    try {
      await ApiService.establecerPrincipal(widget.userId, id);
      await _cargar();
    } catch (_) {}
  }

  Future<void> _eliminar(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar dirección',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('¿Estás seguro de que deseas eliminar esta dirección?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.grayMid))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar', style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ApiService.eliminarDireccion(widget.userId, id);
        await _cargar();
      } catch (_) {}
    }
  }

  void _abrirFormulario({Map<String, dynamic>? direccion}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DireccionFormSheet(
        userId: widget.userId,
        direccion: direccion,
        onGuardado: _cargar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.carbon),
          onPressed: () => Navigator.pop(context),
          tooltip: widget.mostrarBotonMarketplace ? 'Volver al marketplace' : 'Volver',
        ),
        title: Text(
          widget.mostrarBotonMarketplace ? 'Volver al marketplace' : 'Mis direcciones',
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: !widget.mostrarBotonMarketplace,
        actions: [
          TextButton.icon(
            onPressed: () => _abrirFormulario(),
            icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
            label: const Text('Nueva', style: TextStyle(color: AppColors.primary, fontSize: 13)),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _direcciones.isEmpty
              ? _buildVacio()
              : _buildLista(),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                size: 64, color: AppColors.grayMid.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text('Sin direcciones guardadas',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Agrega tu primera dirección para situar\ntus publicaciones en el mapa.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.grayMid)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Agregar dirección'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLista() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: _direcciones.length,
      itemBuilder: (_, i) => _buildTarjeta(_direcciones[i]),
    );
  }

  Widget _buildTarjeta(Map<String, dynamic> d) {
    final esPrincipal = (d['es_principal'] as int? ?? 0) == 1;
    final etiqueta = d['etiqueta'] as String? ?? 'Casa';
    final direccion = d['direccion'] as String? ?? '';
    final comuna = d['comuna'] as String? ?? '';
    final ciudad = d['ciudad'] as String? ?? '';
    final partes = [if (comuna.isNotEmpty) comuna, if (ciudad.isNotEmpty) ciudad]
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esPrincipal ? AppColors.primary : AppColors.divider,
          width: esPrincipal ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: esPrincipal ? null : () => _establecerPrincipal(d['id'] as int),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícono según etiqueta
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: esPrincipal
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconoPorEtiqueta(etiqueta),
                  size: 20,
                  color: esPrincipal ? AppColors.primary : AppColors.grayMid,
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(etiqueta,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        if (esPrincipal) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Principal',
                                style: TextStyle(fontSize: 11, color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(direccion,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (partes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(partes,
                          style: const TextStyle(fontSize: 12, color: AppColors.grayMid)),
                    ],
                    if (!esPrincipal)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: GestureDetector(
                          onTap: () => _establecerPrincipal(d['id'] as int),
                          child: const Text('Usar como principal',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ),
              // Acciones
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: AppColors.grayMid),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'editar', child: Text('Editar')),
                  const PopupMenuItem(
                      value: 'eliminar',
                      child: Text('Eliminar', style: TextStyle(color: AppColors.primary))),
                ],
                onSelected: (v) {
                  if (v == 'editar') _abrirFormulario(direccion: d);
                  if (v == 'eliminar') _eliminar(d['id'] as int);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconoPorEtiqueta(String etiqueta) {
    final e = etiqueta.toLowerCase();
    if (e.contains('casa') || e.contains('hogar')) return Icons.home_outlined;
    if (e.contains('trabajo') || e.contains('oficina')) return Icons.work_outline;
    if (e.contains('otro') || e.contains('genérico')) return Icons.location_on_outlined;
    return Icons.place_outlined;
  }
}

// ── Formulario de agregar/editar dirección ────────────────────────────────────

class _DireccionFormSheet extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? direccion; // null = nueva
  final VoidCallback onGuardado;

  const _DireccionFormSheet({
    required this.userId,
    required this.onGuardado,
    this.direccion,
  });

  @override
  State<_DireccionFormSheet> createState() => _DireccionFormSheetState();
}

class _DireccionFormSheetState extends State<_DireccionFormSheet> {
  final _etiquetaCtrl    = TextEditingController();
  final _busquedaCtrl    = TextEditingController();
  List<Map<String, dynamic>> _sugerencias = [];
  bool _buscando         = false;
  bool _guardando        = false;
  bool _obteniendoGps    = false;
  Timer? _debounce;
  Map<String, dynamic>? _seleccionada;

  // ── Modo manual ───────────────────────────────────────────────────────────
  bool _modoManual       = false;
  final _calleCtrl       = TextEditingController();
  final _numeracionCtrl  = TextEditingController();
  final _comunaCtrl      = TextEditingController();
  final _ciudadCtrl      = TextEditingController();
  double? _latManual;
  double? _lngManual;
  // centro sugerido para el mapa según la comuna ingresada
  double? _latComuna;
  double? _lngComuna;

  static const _etiquetas = ['Casa', 'Trabajo', 'Otro'];

  @override
  void initState() {
    super.initState();
    final d = widget.direccion;
    if (d != null) {
      _etiquetaCtrl.text = d['etiqueta'] as String? ?? 'Casa';
      final partes = [
        d['direccion'] as String? ?? '',
        d['comuna'] as String? ?? '',
        d['ciudad'] as String? ?? '',
      ].where((s) => s.isNotEmpty).join(', ');
      _busquedaCtrl.text = partes;
      // Pre-cargar la dirección actual como "seleccionada"
      _seleccionada = {
        'display_name': partes,
        'lat': d['lat']?.toString() ?? '',
        'lon': d['lng']?.toString() ?? '',
        'address': {
          'road': d['direccion'],
          'suburb': d['comuna'],
          'city': d['ciudad'],
        },
      };
    } else {
      _etiquetaCtrl.text = 'Casa';
    }
  }

  @override
  void dispose() {
    _etiquetaCtrl.dispose();
    _busquedaCtrl.dispose();
    _calleCtrl.dispose();
    _numeracionCtrl.dispose();
    _comunaCtrl.dispose();
    _ciudadCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onCambio(String texto) {
    _debounce?.cancel();
    setState(() => _seleccionada = null);
    if (texto.trim().length < 4) {
      setState(() => _sugerencias = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _buscar(texto));
  }

  Future<void> _buscar(String query) async {
    setState(() => _buscando = true);
    bool encontrado = false;

    // Photon (Elasticsearch sobre OSM): mejor fuzzy matching para calles chilenas
    try {
      final uri = Uri.parse('https://photon.komoot.io/api/').replace(
        queryParameters: {
          'q': query,
          'limit': '8',
          'lang': 'es',
          'bbox': '-75.7,-55.9,-66.1,-17.5', // bounding box Chile
        },
      );
      final resp = await http.get(uri, headers: {
        'User-Agent': 'OkVenta/1.0 (okventa.app)',
      }).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final features = (data['features'] as List?) ?? [];
        if (features.isNotEmpty) {
          final resultados = features.map<Map<String, dynamic>>((f) {
            final props = Map<String, dynamic>.from(f['properties'] as Map);
            final coords = (f['geometry']['coordinates'] as List);
            final lon = coords[0];
            final lat = coords[1];
            final calle = props['street'] as String? ?? props['name'] as String? ?? '';
            final numero = props['housenumber'] as String? ?? '';
            final calleConNum = [calle, numero].where((s) => s.isNotEmpty).join(' ');
            final suburb = props['suburb'] as String? ?? props['district'] as String? ?? '';
            final ciudad = props['city'] as String? ?? props['town'] as String? ?? props['village'] as String? ?? '';
            final estado = props['state'] as String? ?? '';
            final displayName = [calleConNum, suburb, ciudad, estado, 'Chile']
                .where((s) => s.isNotEmpty).join(', ');
            return {
              'display_name': displayName,
              'lat': '$lat',
              'lon': '$lon',
              'address': {
                'road': calleConNum,
                'suburb': suburb,
                'city': ciudad,
                'state': estado,
                'country': 'Chile',
              },
            };
          }).toList();
          if (mounted) setState(() => _sugerencias = resultados);
          encontrado = true;
        }
      }
    } catch (_) {}

    // Fallback: Nominatim si Photon no retorna resultados
    if (!encontrado) {
      try {
        final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
          queryParameters: {
            'q': '$query, Chile',
            'format': 'json',
            'limit': '6',
            'addressdetails': '1',
            'countrycodes': 'cl',
          },
        );
        final resp = await http.get(uri, headers: {
          'User-Agent': 'OkVenta/1.0 (okventa.app)',
          'Accept-Language': 'es',
        }).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as List;
          if (mounted) setState(() => _sugerencias = data.map((e) => Map<String, dynamic>.from(e)).toList());
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _buscando = false);
  }

  Future<void> _usarGps() async {
    setState(() => _obteniendoGps = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado')));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      // Reverse geocoding con Nominatim
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(
        queryParameters: {
          'lat': '${pos.latitude}',
          'lon': '${pos.longitude}',
          'format': 'json',
          'addressdetails': '1',
          'accept-language': 'es',
        },
      );
      final resp = await http.get(uri, headers: {
        'User-Agent': 'OkVenta/1.0 (okventa.app)',
      }).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && mounted) {
        final data = Map<String, dynamic>.from(jsonDecode(resp.body));
        setState(() {
          _seleccionada = {
            'display_name': data['display_name'],
            'lat': '${pos.latitude}',
            'lon': '${pos.longitude}',
            'address': data['address'] ?? {},
          };
          _busquedaCtrl.text = data['display_name'] ?? '';
          _sugerencias = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la ubicación')));
      }
    } finally {
      if (mounted) setState(() => _obteniendoGps = false);
    }
  }

  Future<void> _geocodificarComuna(String comuna) async {
    if (comuna.trim().length < 3) return;
    try {
      final uri = Uri.parse('https://photon.komoot.io/api/').replace(
        queryParameters: {
          'q': '$comuna, Chile',
          'limit': '1',
          'lang': 'es',
          'bbox': '-75.7,-55.9,-66.1,-17.5',
        },
      );
      final resp = await http.get(uri,
          headers: {'User-Agent': 'OkVenta/1.0'})
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final features = (data['features'] as List?) ?? [];
        if (features.isNotEmpty) {
          final coords = features.first['geometry']['coordinates'] as List;
          if (mounted) setState(() {
            _latComuna = (coords[1] as num).toDouble();
            _lngComuna = (coords[0] as num).toDouble();
          });
        }
      }
    } catch (_) {}
  }

  Widget _botonAgregarManual() {
    return InkWell(
      onTap: () => setState(() {
        _modoManual = true;
        _sugerencias = [];
        _seleccionada = null;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.edit_location_alt_outlined,
                size: 16, color: AppColors.carbon),
            const SizedBox(width: 10),
            const Text('Agregar manual',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.carbon)),
          ],
        ),
      ),
    );
  }

  Widget _campoManual({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    TextInputType teclado = TextInputType.text,
    VoidCallback? onEditingComplete,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: teclado,
            onEditingComplete: onEditingComplete,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.grayMid, fontSize: 13),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  String _extraer(Map<String, dynamic> addr, List<String> claves) {
    for (final c in claves) {
      final v = addr[c];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }

  Future<void> _guardar() async {
    final etiqueta = _etiquetaCtrl.text.trim().isEmpty ? 'Casa' : _etiquetaCtrl.text.trim();
    String direccion, comuna, ciudad;
    double? lat, lng;

    if (_modoManual) {
      final calle = _calleCtrl.text.trim();
      final num   = _numeracionCtrl.text.trim();
      if (calle.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ingresa el nombre de la calle')));
        return;
      }
      if (_latManual == null || _lngManual == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sitúa el pin en el mapa para guardar la ubicación')));
        return;
      }
      direccion = num.isNotEmpty ? '$calle $num' : calle;
      comuna    = _comunaCtrl.text.trim();
      ciudad    = _ciudadCtrl.text.trim().isEmpty ? 'Chile' : _ciudadCtrl.text.trim();
      lat       = _latManual;
      lng       = _lngManual;
    } else {
      if (_seleccionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecciona una dirección de la lista')));
        return;
      }
      final addr = _seleccionada!['address'] as Map<String, dynamic>? ?? {};
      direccion = _extraer(addr, ['road', 'pedestrian', 'footway', 'display_name']);
      comuna    = _extraer(addr, ['suburb', 'neighbourhood', 'quarter', 'town', 'village']);
      ciudad    = _extraer(addr, ['city', 'county', 'state_district', 'state']);
      lat       = double.tryParse(_seleccionada!['lat']?.toString() ?? '');
      lng       = double.tryParse(_seleccionada!['lon']?.toString() ?? '');
    }

    setState(() => _guardando = true);
    try {
      final d = widget.direccion;
      if (d != null) {
        await ApiService.actualizarDireccion(
          widget.userId, d['id'] as int,
          etiqueta: etiqueta, direccion: direccion,
          comuna: comuna, ciudad: ciudad, lat: lat, lng: lng,
        );
      } else {
        await ApiService.agregarDireccion(
          widget.userId,
          etiqueta: etiqueta, direccion: direccion,
          comuna: comuna, ciudad: ciudad, lat: lat, lng: lng,
        );
      }
      widget.onGuardado();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.80,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, sc) => Container(
          color: AppColors.surface,
          child: Column(
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  widget.direccion == null ? 'Nueva dirección' : 'Editar dirección',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Etiqueta
                      const Text('Etiqueta',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ..._etiquetas.map((e) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _etiquetaCtrl.text = e),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _etiquetaCtrl.text == e
                                      ? AppColors.carbon
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _etiquetaCtrl.text == e
                                        ? AppColors.carbon
                                        : AppColors.divider,
                                  ),
                                ),
                                child: Text(e,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _etiquetaCtrl.text == e
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    )),
                              ),
                            ),
                          )),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Buscar dirección
                      const Text('Dirección',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: TextField(
                          controller: _busquedaCtrl,
                          onChanged: _onCambio,
                          decoration: InputDecoration(
                            hintText: 'Ej: Av. Providencia 1234, Santiago',
                            hintStyle: const TextStyle(color: AppColors.grayMid, fontSize: 13),
                            prefixIcon: _buscando
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(width: 16, height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: AppColors.primary)))
                                : const Icon(Icons.search, size: 18, color: AppColors.grayMid),
                            suffixIcon: _busquedaCtrl.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () => setState(() {
                                      _busquedaCtrl.clear();
                                      _sugerencias = [];
                                      _seleccionada = null;
                                    }),
                                    child: const Icon(Icons.close, size: 16, color: AppColors.grayMid))
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      // Botón GPS
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _obteniendoGps ? null : _usarGps,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.carbon.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              _obteniendoGps
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: AppColors.carbon))
                                  : const Icon(Icons.my_location_rounded,
                                      size: 18, color: AppColors.carbon),
                              const SizedBox(width: 10),
                              const Text('Usar mi ubicación actual',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                      color: AppColors.carbon)),
                            ],
                          ),
                        ),
                      ),

                      // Sugerencias buscador
                      if (!_modoManual && _sugerencias.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            children: [
                              ..._sugerencias.asMap().entries.map((entry) {
                                final i = entry.key;
                                final s = entry.value;
                                final nombre = s['display_name'] as String? ?? '';
                                return Column(
                                  children: [
                                    if (i > 0)
                                      Divider(height: 0.5, color: AppColors.divider),
                                    InkWell(
                                      onTap: () => setState(() {
                                        _seleccionada = s;
                                        _busquedaCtrl.text = nombre;
                                        _sugerencias = [];
                                      }),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined,
                                                size: 16, color: AppColors.grayMid),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(nombre,
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: AppColors.textPrimary),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              // Opción agregar manual al final de la lista
                              Divider(height: 0.5, color: AppColors.divider),
                              _botonAgregarManual(),
                            ],
                          ),
                        ),
                      ],

                      // Botón agregar manual cuando no hay sugerencias y se buscó algo
                      if (!_modoManual && _sugerencias.isEmpty && !_buscando &&
                          _busquedaCtrl.text.trim().length >= 4 && _seleccionada == null) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(children: [
                                const Icon(Icons.search_off_rounded, size: 15, color: AppColors.grayMid),
                                const SizedBox(width: 8),
                                const Text('No se encontraron resultados',
                                    style: TextStyle(fontSize: 13, color: AppColors.grayMid)),
                              ]),
                            ),
                            Divider(height: 0.5, color: AppColors.divider),
                            _botonAgregarManual(),
                          ]),
                        ),
                      ],

                      // Formulario manual
                      if (_modoManual) ...[
                        const SizedBox(height: 16),
                        _campoManual(label: 'Calle / Avenida', ctrl: _calleCtrl,
                            hint: 'Ej: Av. Providencia'),
                        const SizedBox(height: 12),
                        _campoManual(label: 'Numeración', ctrl: _numeracionCtrl,
                            hint: 'Ej: 1234', teclado: TextInputType.number),
                        const SizedBox(height: 12),
                        _campoManual(
                          label: 'Comuna',
                          ctrl: _comunaCtrl,
                          hint: 'Ej: Maipú',
                          onEditingComplete: () => _geocodificarComuna(_comunaCtrl.text),
                        ),
                        const SizedBox(height: 12),
                        _campoManual(label: 'Ciudad', ctrl: _ciudadCtrl,
                            hint: 'Ej: Santiago'),
                        const SizedBox(height: 16),

                        // Botón situar pin
                        GestureDetector(
                          onTap: () async {
                            // si escribió una comuna, geocodificamos primero para centrar el mapa
                            if (_latComuna == null && _comunaCtrl.text.trim().isNotEmpty) {
                              await _geocodificarComuna(_comunaCtrl.text);
                            }
                            final resultado = await Navigator.push<LatLng>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _MapaPinPickerScreen(
                                  latInicial: _latManual ?? _latComuna,
                                  lngInicial: _lngManual ?? _lngComuna,
                                ),
                              ),
                            );
                            if (resultado != null && mounted) {
                              setState(() {
                                _latManual = resultado.latitude;
                                _lngManual = resultado.longitude;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: _latManual != null
                                  ? AppColors.primary.withOpacity(0.06)
                                  : AppColors.carbon.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _latManual != null
                                    ? AppColors.primary.withOpacity(0.4)
                                    : AppColors.divider,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _latManual != null
                                      ? Icons.location_on_rounded
                                      : Icons.add_location_alt_outlined,
                                  size: 20,
                                  color: _latManual != null
                                      ? AppColors.primary
                                      : AppColors.carbon,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _latManual != null
                                        ? 'Pin situado: ${_latManual!.toStringAsFixed(5)}, ${_lngManual!.toStringAsFixed(5)}'
                                        : 'Situar pin en el mapa',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _latManual != null
                                          ? AppColors.primary
                                          : AppColors.carbon,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    size: 18,
                                    color: _latManual != null
                                        ? AppColors.primary
                                        : AppColors.grayMid),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(() => _modoManual = false),
                          child: const Text('← Volver a búsqueda',
                              style: TextStyle(fontSize: 13, color: AppColors.grayMid)),
                        ),
                      ],

                      // Dirección confirmada
                      if (_seleccionada != null && _sugerencias.isEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _seleccionada!['display_name']?.toString() ??
                                      _busquedaCtrl.text,
                                  style: const TextStyle(fontSize: 13,
                                      color: AppColors.textPrimary),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Guardar
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _guardando ? null : _guardar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textOnPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _guardando
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(widget.direccion == null ? 'Guardar dirección' : 'Guardar cambios',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pantalla picker de pin en mapa ───────────────────────────────────────────
class _MapaPinPickerScreen extends StatefulWidget {
  final double? latInicial;
  final double? lngInicial;
  const _MapaPinPickerScreen({this.latInicial, this.lngInicial});

  @override
  State<_MapaPinPickerScreen> createState() => _MapaPinPickerScreenState();
}

class _MapaPinPickerScreenState extends State<_MapaPinPickerScreen> {
  static final _santiago = LatLng(-33.4489, -70.6693);
  late LatLng _pin;
  late MapController _mapCtrl;

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();
    _pin = widget.latInicial != null && widget.lngInicial != null
        ? LatLng(widget.latInicial!, widget.lngInicial!)
        : _santiago;
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.carbon),
        title: const Text('Sitúa tu dirección',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.divider),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _pin),
            child: const Text('Confirmar',
                style: TextStyle(color: AppColors.primary,
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              center: _pin,
              zoom: 15.0,
              maxZoom: 19,
              onTap: (_, latlng) => setState(() => _pin = latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.okventa.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _pin,
                    width: 40,
                    height: 50,
                    anchorPos: AnchorPos.align(AnchorAlign.top),
                    builder: (_) => const Icon(
                      Icons.location_on_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Instrucción centrada arriba
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1),
                      blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_rounded, size: 15, color: AppColors.grayMid),
                  SizedBox(width: 6),
                  Text('Toca el mapa para mover el pin',
                      style: TextStyle(fontSize: 13, color: AppColors.grayMid)),
                ],
              ),
            ),
          ),

          // Coordenadas del pin abajo
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1),
                      blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${_pin.latitude.toStringAsFixed(5)}, ${_pin.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
