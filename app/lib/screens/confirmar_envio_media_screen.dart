import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

/// Lo que se envía y el comentario que lo acompaña.
class EnvioMedia {
  final File archivo;
  final String comentario;

  const EnvioMedia(this.archivo, this.comentario);
}

/// Paso intermedio entre elegir una foto o video y enviarlo.
///
/// Antes se enviaba en el instante en que se soltaba el dedo en la galería:
/// no había forma de ver qué se había elegido, ni de acompañarlo con una
/// explicación, ni de arrepentirse. En un chat donde las fotos son la
/// evidencia de un trabajo, mandar la equivocada es un problema real.
///
/// Devuelve un [EnvioMedia] al confirmar, o null si el usuario cancela.
class ConfirmarEnvioMediaScreen extends StatefulWidget {
  final File archivo;
  final bool esVideo;

  const ConfirmarEnvioMediaScreen({
    super.key,
    required this.archivo,
    this.esVideo = false,
  });

  @override
  State<ConfirmarEnvioMediaScreen> createState() =>
      _ConfirmarEnvioMediaScreenState();
}

class _ConfirmarEnvioMediaScreenState
    extends State<ConfirmarEnvioMediaScreen> {
  final _comentarioCtrl = TextEditingController();
  VideoPlayerController? _video;
  bool _videoListo = false;

  @override
  void initState() {
    super.initState();
    if (widget.esVideo) {
      final c = VideoPlayerController.file(widget.archivo);
      _video = c;
      c.initialize().then((_) {
        if (!mounted) return;
        c.setLooping(true);
        c.play();
        setState(() => _videoListo = true);
      }).catchError((_) {
        // Si la vista previa falla igual se puede enviar: el archivo está
        // bien, lo que no se pudo fue dibujarlo.
        if (mounted) setState(() => _videoListo = false);
      });
    }
  }

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.esVideo ? 'Enviar video' : 'Enviar foto',
            style: const TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: Center(child: _vistaPrevia())),

          // Comentario + enviar, sobre el teclado.
          Container(
            color: Colors.black,
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _comentarioCtrl,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Añade un comentario (opcional)',
                        hintStyle:
                            TextStyle(color: Colors.white54, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(
                    context,
                    EnvioMedia(widget.archivo, _comentarioCtrl.text.trim()),
                  ),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: colors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaPrevia() {
    if (!widget.esVideo) {
      return InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Image.file(widget.archivo, fit: BoxFit.contain),
      );
    }

    final c = _video;
    if (!_videoListo || c == null) {
      return CircularProgressIndicator(color: colors.primary);
    }
    return AspectRatio(
      aspectRatio: c.value.aspectRatio,
      child: VideoPlayer(c),
    );
  }
}
