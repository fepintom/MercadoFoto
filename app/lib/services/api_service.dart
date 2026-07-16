import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // ── URL del servidor ─────────────────────────────────────────────────────
  // 💻 Desarrollo local (WiFi)
  // static const String baseUrl = "http://192.168.1.81:8000";

  // 🌐 Producción (Render)
  static const String baseUrl = "https://okventa-backend.onrender.com";

  // ──────────────────────────────────────────────
  // CARGA MASIVA
  // ──────────────────────────────────────────────

  static Future<void> enviarPlantilla(String email) async {
    final uri = Uri.parse('$baseUrl/enviar_plantilla')
        .replace(queryParameters: {'email': email});
    final response = await http.post(uri);
    if (response.statusCode != 200) {
      throw Exception("No se pudo enviar la plantilla: ${response.body}");
    }
  }

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
    String condicion = 'nuevo',
    bool aceptaOfertas = true,
  }) async {
    final uri = Uri.parse('$baseUrl/publicaciones/$id');
    final request = http.MultipartRequest('PUT', uri);

    request.fields['titulo'] = titulo;
    request.fields['descripcion'] = descripcion;
    request.fields['precio'] = precio.toString();
    request.fields['condicion'] = condicion;
    request.fields['acepta_ofertas'] = aceptaOfertas ? '1' : '0';

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

  static Future<void> guardarInfoAdicional(
    int id, {
    String? sku,
    int? stock,
    String? codigoUniversal,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/publicaciones/$id/info-adicional'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sku': sku,
        'stock': stock,
        'codigo_universal': codigoUniversal,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception("Error al guardar info adicional: ${response.body}");
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

  static Future<List<Map<String, dynamic>>> obtenerConversaciones(
      int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/conversaciones/$userId'),
    );
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

  static Future<void> marcarNotificacionesLeidas(int userId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/notificaciones/$userId/marcar-leidas'),
      );
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> obtenerServicios(
      {String? tipo}) async {
    var uri = Uri.parse('$baseUrl/servicios');
    if (tipo != null) {
      uri = uri.replace(queryParameters: {'tipo': tipo});
    }
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  static Future<Map<String, dynamic>?> obtenerPublicacion(
      int publicacionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/publicaciones/$publicacionId'),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)));
    }
    return null;
  }

  // ──────────────────────────────────────────────
  // PAGOS / MERCADOPAGO
  // ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> crearPreferencia({
    required int compradorId,
    required int vendedorId,
    required String tipo, // 'producto' | 'servicio'
    required String titulo,
    required double monto,
    int? publicacionId,
    int? servicioId,
    String compradorEmail = '',
    String imagenUrl = '',
  }) async {
    final body = <String, dynamic>{
      'comprador_id': compradorId,
      'vendedor_id': vendedorId,
      'tipo': tipo,
      'titulo': titulo,
      'monto': monto,
      'comprador_email': compradorEmail,
      'imagen_url': imagenUrl,
    };
    if (publicacionId != null) body['publicacion_id'] = publicacionId;
    if (servicioId != null) body['servicio_id'] = servicioId;

    final response = await http.post(
      Uri.parse('$baseUrl/pagos/crear-preferencia'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Error al crear preferencia: ${response.body}');
  }

  static Future<List<Map<String, dynamic>>> obtenerMisCompras(
      int userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/mis-compras/$userId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> obtenerMisVentas(
      int userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/mis-ventas/$userId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  static Future<void> confirmarOrden(int ordenId) async {
    await http.post(Uri.parse('$baseUrl/ordenes/$ordenId/confirmar'));
  }

  static Future<void> disputarOrden(int ordenId) async {
    await http.post(Uri.parse('$baseUrl/ordenes/$ordenId/disputar'));
  }

  // ──────────────────────────────────────────────
  // DELIVERY OKVENTA
  // ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> obtenerDelivery(
      {bool soloActivos = true}) async {
    final uri = Uri.parse('$baseUrl/delivery')
        .replace(queryParameters: {'solo_activos': soloActivos.toString()});
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  static Future<Map<String, dynamic>?> obtenerDeliveryUsuario(
      int userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/delivery/usuario/$userId'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)));
    }
    return null;
  }

  static Future<bool> toggleDeliveryActivo(
      int deliveryId, int userId, bool activo) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/delivery/$deliveryId/estado'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'activo': activo}),
    );
    return response.statusCode == 200;
  }

  // ── Ayuda / Soporte ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> crearTicketAyuda({
    required int userId,
    required String tipo,
    String numeroReferencia = '',
    required String detalle,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ayuda'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id':           userId,
        'tipo':              tipo,
        'numero_referencia': numeroReferencia,
        'detalle':           detalle,
      }),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)));
    }
    throw Exception('Error al crear ticket de ayuda');
  }

  static Future<Map<String, dynamic>> crearChatDirecto(int userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ayuda/chat_directo'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)));
    }
    throw Exception('Error al iniciar chat directo');
  }

  static Future<List<Map<String, dynamic>>> obtenerTicketsAyuda(
      int userId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/ayuda/usuario/$userId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data['tickets'] ?? []);
    }
    return [];
  }

  static Future<Map<String, dynamic>> obtenerMensajesTicket(
      int ticketId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/ayuda/$ticketId/mensajes'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)));
    }
    return {};
  }

  static Future<bool> enviarMensajeTicket(
      int ticketId, String mensaje) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ayuda/$ticketId/mensaje_usuario'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mensaje': mensaje}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> cerrarTicketAyuda(int ticketId, int userId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/ayuda/$ticketId/cerrar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    return response.statusCode == 200;
  }

  // ── Entrega de orden ───────────────────────────────────────────────────────

  // ── Servicios (Ofrezco/Busco) ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> obtenerMisServicios(
      int userId) async {
    final response = await http.get(
        Uri.parse('$baseUrl/servicios/usuario/$userId/mis_servicios'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data is List ? data : []);
    }
    throw Exception('Error al obtener mis servicios');
  }

  static Future<void> registrarContactoServicio(
      int servicioId, int? contactanteId, String tipo, String nombre) async {
    await http.post(
      Uri.parse('$baseUrl/servicios/$servicioId/contacto'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contactante_id': contactanteId,
        'tipo':           tipo,
        'nombre':         nombre,
      }),
    );
  }

  static Future<List<Map<String, dynamic>>> obtenerContactosServicio(
      int servicioId, int ownerId) async {
    final response = await http.get(Uri.parse(
        '$baseUrl/servicios/$servicioId/contactos?owner_id=$ownerId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data['contactos'] ?? []);
    }
    return [];
  }

  // ───────────────────────────────────────────────────────────────────────────

  static Future<void> elegirEntrega({
    required int ordenId,
    required String method,
    int? deliveryId,
    String? blueExpressPunto,
  }) async {
    // Nota: el backend lee 'delivery_method' (no 'method').
    final body = <String, dynamic>{'delivery_method': method};
    if (deliveryId != null) body['delivery_id'] = deliveryId;
    if (blueExpressPunto != null) body['blue_express_punto'] = blueExpressPunto;
    final response = await http.patch(
      Uri.parse('$baseUrl/ordenes/$ordenId/entrega'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al elegir entrega: ${response.body}');
    }
  }

  // ──────────────────────────────────────────────
  // TRACKING VENDEDOR (entrego yo)
  // ──────────────────────────────────────────────

  static Future<void> enviarTrackingVendedor(
      int ordenId, double lat, double lng) async {
    await http.post(
      Uri.parse('$baseUrl/ordenes/$ordenId/tracking'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
  }

  static Future<Map<String, dynamic>?> obtenerTrackingVendedor(
      int ordenId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/ordenes/$ordenId/tracking'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)));
    }
    return null;
  }

  // ──────────────────────────────────────────────
  // ETIQUETA DE ENVÍO (doble QR)
  // ──────────────────────────────────────────────

  static Future<Map<String, dynamic>?> obtenerEtiqueta(int ordenId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/ordenes/$ordenId/etiqueta'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)));
    }
    return null;
  }

  static Future<void> confirmarEntregaQr({
    required int ordenId,
    required int userId,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ordenes/$ordenId/confirmar-entrega'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'user_id': userId}),
    );
    if (response.statusCode != 200) {
      String msg = response.body;
      try {
        msg = jsonDecode(utf8.decode(response.bodyBytes))['detail'] ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }

  // ──────────────────────────────────────────────
  // EVIDENCIA DE ENTREGA (doble confirmación con foto, entrega 'yo')
  // ──────────────────────────────────────────────

  static Future<void> reportarEntregaConFoto({
    required int ordenId,
    required int userId,
    required File foto,
    double? lat,
    double? lng,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ordenes/$ordenId/reportar-entrega'),
    );
    request.fields['user_id'] = userId.toString();
    request.fields['capturado_en'] = DateTime.now().toIso8601String();
    if (lat != null) request.fields['lat'] = lat.toString();
    if (lng != null) request.fields['lng'] = lng.toString();
    request.files.add(await http.MultipartFile.fromPath('foto', foto.path));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Error al reportar entrega: ${response.body}');
    }
  }

  static Future<void> confirmarRecepcionConFoto({
    required int ordenId,
    required int userId,
    required File foto,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ordenes/$ordenId/confirmar-recepcion'),
    );
    request.fields['user_id'] = userId.toString();
    request.fields['capturado_en'] = DateTime.now().toIso8601String();
    request.files.add(await http.MultipartFile.fromPath('foto', foto.path));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Error al confirmar recepción: ${response.body}');
    }
  }

  static Future<void> reportarProblemaOrden({
    required int ordenId,
    required int userId,
    required String motivo,
    String? descripcion,
    File? fotoReclamo,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/ordenes/$ordenId/reportar-problema'),
    );
    request.fields['user_id'] = userId.toString();
    request.fields['motivo'] = motivo;
    if (descripcion != null && descripcion.isNotEmpty) {
      request.fields['descripcion'] = descripcion;
    }
    if (fotoReclamo != null) {
      request.files.add(
          await http.MultipartFile.fromPath('foto_reclamo', fotoReclamo.path));
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Error al reportar problema: ${response.body}');
    }
  }

  // ──────────────────────────────────────────────
  // OKDELIVERY — flujo de entrega propia (retiro, tracking, entrega, evidencia)
  // ──────────────────────────────────────────────

  static Future<Map<String, dynamic>?> obtenerEntregaOkdelivery(
      int ordenId) async {
    final response = await http.get(Uri.parse('$baseUrl/okdelivery/$ordenId'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)));
    }
    return null;
  }

  static Future<Map<String, dynamic>?> trackingOkdelivery(int ordenId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/okdelivery/$ordenId/tracking'));
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(
          jsonDecode(utf8.decode(response.bodyBytes)));
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> entregasActivasRepartidor(
      int deliveryId) async {
    final response = await http.get(
        Uri.parse('$baseUrl/okdelivery/repartidor/$deliveryId/activas'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> pendientesOkdelivery(
      int deliveryId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/okdelivery/pendientes/$deliveryId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  static Future<void> aceptarEntregaOkdelivery(
      int ordenId, int deliveryId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/okdelivery/$ordenId/aceptar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'delivery_id': deliveryId}),
    );
    if (response.statusCode != 200) {
      throw Exception('No se pudo aceptar la entrega: ${response.body}');
    }
  }

  static Future<String?> actualizarUbicacionOkdelivery(
      int ordenId, double lat, double lng) async {
    final response = await http.post(
      Uri.parse('$baseUrl/okdelivery/$ordenId/ubicacion'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'lat': lat, 'lng': lng}),
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body)['estado']) as String?;
    }
    return null;
  }

  static Future<void> llegueRetiroOkdelivery(int ordenId) async {
    await http.post(Uri.parse('$baseUrl/okdelivery/$ordenId/llegue_retiro'));
  }

  static Future<void> entregueADeliveryOkdelivery(int ordenId) async {
    await http
        .post(Uri.parse('$baseUrl/ventas/$ordenId/entregue_a_delivery'));
  }

  static Future<void> confirmarRecepcionRepartidor({
    required int ordenId,
    required String estadoProducto, // 'ok' | 'con_observaciones'
    String? observaciones,
    required File foto,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/okdelivery/$ordenId/confirmar_recepcion'),
    );
    request.fields['estado_producto'] = estadoProducto;
    if (observaciones != null) request.fields['observaciones'] = observaciones;
    request.files.add(await http.MultipartFile.fromPath('foto', foto.path));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Error al confirmar recepción: ${response.body}');
    }
  }

  static Future<void> repararProductoOkdelivery(int ordenId) async {
    await http.post(Uri.parse('$baseUrl/ventas/$ordenId/reparar'));
  }

  static Future<void> noRepararProductoOkdelivery(int ordenId) async {
    await http.post(Uri.parse('$baseUrl/ventas/$ordenId/no_reparar'));
  }

  static Future<void> confirmarReparacionOkdelivery(int ordenId) async {
    await http
        .post(Uri.parse('$baseUrl/okdelivery/$ordenId/confirmar_reparacion'));
  }

  static Future<void> llegueEntregaOkdelivery(int ordenId) async {
    await http.post(Uri.parse('$baseUrl/okdelivery/$ordenId/llegue_entrega'));
  }

  static Future<void> confirmarEntregaRepartidor(
      int ordenId, File foto) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/okdelivery/$ordenId/confirmar_entrega'),
    );
    request.files.add(await http.MultipartFile.fromPath('foto', foto.path));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Error al confirmar entrega: ${response.body}');
    }
  }

  static Future<void> confirmarRecepcionComprador(
      int ordenId, {File? video}) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/compras/$ordenId/confirmar_recepcion'),
    );
    if (video != null) {
      request.files.add(await http.MultipartFile.fromPath('video', video.path));
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Error al confirmar recepción: ${response.body}');
    }
  }

  static Future<void> reclamoComprador({
    required int ordenId,
    required String texto,
    required File video,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/compras/$ordenId/reclamo'),
    );
    request.fields['texto'] = texto;
    request.files.add(await http.MultipartFile.fromPath('video', video.path));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Error al enviar el reclamo: ${response.body}');
    }
  }

  // ── Mis Direcciones ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> obtenerDirecciones(int userId) async {
    final res = await http.get(Uri.parse('$baseUrl/usuarios/$userId/direcciones'));
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    return [];
  }

  static Future<Map<String, dynamic>> agregarDireccion(
    int userId, {
    required String etiqueta,
    required String direccion,
    String comuna = '',
    String ciudad = '',
    double? lat,
    double? lng,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/usuarios/$userId/direcciones'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'etiqueta': etiqueta,
        'direccion': direccion,
        'comuna': comuna,
        'ciudad': ciudad,
        'lat': lat,
        'lng': lng,
      }),
    );
    if (res.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(res.body));
    throw Exception('Error al agregar dirección');
  }

  static Future<void> actualizarDireccion(
    int userId,
    int addressId, {
    required String etiqueta,
    required String direccion,
    String comuna = '',
    String ciudad = '',
    double? lat,
    double? lng,
  }) async {
    await http.put(
      Uri.parse('$baseUrl/usuarios/$userId/direcciones/$addressId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'etiqueta': etiqueta,
        'direccion': direccion,
        'comuna': comuna,
        'ciudad': ciudad,
        'lat': lat,
        'lng': lng,
      }),
    );
  }

  static Future<void> eliminarDireccion(int userId, int addressId) async {
    await http.delete(Uri.parse('$baseUrl/usuarios/$userId/direcciones/$addressId'));
  }

  static Future<void> establecerPrincipal(int userId, int addressId) async {
    await http.patch(Uri.parse('$baseUrl/usuarios/$userId/direcciones/$addressId/principal'));
  }
}
