import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reglas del Seguro Garantía (las mismas del servidor, database/ordenes.py).
const double kPctRetencionGarantia = 0.20;
const int kDiasRetencionGarantia = 30;

/// Cuánto duran las cotizaciones guardadas en el teléfono.
const int kDiasCotizacionGuardada = 30;

/// Una cotización guardada en el teléfono (borrador o ya enviada), con su
/// PDF. Se borra sola a los [kDiasCotizacionGuardada] días.
class CotizacionGuardada {
  final String id;
  final int numero;
  final DateTime creado;
  String estado; // 'borrador' | 'enviada'
  Map<String, dynamic> datos;
  String? pdfPath;
  final int? servicioId;
  final int? proveedorId;
  final int? clienteId;

  CotizacionGuardada({
    required this.id,
    required this.numero,
    required this.creado,
    required this.estado,
    required this.datos,
    this.pdfPath,
    this.servicioId,
    this.proveedorId,
    this.clienteId,
  });

  DateTime get vence => creado.add(const Duration(days: kDiasCotizacionGuardada));
  int get diasRestantes =>
      vence.difference(DateTime.now()).inHours.clamp(0, 1 << 30) ~/ 24;

  Map<String, dynamic> toJson() => {
        'id': id,
        'numero': numero,
        'creado': creado.toIso8601String(),
        'estado': estado,
        'datos': datos,
        'pdfPath': pdfPath,
        'servicioId': servicioId,
        'proveedorId': proveedorId,
        'clienteId': clienteId,
      };

  factory CotizacionGuardada.fromJson(Map<String, dynamic> j) =>
      CotizacionGuardada(
        id: j['id'].toString(),
        numero: (j['numero'] as num?)?.toInt() ?? 0,
        creado: DateTime.tryParse(j['creado']?.toString() ?? '') ??
            DateTime.now(),
        estado: (j['estado'] ?? 'borrador').toString(),
        datos: Map<String, dynamic>.from(j['datos'] as Map? ?? const {}),
        pdfPath: j['pdfPath']?.toString(),
        servicioId: (j['servicioId'] as num?)?.toInt(),
        proveedorId: (j['proveedorId'] as num?)?.toInt(),
        clienteId: (j['clienteId'] as num?)?.toInt(),
      );
}

class CotizacionesGuardadasService {
  CotizacionesGuardadasService._();

  static const _kLista = 'cotizaciones_guardadas_v1';
  static const _kNumero = 'cotizaciones_numero_v1';

  static final ValueNotifier<List<CotizacionGuardada>> lista =
      ValueNotifier<List<CotizacionGuardada>>([]);

  /// Carga y borra las vencidas (más de 30 días), con sus PDF.
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLista);
      final todas = raw == null
          ? <CotizacionGuardada>[]
          : (jsonDecode(raw) as List)
              .map((e) => CotizacionGuardada.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList();
      final ahora = DateTime.now();
      final vigentes = <CotizacionGuardada>[];
      for (final c in todas) {
        if (c.vence.isBefore(ahora)) {
          _borrarArchivo(c.pdfPath);
        } else {
          vigentes.add(c);
        }
      }
      lista.value = vigentes;
      if (vigentes.length != todas.length) await _guardar();
    } catch (_) {}
  }

  static Future<void> _guardar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kLista, jsonEncode(lista.value.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  static void _borrarArchivo(String? p) {
    if (p == null) return;
    try {
      final f = File(p);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  /// Número correlativo para las cotizaciones hechas en este teléfono.
  static Future<int> siguienteNumero() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final n = (prefs.getInt(_kNumero) ?? 0) + 1;
      await prefs.setInt(_kNumero, n);
      return n;
    } catch (_) {
      return DateTime.now().millisecondsSinceEpoch % 10000;
    }
  }

  static Future<String> _rutaPdf(String id) async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/cotizaciones');
    if (!d.existsSync()) d.createSync(recursive: true);
    return '${d.path}/cotizacion_$id.pdf';
  }

  /// Guarda (o actualiza) una cotización y su PDF.
  static Future<CotizacionGuardada> guardar(CotizacionGuardada c,
      {Uint8List? pdf}) async {
    if (pdf != null) {
      final ruta = await _rutaPdf(c.id);
      await File(ruta).writeAsBytes(pdf, flush: true);
      c.pdfPath = ruta;
    }
    final otras = lista.value.where((x) => x.id != c.id).toList();
    lista.value = [c, ...otras];
    await _guardar();
    return c;
  }

  static Future<void> borrar(String id) async {
    final c = lista.value.where((x) => x.id == id).toList();
    lista.value = lista.value.where((x) => x.id != id).toList();
    await _guardar();
    for (final x in c) {
      _borrarArchivo(x.pdfPath);
    }
  }
}
