import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class OfertaScreen extends StatefulWidget {
  final int publicacionId;
  final int compradorId;   // quien hizo la oferta
  final double monto;
  final String titulo;
  final String imagenUrl;

  const OfertaScreen({
    super.key,
    required this.publicacionId,
    required this.compradorId,
    required this.monto,
    required this.titulo,
    required this.imagenUrl,
  });

  @override
  State<OfertaScreen> createState() => _OfertaScreenState();
}

class _OfertaScreenState extends State<OfertaScreen> {
  final _mensajeCtrl = TextEditingController();
  final _contraCtrl  = TextEditingController();
  bool _enviando = false;
  int? _vendedorId;
  late String _titulo;
  late String _imagenUrl;

  @override
  void initState() {
    super.initState();
    _titulo    = widget.titulo;
    _imagenUrl = widget.imagenUrl;
    _cargarVendedor();
    if (_titulo.isEmpty || _imagenUrl.isEmpty) {
      _cargarPublicacion();
    }
  }

  @override
  void dispose() {
    _mensajeCtrl.dispose();
    _contraCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarVendedor() async {
    _vendedorId = await SessionService.obtenerUser();
    if (mounted) setState(() {});
  }

  Future<void> _cargarPublicacion() async {
    try {
      final pub = await ApiService.obtenerPublicacion(widget.publicacionId);
      if (pub != null && mounted) {
        setState(() {
          _titulo    = pub['titulo'] ?? _titulo;
          _imagenUrl = pub['imagen_url'] ?? _imagenUrl;
        });
      }
    } catch (_) {}
  }

  Future<void> _responder(String accion, {double? montoContra}) async {
    if (_vendedorId == null) return;
    setState(() => _enviando = true);

    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/oferta/responder'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'publicacion_id': widget.publicacionId,
          'vendedor_id':    _vendedorId,
          'comprador_id':   widget.compradorId,
          'accion':         accion,
          if (montoContra != null) 'monto_contra': montoContra,
          'mensaje':        _mensajeCtrl.text.trim(),
        }),
      );

      if (!mounted) return;
      // Ir al chat
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            publicacionId:  widget.publicacionId,
            tituloProducto: _titulo,
            imagenUrl:      _imagenUrl,
            vendedorId:     _vendedorId!,
            nombreVendedor: '',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar respuesta')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarContraoferta() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contraofertar',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: _contraCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Tu precio',
                prefixText: '\$',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mensajeCtrl,
              decoration: InputDecoration(
                labelText: 'Mensaje (opcional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final monto = double.tryParse(_contraCtrl.text.trim());
                  if (monto == null || monto <= 0) return;
                  Navigator.pop(context);
                  _responder('contraofertar', montoContra: monto);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Enviar contraoferta',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              size: 18, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Oferta recibida',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: colors.divider),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Producto
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.divider),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      '${ApiService.baseUrl}$_imagenUrl',
                      width: 64, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64, height: 64,
                        color: colors.background,
                        child: Icon(Icons.image,
                            color: colors.grayMid),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _titulo,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Monto oferta
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: colors.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text('Oferta recibida',
                      style: TextStyle(
                          fontSize: 13, color: colors.grayMid)),
                  const SizedBox(height: 8),
                  Text(
                    '\$${widget.monto.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: colors.primary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Mensaje opcional
            Text('Agregar mensaje (opcional)',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _mensajeCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ej: ¡Trato! Podemos coordinar la entrega...',
                hintStyle: TextStyle(
                    color: colors.grayMid, fontSize: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: colors.divider)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: colors.divider)),
                filled: true,
                fillColor: colors.surface,
              ),
            ),

            const SizedBox(height: 32),

            // Botones
            if (_enviando)
              Center(
                  child: CircularProgressIndicator(
                      color: colors.primary))
            else
              Column(
                children: [
                  // Aceptar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _responder('aceptar'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Aceptar oferta',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Contraofertar
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _mostrarContraoferta,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Contraofertar',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(
                            color: colors.primary, width: 1.5),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Rechazar
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _responder('rechazar'),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Rechazar oferta',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(
                            color: Colors.red, width: 1.5),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
