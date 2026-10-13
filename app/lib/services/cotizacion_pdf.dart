import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/format_utils.dart';
import 'cotizaciones_guardadas_service.dart';

/// PDF de una cotización hecho en el teléfono (para imprimir, compartir o
/// guardar en "Mis cotizaciones"). Mismo diseño que el que genera el
/// servidor al enviarla por el chat: logo OK VENTA, emisor/cliente, tabla,
/// totales con la retención de garantía, condiciones, observaciones y
/// Okventín al pie.
class CotizacionPdf {
  CotizacionPdf._();

  static const _rojo = PdfColor.fromInt(0xFFC0545C);
  static const _tinta = PdfColor.fromInt(0xFF22262E);
  static const _gris = PdfColor.fromInt(0xFF6E7480);
  static const _linea = PdfColor.fromInt(0xFFE2E4E9);
  static const _fondoTabla = PdfColor.fromInt(0xFFF2F3F5);

  static String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static DateTime? _fecha(dynamic iso) =>
      iso == null ? null : DateTime.tryParse(iso.toString());

  static Future<Uint8List> generar(Map<String, dynamic> d,
      {required int numero, DateTime? emision}) async {
    final emitida = emision ?? DateTime.now();
    final items = List<Map<String, dynamic>>.from(
        (d['items'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)));
    double num_(dynamic v) => (v as num?)?.toDouble() ?? 0;
    final subtotal = items.fold<double>(
        0, (a, i) => a + num_(i['precio']) * num_(i['cantidad']).clamp(1.0, 1e9).toDouble());
    final descuento = num_(d['descuento']).clamp(0, subtotal).toDouble();
    final impuestos = num_(d['impuestos']);
    final total = subtotal - descuento + impuestos;
    final retencion = (total * kPctRetencionGarantia).roundToDouble();

    pw.MemoryImage? okventin;
    try {
      final b = await rootBundle.load('assets/images/okventin_servicios.png');
      okventin = pw.MemoryImage(b.buffer.asUint8List());
    } catch (_) {}

    final normal = pw.Font.helvetica();
    final negrita = pw.Font.helveticaBold();
    pw.TextStyle st(double t, {bool b = false, PdfColor c = _tinta}) =>
        pw.TextStyle(font: b ? negrita : normal, fontSize: t, color: c);

    pw.Widget fila(String a, String b, {bool fuerte = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text(a, style: st(fuerte ? 12.5 : 9, b: fuerte))),
            pw.Text(b, style: st(fuerte ? 18 : 9.5, b: fuerte)),
          ]),
        );

    pw.Widget hr() => pw.Container(height: 0.8, color: _linea);

    final doc = pw.Document(title: 'Cotización N.º ${numero.toString().padLeft(4, '0')}');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 44, 48, 40),
      footer: (ctx) => pw.Column(children: [
        hr(),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Expanded(
              child: pw.Text('Valores expresados en pesos chilenos (CLP).',
                  style: st(7.5, c: _gris))),
          pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: st(7.5, c: _gris)),
        ]),
      ]),
      build: (ctx) => [
        // Encabezado
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.RichText(
              text: pw.TextSpan(children: [
            pw.TextSpan(text: 'OK ', style: st(26, b: true, c: _rojo)),
            pw.TextSpan(text: 'VENTA', style: st(26, b: true)),
          ])),
          pw.Spacer(),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('COTIZACIÓN', style: st(20, b: true)),
            pw.SizedBox(height: 4),
            pw.Text('N.º ${numero.toString().padLeft(4, '0')}', style: st(10)),
          ]),
        ]),
        pw.SizedBox(height: 14),
        hr(),
        pw.SizedBox(height: 14),
        // Emisor / cliente
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('EMISOR', style: st(8.5, b: true, c: _gris)),
              pw.SizedBox(height: 8),
              pw.Text((d['empresa'] ?? 'Nombre o empresa').toString(), style: st(12.5, b: true)),
              pw.SizedBox(height: 6),
              pw.Text('Fecha de emisión: ${_dmy(emitida)}', style: st(9.5)),
            ]),
          ),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('CLIENTE', style: st(8.5, b: true, c: _gris)),
              pw.SizedBox(height: 8),
              pw.Text((d['cliente_nombre'] ?? 'Nombre del cliente').toString(),
                  style: st(12.5, b: true)),
              pw.SizedBox(height: 6),
              pw.Text(
                  'Válida hasta: ${_dmy(_fecha(d['valida_hasta']) ?? emitida.add(const Duration(days: 7)))}',
                  style: st(9.5)),
            ]),
          ),
        ]),
        pw.SizedBox(height: 14),
        hr(),
        pw.SizedBox(height: 14),
        // Tabla
        pw.Container(
          color: _fondoTabla,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: pw.Row(children: [
            pw.Expanded(flex: 5, child: pw.Text('Producto o servicio', style: st(9.5, b: true))),
            pw.Expanded(
                flex: 2,
                child: pw.Text('Cantidad', textAlign: pw.TextAlign.right, style: st(8.5, b: true))),
            pw.Expanded(
                flex: 3,
                child: pw.Text('Precio unitario',
                    textAlign: pw.TextAlign.right, style: st(8.5, b: true))),
            pw.Expanded(
                flex: 3,
                child: pw.Text('Importe', textAlign: pw.TextAlign.right, style: st(8.5, b: true))),
          ]),
        ),
        for (final i in items)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _linea, width: 0.8))),
            child: pw.Row(children: [
              pw.Expanded(flex: 5, child: pw.Text((i['nombre'] ?? '').toString(), style: st(10))),
              pw.Expanded(
                  flex: 2,
                  child: pw.Text('${num_(i['cantidad']).toInt()}',
                      textAlign: pw.TextAlign.right, style: st(10))),
              pw.Expanded(
                  flex: 3,
                  child: pw.Text(formatPrecio(num_(i['precio'])),
                      textAlign: pw.TextAlign.right, style: st(10))),
              pw.Expanded(
                  flex: 3,
                  child: pw.Text(formatPrecio(num_(i['precio']) * num_(i['cantidad'])),
                      textAlign: pw.TextAlign.right, style: st(10))),
            ]),
          ),
        pw.SizedBox(height: 10),
        // Totales (mitad derecha)
        pw.Row(children: [
          pw.Expanded(child: pw.SizedBox()),
          pw.Expanded(
            child: pw.Column(children: [
              fila('Subtotal', formatPrecio(subtotal)),
              fila('Descuento', '${descuento > 0 ? '-' : ''}${formatPrecio(descuento)}'),
              fila('Impuestos (según corresponda)', formatPrecio(impuestos)),
            ]),
          ),
        ]),
        hr(),
        pw.Row(children: [
          pw.Expanded(child: pw.SizedBox()),
          pw.Expanded(
            child: pw.Column(children: [
              pw.SizedBox(height: 6),
              fila('TOTAL', formatPrecio(total), fuerte: true),
              fila('Retención de garantía (${(kPctRetencionGarantia * 100).round()} %)',
                  formatPrecio(retencion)),
              fila('Pago inicial al prestador', formatPrecio(total - retencion)),
            ]),
          ),
        ]),
        pw.SizedBox(height: 6),
        hr(),
        pw.SizedBox(height: 16),
        pw.Text('GARANTÍA DEL SERVICIO', style: st(10, b: true)),
        pw.SizedBox(height: 6),
        pw.Text(
            'La retención forma parte del total y se libera al prestador cuando el cliente '
            'confirma que el servicio está conforme, o automáticamente a los '
            '$kDiasRetencionGarantia días de finalizar el servicio si el cliente no reporta un problema.',
            style: st(9.5, c: _gris)),
        pw.SizedBox(height: 16),
        pw.Text('CONDICIONES', style: st(10, b: true)),
        pw.SizedBox(height: 8),
        pw.Text('Entrega o ejecución: ${(d['entrega'] ?? '').toString().isEmpty ? 'A convenir' : d['entrega']}',
            style: st(9.5)),
        pw.SizedBox(height: 6),
        pw.Text('Forma de pago: ${(d['forma_pago'] ?? '').toString().isEmpty ? 'A convenir' : d['forma_pago']}',
            style: st(9.5)),
        pw.SizedBox(height: 12),
        hr(),
        pw.SizedBox(height: 14),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('OBSERVACIONES', style: st(10, b: true)),
              pw.SizedBox(height: 6),
              pw.Text(
                  (d['observaciones'] ?? '').toString().trim().isEmpty
                      ? 'Sin observaciones.'
                      : d['observaciones'].toString(),
                  style: st(9.5, c: _gris)),
            ]),
          ),
          if (okventin != null)
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Pago protegido', style: st(8.5, b: true, c: _rojo)),
                pw.Text('con OkVenta', style: st(8.5, c: _gris)),
              ]),
              pw.SizedBox(width: 6),
              pw.Image(okventin, width: 64, height: 80),
            ]),
        ]),
      ],
    ));
    return doc.save();
  }
}
