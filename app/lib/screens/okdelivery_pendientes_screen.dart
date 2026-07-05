import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'okdelivery_activo_screen.dart';

/// Pantalla del repartidor: lista de entregas OkDelivery disponibles cerca
/// de él (dentro de su radio configurado) para aceptar.
class OkdeliveryPendientesScreen extends StatefulWidget {
  final int deliveryId;

  const OkdeliveryPendientesScreen({super.key, required this.deliveryId});

  @override
  State<OkdeliveryPendientesScreen> createState() =>
      _OkdeliveryPendientesScreenState();
}

class _OkdeliveryPendientesScreenState
    extends State<OkdeliveryPendientesScreen> {
  List<Map<String, dynamic>> _pendientes = [];
  bool _cargando = true;
  bool _aceptando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);

    // Si ya tiene una entrega en curso, entra directo a esa pantalla.
    final activas =
        await ApiService.entregasActivasRepartidor(widget.deliveryId);
    if (activas.isNotEmpty && mounted) {
      final activa = activas.first;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OkdeliveryActivoScreen(
            ordenId: activa['orden_id'] as int,
            deliveryId: widget.deliveryId,
          ),
        ),
      );
      return;
    }

    try {
      final data = await ApiService.pendientesOkdelivery(widget.deliveryId);
      if (mounted) setState(() { _pendientes = data; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _aceptar(int ordenId) async {
    if (_aceptando) return;
    setState(() => _aceptando = true);
    try {
      await ApiService.aceptarEntregaOkdelivery(ordenId, widget.deliveryId);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OkdeliveryActivoScreen(
            ordenId: ordenId,
            deliveryId: widget.deliveryId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _aceptando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo aceptar (¿ya la tomó otro repartidor?): $e'),
            backgroundColor: AppColors.primary,
          ),
        );
        _cargar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                    bottom: BorderSide(color: AppColors.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: AppColors.carbon),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Entregas OkDelivery',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        Text('Disponibles cerca de ti',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.grayMid)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _cargar,
                    child: const Icon(Icons.refresh_rounded,
                        color: AppColors.grayMid, size: 22),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _cargando
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : _pendientes.isEmpty
                      ? _buildVacio()
                      : RefreshIndicator(
                          onRefresh: _cargar,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _pendientes.length,
                            itemBuilder: (_, i) {
                              final e = _pendientes[i];
                              final titulo =
                                  e['titulo'] as String? ?? 'Producto';
                              final monto = (e['monto'] as num?)?.toDouble() ?? 0;
                              final distancia =
                                  (e['distancia_km'] as num?)?.toDouble() ?? 0;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                          Icons.delivery_dining_rounded,
                                          color: Colors.green),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(titulo,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      AppColors.textPrimary)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${distancia.toStringAsFixed(1)} km · \$${monto.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.grayMid),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: _aceptando
                                          ? null
                                          : () => _aceptar(
                                              e['orden_id'] as int),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Aceptar',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacio() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delivery_dining_outlined,
                  size: 64, color: AppColors.grayMid.withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text('Sin entregas disponibles',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Cuando haya una entrega cerca de ti\naparecerá aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.grayMid),
              ),
            ],
          ),
        ),
      );
}
