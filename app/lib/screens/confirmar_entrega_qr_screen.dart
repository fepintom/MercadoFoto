import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'mis_compras_screen.dart';

/// Pantalla a la que llega el comprador al escanear el QR "Confirmar
/// entrega" de la etiqueta (deep link okventa://orden/{id}/confirmar-entrega).
/// El backend valida el token secreto y que el usuario con sesión activa
/// sea el comprador de la orden.
class ConfirmarEntregaQrScreen extends StatefulWidget {
  final int ordenId;
  final String token;

  const ConfirmarEntregaQrScreen({
    super.key,
    required this.ordenId,
    required this.token,
  });

  @override
  State<ConfirmarEntregaQrScreen> createState() =>
      _ConfirmarEntregaQrScreenState();
}

class _ConfirmarEntregaQrScreenState extends State<ConfirmarEntregaQrScreen> {
  bool _enviando = false;
  bool _confirmado = false;
  String? _error;

  Future<void> _confirmar() async {
    if (_enviando) return;
    setState(() { _enviando = true; _error = null; });
    try {
      final userId = await SessionService.obtenerUser();
      if (userId == null) {
        throw Exception('Debes iniciar sesión con tu cuenta de comprador');
      }
      await ApiService.confirmarEntregaQr(
        ordenId: widget.ordenId,
        userId: userId,
        token: widget.token,
      );
      if (mounted) setState(() => _confirmado = true);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded,
                      size: 26, color: AppColors.carbon),
                ),
              ),
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: (_confirmado ? Colors.green : AppColors.primary)
                      .withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _confirmado
                      ? Icons.check_circle_rounded
                      : Icons.inventory_2_rounded,
                  size: 52,
                  color: _confirmado ? Colors.green : AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _confirmado
                    ? '¡Entrega confirmada!'
                    : '¿Recibiste tu pedido?',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                _confirmado
                    ? 'Gracias por comprar en OkVenta. El vendedor ya fue notificado.'
                    : 'Escaneaste el código de la etiqueta de la orden '
                        '#${widget.ordenId}. Confirma solo si ya tienes el '
                        'paquete en tus manos.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, color: AppColors.grayMid),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.4)),
                  ),
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.red)),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _enviando
                      ? null
                      : _confirmado
                          ? () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const MisComprasScreen()),
                              );
                            }
                          : _confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _confirmado ? Colors.green : AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_confirmado
                          ? 'Ver mis compras'
                          : 'Sí, recibí mi pedido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
