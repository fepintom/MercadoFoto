import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';
import '../widgets/net_image.dart';

/// Ver una foto o un video del chat sin salir de la app.
///
/// Antes se abría el navegador con la URL del servidor: el usuario veía la
/// dirección del servidor en pantalla, perdía el hilo de la conversación y
/// tenía que volver con el botón atrás del sistema. Esto es una pantalla
/// más de la app: se cierra y sigues donde estabas.
class VisorMediaScreen extends StatefulWidget {
  /// URL completa del archivo.
  final String url;

  /// Video o foto. Cambia el reproductor, no el resto de la pantalla.
  final bool esVideo;

  /// Texto que acompañaba al archivo, si lo hubo.
  final String comentario;

  const VisorMediaScreen({
    super.key,
    required this.url,
    this.esVideo = false,
    this.comentario = '',
  });

  @override
  State<VisorMediaScreen> createState() => _VisorMediaScreenState();
}

class _VisorMediaScreenState extends State<VisorMediaScreen> {
  VideoPlayerController? _video;
  bool _listo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.esVideo) _prepararVideo();
  }

  Future<void> _prepararVideo() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _video = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (mounted) setState(() => _listo = true);
    } catch (_) {
      // Un video que no carga no puede dejar la pantalla en negro sin
      // explicación: se avisa y se ofrece cerrar.
      if (mounted) setState(() => _error = 'No se pudo cargar el video');
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fondo negro fijo y no colors.background: una foto se mira mejor sobre
    // negro, y esta pantalla es solo para mirar.
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.esVideo ? 'Video' : 'Foto',
            style: const TextStyle(fontSize: 16)),
      ),
      body: Column(
        children: [
          Expanded(child: Center(child: _contenido())),
          if (widget.comentario.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              color: Colors.black,
              child: Text(
                widget.comentario,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white54, size: 40),
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.white70)),
        ],
      );
    }

    if (widget.esVideo) {
      final c = _video;
      if (!_listo || c == null) {
        return CircularProgressIndicator(color: colors.primary);
      }
      return AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(c),
            // Play/pausa tocando el video, como en cualquier reproductor.
            GestureDetector(
              onTap: () => setState(
                  () => c.value.isPlaying ? c.pause() : c.play()),
              child: Container(
                color: Colors.transparent,
                child: c.value.isPlaying
                    ? null
                    : const Icon(Icons.play_circle_fill_rounded,
                        size: 64, color: Colors.white70),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: colors.primary,
                  backgroundColor: Colors.white24,
                  bufferedColor: Colors.white38,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Zoom con dos dedos, como en la galería del teléfono.
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: NetImage(widget.url, fit: BoxFit.contain),
    );
  }
}
