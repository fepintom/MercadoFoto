import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'navigation_service.dart';

/// Un borrador: una publicación que no se alcanzó a terminar.
///
/// - `analizando`: la IA todavía está leyendo la foto (el usuario se fue a
///   mirar OkMarket mientras tanto).
/// - `listo`: ya tiene título, descripción y precio sugerido; falta que el
///   usuario confirme y publique.
/// - `error`: el análisis falló; se puede reintentar desde la lista.
class Borrador {
  final String id;
  String data; // JSON igual al que devuelve /analizar (+ lo que el usuario editó)
  final List<String> imagenes; // rutas locales (copiadas a la app)
  String estado;
  final DateTime creado;

  Borrador({
    required this.id,
    required this.data,
    required this.imagenes,
    required this.estado,
    required this.creado,
  });

  Map<String, dynamic> get datos {
    try {
      return Map<String, dynamic>.from(jsonDecode(data) as Map);
    } catch (_) {
      return {};
    }
  }

  String get titulo {
    final t = (datos['titulo'] ?? '').toString().trim();
    return t.isEmpty ? 'Publicación sin título' : t;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'data': data,
        'imagenes': imagenes,
        'estado': estado,
        'creado': creado.toIso8601String(),
      };

  factory Borrador.fromJson(Map<String, dynamic> j) => Borrador(
        id: j['id'].toString(),
        data: (j['data'] ?? '{}').toString(),
        imagenes: List<String>.from(j['imagenes'] ?? const []),
        estado: (j['estado'] ?? 'listo').toString(),
        creado: DateTime.tryParse(j['creado']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// Un análisis de foto en curso. Si el usuario decide seguir mirando
/// OkMarket ([mandarAlFondo]), al terminar queda como borrador.
class TareaAnalisis {
  final File imagen;
  final Future<String> resultado;
  bool _alFondo = false;
  TareaAnalisis._(this.imagen, this.resultado);

  bool get enSegundoPlano => _alFondo;

  /// El usuario se fue: se crea el borrador "analizando" y, cuando la IA
  /// termine, pasa a "listo" (o "error") y se avisa.
  Future<void> mandarAlFondo() async {
    if (_alFondo) return;
    _alFondo = true;
    final b = await BorradoresService.crear(
        data: '{}', imagenes: [imagen], estado: 'analizando');
    try {
      final r = await resultado;
      b.data = r;
      b.estado = 'listo';
      await BorradoresService.actualizar(b);
      BorradoresService.avisar('Tu publicación está lista en Borradores');
    } catch (_) {
      b.estado = 'error';
      await BorradoresService.actualizar(b);
      BorradoresService.avisar(
          'No pudimos analizar la foto. Reinténtalo desde Borradores');
    }
  }
}

class BorradoresService {
  BorradoresService._();

  static const _kLista = 'borradores_v1';
  static const _kTiempos = 'tiempos_publicacion_v1';

  static final ValueNotifier<List<Borrador>> lista =
      ValueNotifier<List<Borrador>>([]);
  static bool _cargado = false;

  /// Pantalla que abre la lista (la registra el Home para evitar imports
  /// circulares).
  static void Function(BuildContext)? abrirLista;

  static Future<void> cargar() async {
    if (_cargado) return;
    _cargado = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLista);
      if (raw == null) return;
      final l = (jsonDecode(raw) as List)
          .map((e) => Borrador.fromJson(Map<String, dynamic>.from(e as Map)))
          // Si la app se cerró mientras analizaba, ese análisis se perdió:
          // queda para reintentar.
          .map((b) => b..estado = b.estado == 'analizando' ? 'error' : b.estado)
          .where((b) => b.imagenes.every((p) => File(p).existsSync()))
          .toList();
      lista.value = l;
    } catch (_) {}
  }

  static Future<void> _guardar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kLista, jsonEncode(lista.value.map((b) => b.toJson()).toList()));
    } catch (_) {}
  }

  static Future<Directory> _carpeta() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/borradores');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static String _nuevoId() =>
      '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999)}';

  /// Guarda un borrador copiando las fotos dentro de la app (las del
  /// selector de fotos son temporales y el sistema puede borrarlas).
  static Future<Borrador> crear({
    required String data,
    required List<File> imagenes,
    String estado = 'listo',
  }) async {
    await cargar();
    final id = _nuevoId();
    final dir = await _carpeta();
    final rutas = <String>[];
    for (var i = 0; i < imagenes.length; i++) {
      final f = imagenes[i];
      final ext = f.path.contains('.') ? f.path.split('.').last : 'jpg';
      final destino = '${dir.path}/${id}_$i.$ext';
      try {
        await f.copy(destino);
        rutas.add(destino);
      } catch (_) {
        rutas.add(f.path);
      }
    }
    final b = Borrador(
        id: id,
        data: data,
        imagenes: rutas,
        estado: estado,
        creado: DateTime.now());
    lista.value = [b, ...lista.value];
    await _guardar();
    return b;
  }

  static Future<void> actualizar(Borrador b) async {
    lista.value = [
      for (final x in lista.value) x.id == b.id ? b : x,
    ];
    await _guardar();
  }

  static Future<void> borrar(String id) async {
    final b = lista.value.where((x) => x.id == id).toList();
    lista.value = lista.value.where((x) => x.id != id).toList();
    await _guardar();
    for (final x in b) {
      for (final p in x.imagenes) {
        if (p.contains('/borradores/')) {
          try {
            File(p).deleteSync();
          } catch (_) {}
        }
      }
    }
  }

  // ── Análisis de la foto (IA) ─────────────────────────────────────────────

  static Future<String> _pedirAnalisis(File imagen) async {
    final inicio = DateTime.now();
    final req = http.MultipartRequest(
        'POST', Uri.parse('${ApiService.baseUrl}/analizar'));
    req.files.add(await http.MultipartFile.fromPath('file', imagen.path));
    final resp = await req.send().timeout(const Duration(minutes: 3));
    final cuerpo = await resp.stream.bytesToString();
    if (resp.statusCode != 200) {
      throw Exception('analizar ${resp.statusCode}');
    }
    registrarDuracion('analizar', DateTime.now().difference(inicio));
    return cuerpo;
  }

  static TareaAnalisis analizar(File imagen) =>
      TareaAnalisis._(imagen, _pedirAnalisis(imagen));

  /// Reintenta un borrador con error (o lo vuelve a analizar).
  static Future<void> reintentar(Borrador b) async {
    if (b.imagenes.isEmpty) return;
    b.estado = 'analizando';
    await actualizar(b);
    try {
      b.data = await _pedirAnalisis(File(b.imagenes.first));
      b.estado = 'listo';
    } catch (_) {
      b.estado = 'error';
    }
    await actualizar(b);
  }

  // ── Tiempo estimado ──────────────────────────────────────────────────────

  static const _porDefecto = {'analizar': 14, 'publicar': 12};

  /// Cuánto suele tardar cada etapa en este teléfono (promedio móvil de las
  /// últimas veces; la primera vez, un valor razonable).
  static Future<Duration> estimado(String etapa) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTiempos);
      if (raw != null) {
        final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final s = (m[etapa] as num?)?.toDouble();
        if (s != null && s > 1) return Duration(milliseconds: (s * 1000).round());
      }
    } catch (_) {}
    return Duration(seconds: _porDefecto[etapa] ?? 12);
  }

  static Future<void> registrarDuracion(String etapa, Duration d) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTiempos);
      final m = raw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final nuevo = d.inMilliseconds / 1000.0;
      final viejo = (m[etapa] as num?)?.toDouble();
      m[etapa] = viejo == null ? nuevo : viejo * 0.6 + nuevo * 0.4;
      await prefs.setString(_kTiempos, jsonEncode(m));
    } catch (_) {}
  }

  // ── Aviso ────────────────────────────────────────────────────────────────

  static void avisar(String texto, {bool conVer = true}) {
    final ctx = rootContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C1C1E),
        duration: const Duration(seconds: 5),
        action: !conVer || abrirLista == null
            ? null
            : SnackBarAction(
                label: 'Ver',
                textColor: const Color(0xFFFF5A5A),
                onPressed: () {
                  final c = rootContext;
                  if (c != null && c.mounted) abrirLista!(c);
                },
              ),
      ));
  }
}
