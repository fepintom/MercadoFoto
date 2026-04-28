import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // ── URL del servidor ─────────────────────────────────────────────────────
  // 💻 Desarrollo local (WiFi)
  // static const String baseUrl = "http://192.168.1.82:8000";

  // 🌐 Producción (Render)
  static const String baseUrl = "https://okventa-backend.onrender.com";

  // ──────────────────────────────────────────────
  // ANÁLISIS IA
  // ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> enviarImagen(File file) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analizar'));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    var response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      return jsonDecode(respStr);
    } else {
      throw Exception("Error al analizar imagen");
    }
  }

  // ──────────────────────────────────────────────
  // PUBLICACIONES
  // ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> obtenerPublicaciones({
    String? categoria,
    String? subcategoria,
  }) async {
    var uri = Uri.parse('$baseUrl/publicaciones');
    final params = <String, String>{};
    if (categoria != null) params['categoria'] = categoria;
    if (subcategoria != null) params['subcategoria'] = subcategoria;
    if (params.isNotEmpty) uri = uri.replace(queryParameters: params);

    final response = await http.get(uri);
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> buscarPublicaciones(
      String query) async {
    final uri = Uri.parse('$baseUrl/buscar').replace(
      queryParameters: {'q': query},
    );
    final response = await http.get(uri);
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> editarPublicacion({
    required int id,
    required String titulo,
    required String descripcion,
    required double precio,
    List<String> fotosMantener = const [],
    List<File> fotosNuevas = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/publicaciones/$id');
    final request = http.MultipartRequest('PUT', uri);

    request.fields['titulo'] = titulo;
    request.fields['descripcion'] = descripcion;
    request.fields['precio'] = precio.toString();

    if (fotosMantener.isNotEmpty) {
      request.fields['fotos_mantener'] = jsonEncode(fotosMantener);
    }

    final slots = ['file1', 'file2', 'file3'];
    for (int i = 0; i < fotosNuevas.length && i < 3; i++) {
      request.files.add(
        await http.MultipartFile.fromPath(slots[i], fotosNuevas[i].path),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception("Error al editar publicación: ${response.body}");
    }
  }

  static Future<void> eliminarPublicacion(int id, {int? userId}) async {
    var uri = Uri.parse('$baseUrl/publicaciones/$id');
    if (userId != null) {
      uri = uri.replace(queryParameters: {'user_id': userId.toString()});
    }
    final response = await http.delete(uri);
    if (response.statusCode != 200) {
      throw Exception("Error ${response.statusCode} al eliminar publicación");
    }
  }

  static Future<void> cambiarEstado(int id, String estado) async {
    await http.post(
      Uri.parse('$baseUrl/estado_publicacion'),
      body: {
        'publicacion_id': id.toString(),
        'estado': estado,
      },
    );
  }

  // ──────────────────────────────────────────────
  // GEOLOCALIZACIÓN
  // ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> obtenerPublicacionesCercanas({
    required double lat,
    required double lng,
    double radioKm = 5.0,
  }) async {
    final uri = Uri.parse('$baseUrl/publicaciones/cercanas').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radio_km': radioKm.toString(),
      },
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  static Future<void> actualizarUbicacion({
    required int userId,
    required double lat,
    required double lng,
    String? direccion,
    String? comuna,
    String? ciudad,
  }) async {
    await http.put(
      Uri.parse('$baseUrl/usuarios/$userId/ubicacion'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "lat": lat,
        "lng": lng,
        "direccion": direccion,
        "comuna": comuna,
        "ciudad": ciudad,
      }),
    );
  }

  // ──────────────────────────────────────────────
  // FAVORITOS
  // ──────────────────────────────────────────────

  static Future<bool> esFavorito(int userId, int publicacionId) async {
    final uri = Uri.parse('$baseUrl/favorito/check').replace(
      queryParameters: {
        'user_id': userId.toString(),
        'publicacion_id': publicacionId.toString(),
      },
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['es_favorito'] == true;
    }
    return false;
  }

  static Future<void> guardarFavorito(int userId, int publicacionId) async {
    final uri = Uri.parse('$baseUrl/favorito').replace(
      queryParameters: {
        'user_id': userId.toString(),
        'publicacion_id': publicacionId.toString(),
      },
    );
    await http.post(uri);
  }

  static Future<void> quitarFavorito(int userId, int publicacionId) async {
    final uri = Uri.parse('$baseUrl/favorito').replace(
      queryParameters: {
        'user_id': userId.toString(),
        'publicacion_id': publicacionId.toString(),
      },
    );
    await http.delete(uri);
  }

  static Future<List<Map<String, dynamic>>> obtenerFavoritos(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/favoritos/$userId/completos'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  // ──────────────────────────────────────────────
  // CHAT
  // ──────────────────────────────────────────────

  static Future<void> enviarMensaje({
    required int publicacionId,
    required int remitenteId,
    required String mensaje,
  }) async {
    await http.post(
      Uri.parse('$baseUrl/chat/enviar'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "publicacion_id": publicacionId,
        "remitente_id": remitenteId,
        "mensaje": mensaje,
      }),
    );
  }

  static Future<List<Map<String, dynamic>>> obtenerChat(
      int publicacionId) async {
    final response = await http.get(Uri.parse('$baseUrl/chat/$publicacionId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  // ──────────────────────────────────────────────
  // INTERÉS DE COMPRA
  // ──────────────────────────────────────────────

  static Future<void> registrarInteres({
    required int publicacionId,
    required int compradorId,
  }) async {
    await http.post(
      Uri.parse('$baseUrl/interes_compra/$publicacionId').replace(
        queryParameters: {'comprador_id': compradorId.toString()},
      ),
    );
  }

  // ──────────────────────────────────────────────
  // NOTIFICACIONES
  // ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> obtenerNotificaciones(
      int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/notificaciones/$userId'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }
}
