import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/net_image.dart';
import 'entrega_vendedor_screen.dart';

/// Etiqueta de envío con doble QR (flujo "Lo entrego yo").
///
/// QR "Ruta": el comprador lo escanea para abrir el mapa de tracking.
/// QR "Confirmar entrega": el comprador lo escanea al recibir; lleva un
/// token secreto que el backend valida antes de marcar 'entregado'.
/// La etiqueta puede reimprimirse sin invalidar el token.
class EtiquetaEnvioScreen extends StatefulWidget {
  final int ordenId;
  final String titulo;

  const EtiquetaEnvioScreen({
    super.key,
    required this.ordenId,
    required this.titulo,
  });

  @override
  State<EtiquetaEnvioScreen> createState() => _EtiquetaEnvioScreenState();
}

class _EtiquetaEnvioScreenState extends State<EtiquetaEnvioScreen> {
  Map<String, dynamic>? _etiqueta;
  bool _cargando = true;
  bool _exportando = false;
  final _labelKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final data = await ApiService.obtenerEtiqueta(widget.ordenId);
      if (mounted) setState(() { _etiqueta = data; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Captura la etiqueta como PNG (para imprimir o compartir).
  Future<Uint8List?> _capturarEtiqueta() async {
    try {
      final boundary = _labelKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<pw.Document?> _generarPdf() async {
    final png = await _capturarEtiqueta();
    if (png == null) return null;
    final doc = pw.Document();
    final img = pw.MemoryImage(png);
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Center(child: pw.Image(img, width: 400)),
    ));
    return doc;
  }

  Future<void> _imprimir() async {
    if (_exportando) return;
    setState(() => _exportando = true);
    try {
      final doc = await _generarPdf();
      if (doc != null) {
        await Printing.layoutPdf(onLayout: (_) => doc.save());
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _compartir() async {
    if (_exportando) return;
    setState(() => _exportando = true);
    try {
      final doc = await _generarPdf();
      if (doc != null) {
        await Printing.sharePdf(
            bytes: await doc.save(),
            filename: 'etiqueta_orden_${widget.ordenId}.pdf');
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────
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
                        Text('Etiqueta de envío',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        Text('Paso 1: imprime o guarda la etiqueta',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.grayMid)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _cargando
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : _etiqueta == null
                      ? const Center(
                          child: Text('No se pudo cargar la etiqueta',
                              style: TextStyle(color: AppColors.grayMid)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              RepaintBoundary(
                                key: _labelKey,
                                child: _labelCard(),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          _exportando ? null : _imprimir,
                                      icon: const Icon(Icons.print_rounded,
                                          size: 17),
                                      label: const Text('Imprimir'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: BorderSide(
                                            color: AppColors.primary
                                                .withOpacity(0.5)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          _exportando ? null : _compartir,
                                      icon: const Icon(
                                          Icons.ios_share_rounded,
                                          size: 17),
                                      label: const Text('Descargar'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: BorderSide(
                                            color: AppColors.primary
                                                .withOpacity(0.5)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Si no tienes impresora, guarda la etiqueta y '
                                'muéstrala desde el teléfono al entregar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.grayMid),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EntregaVendedorScreen(
                                          ordenId: widget.ordenId,
                                          titulo: widget.titulo,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                      Icons.local_shipping_rounded,
                                      size: 18),
                                  label: const Text('Comenzar entrega'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    textStyle: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── La etiqueta en sí (lo que se imprime) ────────────────────────────────
  Widget _labelCard() {
    final e = _etiqueta!;
    final imagenUrl = e['imagen_url'] as String?;
    final direccion = e['direccion'] as String? ?? '';
    final comprador = e['comprador_nombre'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Marca + orden
          Row(
            children: [
              const Text('OkVenta',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black)),
              const Spacer(),
              Text('Orden #${e['orden_id']}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54)),
            ],
          ),
          const Divider(height: 20, color: Colors.black26),

          // Producto
          Row(
            children: [
              if (imagenUrl != null && imagenUrl.isNotEmpty)
                NetImage(
                  imagenUrl.startsWith('http')
                      ? imagenUrl
                      : '${ApiService.baseUrl}$imagenUrl',
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(8),
                )
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      color: Colors.black38),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e['titulo'] as String? ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black)),
                    Text(formatPrecio(e['monto']),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Destinatario
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ENTREGAR A',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.black45,
                        letterSpacing: 1)),
                const SizedBox(height: 3),
                if (comprador.isNotEmpty)
                  Text(comprador,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black)),
                Text(direccion.isNotEmpty ? direccion : 'Coordinar con el comprador',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          const Center(
            child: Text('Escanea el código para ver el mapa',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54)),
          ),
          const SizedBox(height: 10),

          // Doble QR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _qrConEtiqueta(e['qr_ruta'] as String? ?? '', 'RUTA',
                  'Ver entrega en el mapa'),
              _qrConEtiqueta(e['qr_confirmar'] as String? ?? '',
                  'CONFIRMAR ENTREGA', 'Escanear al recibir'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qrConEtiqueta(String data, String titulo, String subtitulo) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: QrImageView(
            data: data,
            size: 120,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(titulo,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.black)),
        Text(subtitulo,
            style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }
}
