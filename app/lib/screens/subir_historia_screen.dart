import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/historias_service.dart';

/// Publicar una historia: elegir foto (cámara o galería), ver cómo queda,
/// escribir un texto opcional y publicar. Dura 24 h; desde el visor se
/// puede dejar destacada con el corazón.
class SubirHistoriaScreen extends StatefulWidget {
  final int userId;
  final File foto;
  const SubirHistoriaScreen({super.key, required this.userId, required this.foto});

  /// Pregunta cámara o galería, y abre la pantalla. true si se publicó.
  static Future<bool> iniciar(BuildContext context, int userId) async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          const Text('Nueva historia',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (origen == null || !context.mounted) return false;
    final x = await ImagePicker().pickImage(
        source: origen, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (x == null || !context.mounted) return false;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => SubirHistoriaScreen(userId: userId, foto: File(x.path))),
    );
    return ok == true;
  }

  @override
  State<SubirHistoriaScreen> createState() => _SubirHistoriaScreenState();
}

class _SubirHistoriaScreenState extends State<SubirHistoriaScreen> {
  final _texto = TextEditingController();
  bool _subiendo = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _publicar() async {
    setState(() => _subiendo = true);
    final error =
        await HistoriasService.subir(widget.userId, widget.foto, _texto.text.trim());
    if (!mounted) return;
    setState(() => _subiendo = false);
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Historia publicada: se verá por 24 horas')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Nueva historia'),
      ),
      body: Column(children: [
        Expanded(child: Center(child: Image.file(widget.foto, fit: BoxFit.contain))),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _texto,
                  maxLength: 200,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Escribe algo (opcional)…',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _subiendo ? null : _publicar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                child: _subiendo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Publicar'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
