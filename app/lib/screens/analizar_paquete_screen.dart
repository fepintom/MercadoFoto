import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Pantalla que se muestra al comprador justo después de grabar el
/// unboxing: presiona "Analizar" y la IA compara los fotogramas del
/// embalaje (subidos por el vendedor) con los del unboxing recién
/// grabado, verificando dimensiones, posición de los sellos/etiquetas y
/// que el paquete no esté dañado ni alterado.
class AnalizarPaqueteScreen extends StatefulWidget {
  final int ordenId;
  final String tituloProducto;

  const AnalizarPaqueteScreen({
    super.key,
    required this.ordenId,
    required this.tituloProducto,
  });

  @override
  State<AnalizarPaqueteScreen> createState() => _AnalizarPaqueteScreenState();
}

class _AnalizarPaqueteScreenState extends State<AnalizarPaqueteScreen> {
  bool _analizando = false;
  Map<String, dynamic>? _resultado;
  String? _error;

  Future<void> _analizar() async {
    setState(() {
      _analizando = true;
      _error = null;
    });
    try {
      final resultado = await ApiService.analizarEmpaque(widget.ordenId);
      if (!mounted) return;
      setState(() => _resultado = resultado);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error =
          'No pudimos completar el análisis en este momento. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _analizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = _resultado != null && _resultado!['ok'] == true;
    final huboResultado = _resultado != null;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Verificación del paquete')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.tituloProducto,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Ya registramos el video de tu unboxing. Presiona "Analizar" '
              'para que comparemos el paquete con el que registró el '
              'vendedor al despacharlo.',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),
            if (huboResultado)
              _buildResultado(ok)
            else if (_error != null)
              Text(_error!, style: TextStyle(color: colors.primary)),
            const Spacer(),
            if (!huboResultado)
              ElevatedButton(
                onPressed: _analizando ? null : _analizar,
                child: _analizando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Analizar'),
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(ok),
                child: Text(ok ? 'Abrir mi okcompra' : 'Entendido'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultado(bool ok) {
    final color = ok ? const Color(0xFF2E7D32) : colors.primary;
    final icono = ok ? Icons.check_circle : Icons.warning_amber_rounded;
    final detalle = _resultado?['detalle'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _resultado!['mensaje'] ?? '',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (!ok && (detalle != null && detalle.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Text(detalle, style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
