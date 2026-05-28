import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';

/// Resultado que devuelve esta pantalla al pop
class UbicacionElegida {
  final double lat;
  final double lng;
  final double radioKm;

  const UbicacionElegida({
    required this.lat,
    required this.lng,
    required this.radioKm,
  });
}

/// Pantalla full-screen para fijar un pin en el mapa y ajustar el radio de cobertura.
/// Uso:
///   final result = await Navigator.push<UbicacionElegida>(
///     context, MaterialPageRoute(builder: (_) => MapaUbicacionPickerScreen()));
class MapaUbicacionPickerScreen extends StatefulWidget {
  /// Ubicación inicial (opcional). Si no se pasa, centra en Santiago.
  final double? latInicial;
  final double? lngInicial;
  final double radioKmInicial;

  const MapaUbicacionPickerScreen({
    super.key,
    this.latInicial,
    this.lngInicial,
    this.radioKmInicial = 5.0,
  });

  @override
  State<MapaUbicacionPickerScreen> createState() =>
      _MapaUbicacionPickerScreenState();
}

class _MapaUbicacionPickerScreenState
    extends State<MapaUbicacionPickerScreen> {
  static final _santiago = LatLng(-33.4489, -70.6693);

  late LatLng _pin;
  late double _radioKm;
  late MapController _mapCtrl;
  bool _pinColocado = false;

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();
    _radioKm = widget.radioKmInicial;
    if (widget.latInicial != null && widget.lngInicial != null) {
      _pin = LatLng(widget.latInicial!, widget.lngInicial!);
      _pinColocado = true;
    } else {
      _pin = _santiago;
      _pinColocado = false;
    }
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      _pin = point;
      _pinColocado = true;
    });
  }

  void _confirmar() {
    if (!_pinColocado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toca el mapa para colocar tu ubicación'),
          backgroundColor: AppColors.carbon,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      UbicacionElegida(lat: _pin.latitude, lng: _pin.longitude, radioKm: _radioKm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Elige tu ubicación',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.carbon),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.divider),
        ),
      ),
      body: Column(
        children: [
          // Instrucción
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.primary.withOpacity(0.08),
            child: const Row(
              children: [
                Icon(Icons.touch_app_rounded,
                    size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Toca el mapa para colocar el pin de tu ubicación',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // Mapa
          Expanded(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                center: _pin,
                zoom: 13,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.okventa.app',
                ),

                // Círculo de cobertura
                if (_pinColocado)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _pin,
                        radius: _radioKm * 1000, // metros
                        useRadiusInMeter: true,
                        color: AppColors.primary.withOpacity(0.15),
                        borderStrokeWidth: 2,
                        borderColor: AppColors.primary.withOpacity(0.6),
                      ),
                    ],
                  ),

                // Pin
                if (_pinColocado)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pin,
                        width: 40,
                        height: 50,
                        anchorPos: AnchorPos.align(AnchorAlign.top),
                        builder: (_) => const Icon(
                          Icons.location_pin,
                          color: AppColors.primary,
                          size: 48,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Panel inferior: radio + confirmar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Radio
                Row(
                  children: [
                    const Icon(Icons.radar_rounded,
                        size: 18, color: AppColors.grayMid),
                    const SizedBox(width: 8),
                    const Text(
                      'Radio de cobertura',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_radioKm.toStringAsFixed(0)} km',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _radioKm,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.divider,
                  onChanged: (v) => setState(() => _radioKm = v),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('1 km',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.grayMid)),
                    Text('50 km',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.grayMid)),
                  ],
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirmar,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text(
                      'Confirmar ubicación',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
