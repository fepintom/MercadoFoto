import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://192.168.1.83:8000";

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

  static Future<void> publicarProducto({
    required String titulo,
    required String descripcion,
    required String precio,
    required String imagenUrl,
    required String guestId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/publicar'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "titulo": titulo,
        "descripcion": descripcion,
        "precio": double.parse(precio),
        "imagen_url": imagenUrl,
        "guest_id": guestId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Error al publicar");
    }
  }
}
