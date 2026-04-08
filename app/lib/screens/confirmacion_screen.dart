import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'mis_publicaciones_screen.dart';

class ConfirmacionScreen extends StatefulWidget {
  final String data;
  final File imagen;

  const ConfirmacionScreen({
    super.key,
    required this.data,
    required this.imagen,
  });

  @override
  State<ConfirmacionScreen> createState() => _ConfirmacionScreenState();
}

class _ConfirmacionScreenState extends State<ConfirmacionScreen> {
  late TextEditingController titulo;
  late TextEditingController descripcion;
  late TextEditingController dimensiones;
  final precio = TextEditingController();

  @override
  void initState() {
    super.initState();

    final jsonData = jsonDecode(widget.data);

    titulo = TextEditingController(text: jsonData["titulo"] ?? "");
    descripcion = TextEditingController(text: jsonData["descripcion"] ?? "");
    dimensiones = TextEditingController(text: jsonData["dimensiones"] ?? "");
  }

  Future<void> publicar() async {
    if (precio.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa un precio")),
      );
      return;
    }

    try {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse("${ApiService.baseUrl}/publicar"),
      );

      request.fields["titulo"] = titulo.text.trim();
      request.fields["descripcion"] = descripcion.text.trim();
      request.fields["precio"] = precio.text.trim();
      request.fields["dimensiones"] = dimensiones.text.trim();

      request.files.add(
        await http.MultipartFile.fromPath("file", widget.imagen.path),
      );

      final session = await SessionService.obtenerSesion();

      if (session["user_id"] != null) {
        request.fields["user_id"] = session["user_id"].toString();
      } else {
        request.fields["guest_id"] = session["guest_id"].toString();
      }

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        debugPrint("ERROR PUBLICAR: $respStr");
        throw Exception("Error al publicar");
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MisPublicacionesScreen()),
      );
    } catch (e) {
      debugPrint("ERROR PUBLICAR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error al publicar el producto"),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Widget campo(String label, TextEditingController controller,
      {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: AppColors.grayMid,
            fontSize: 14,
          ),
          filled: true,
          fillColor: readOnly ? AppColors.background : AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Confirmar producto",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.carbon),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppColors.divider, height: 0.5),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Imagen preview
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              widget.imagen,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(height: 24),

          // Campos editables
          campo("Título", titulo),
          campo("Descripción", descripcion),

          // Dimensiones — solo lectura, generado por IA
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              campo("Dimensiones estimadas", dimensiones, readOnly: true),
              Padding(
                padding: const EdgeInsets.only(top: 0, bottom: 16, left: 4),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 13, color: AppColors.grayMid),
                    const SizedBox(width: 4),
                    const Text(
                      "Estimado por IA — solo visible para compradores registrados",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.grayMid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Precio
          TextField(
            controller: precio,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: "Precio",
              labelStyle: const TextStyle(
                color: AppColors.grayMid,
                fontSize: 14,
              ),
              prefixText: "\$ ",
              prefixStyle: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.divider, width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.divider, width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: publicar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text("Publicar"),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
