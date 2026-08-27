import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Pantalla donde el comprador califica al vendedor tras una compra ya
/// entregada. Se accede desde "Mis compras" (orden en estado 'entregado' y
/// aún no calificada). La calificación queda amarrada a la orden — el
/// backend impide calificar dos veces la misma compra o calificar sin haber
/// comprado.
class CalificarVendedorScreen extends StatefulWidget {
  final int ordenId;
  final int vendedorId;
  final int compradorId;
  final String nombreVendedor;
  final String tituloProducto;

  const CalificarVendedorScreen({
    super.key,
    required this.ordenId,
    required this.vendedorId,
    required this.compradorId,
    required this.nombreVendedor,
    required this.tituloProducto,
  });

  @override
  State<CalificarVendedorScreen> createState() =>
      _CalificarVendedorScreenState();
}

class _CalificarVendedorScreenState extends State<CalificarVendedorScreen> {
  int _estrellas = 0;
  final _comentarioCtrl = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_estrellas == 0) {
      setState(() => _error = 'Elige una calificación de 1 a 5 estrellas');
      return;
    }
    if (_comentarioCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Agrega un comentario');
      return;
    }
    setState(() { _enviando = true; _error = null; });
    try {
      await ApiService.calificarVendedor(
        ordenId: widget.ordenId,
        vendedorId: widget.vendedorId,
        compradorId: widget.compradorId,
        estrellas: _estrellas,
        comentario: _comentarioCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('¡Gracias por tu calificación!'),
        backgroundColor: colors.primary,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() =>
          _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 18,
              color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Calificar vendedor',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Cómo estuvo tu compra a ${widget.nombreVendedor}?',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const SizedBox(height: 4),
              Text(widget.tituloProducto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: colors.grayMid)),
              const SizedBox(height: 24),

              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final idx = i + 1;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _estrellas = idx;
                        _error = null;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          idx <= _estrellas
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 40,
                          color: idx <= _estrellas
                              ? colors.primary
                              : colors.grayMid,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              Text('Comentario',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _comentarioCtrl,
                maxLines: 4,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText:
                      'Cuéntale a otros compradores cómo te fue con este vendedor',
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.divider)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.divider)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: colors.primary, width: 1.5)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(fontSize: 13, color: Colors.red)),
              ],

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _enviando ? null : _enviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    disabledBackgroundColor: colors.grayMid,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text('Enviar calificación',
                          style: TextStyle(
                              color: colors.textOnPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
