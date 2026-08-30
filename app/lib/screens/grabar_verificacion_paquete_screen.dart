import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/rejilla_empaque_overlay.dart';

/// Duración máxima del video: 1 minuto, tal como pide la política
/// antifraude. El video en sí nunca se sube ni se guarda — solo se
/// extraen unos pocos fotogramas clave para ahorrar almacenamiento.
const int _duracionMaximaSegundos = 60;

/// Cuántos fotogramas clave se extraen del video grabado.
const int _cantidadFotogramas = 6;

/// Pantalla de cámara con rejilla para grabar el paquete, usada en dos
/// momentos del flujo antifraude:
///   - Vendedor, al despachar: graba el EMBALAJE (boxing) — el paquete
///     siendo envuelto, sellado con los 4 sellos de seguridad y con las
///     etiquetas puestas.
///   - Comprador, al recibir: graba el UNBOXING — el mismo paquete antes
///     de abrirlo, con la misma rejilla, para poder comparar.
///
/// En ambos casos solo se suben fotogramas clave del video (nunca el
/// archivo de video completo).
class GrabarVerificacionPaqueteScreen extends StatefulWidget {
  final int ordenId;
  final String tituloProducto;

  /// false = grabación de embalaje (vendedor) · true = grabación de
  /// unboxing (comprador).
  final bool esUnboxing;

  const GrabarVerificacionPaqueteScreen({
    super.key,
    required this.ordenId,
    required this.tituloProducto,
    required this.esUnboxing,
  });

  @override
  State<GrabarVerificacionPaqueteScreen> createState() =>
      _GrabarVerificacionPaqueteScreenState();
}

class _GrabarVerificacionPaqueteScreenState
    extends State<GrabarVerificacionPaqueteScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  String? _errorInicializacion;

  bool _grabando = false;
  bool _procesando = false;
  int _segundos = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _inicializarCamara();
  }

  Future<void> _inicializarCamara() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) {
        setState(() =>
            _errorInicializacion = 'No se encontró una cámara en este equipo.');
        return;
      }
      final trasera = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );
      final controller = CameraController(
        trasera,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      _controller = controller;
      _initFuture = controller.initialize();
      await _initFuture;
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _errorInicializacion =
          'No pudimos acceder a la cámara. Revisa los permisos de cámara y micrófono en Ajustes.');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _alternarGrabacion() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (_grabando) {
      await _detenerYProcesar();
      return;
    }

    try {
      await controller.startVideoRecording();
      setState(() {
        _grabando = true;
        _segundos = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _segundos++);
        if (_segundos >= _duracionMaximaSegundos) {
          _detenerYProcesar();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar la grabación.')),
      );
    }
  }

  Future<void> _detenerYProcesar() async {
    final controller = _controller;
    if (controller == null || !_grabando) return;
    _timer?.cancel();
    setState(() {
      _grabando = false;
      _procesando = true;
    });

    try {
      final XFile video = await controller.stopVideoRecording();
      final fotogramas = await _extraerFotogramasClave(video.path, _segundos);

      if (widget.esUnboxing) {
        await ApiService.subirFotogramasUnboxing(widget.ordenId, fotogramas);
      } else {
        await ApiService.subirFotogramasEmbalaje(widget.ordenId, fotogramas);
      }

      // El video original ya cumplió su propósito (se extrajeron los
      // fotogramas); se borra de inmediato del dispositivo, no se
      // conserva ni se sube completo.
      try {
        await File(video.path).delete();
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo procesar el video: $e')),
      );
    }
  }

  /// Extrae [_cantidadFotogramas] fotogramas repartidos a lo largo del
  /// video (usando el tiempo grabado, sin depender de leer la duración
  /// real del archivo) y los guarda como JPG temporales.
  Future<List<File>> _extraerFotogramasClave(
      String videoPath, int segundosGrabados) async {
    final dir = await getTemporaryDirectory();
    final duracionMs =
        (segundosGrabados > 0 ? segundosGrabados : 1) * 1000;
    final List<File> archivos = [];

    for (int i = 0; i < _cantidadFotogramas; i++) {
      final fraccion = (i + 1) / (_cantidadFotogramas + 1);
      final timeMs = (duracionMs * fraccion).round();
      try {
        final bytes = await vt.VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: vt.ImageFormat.JPEG,
          maxWidth: 900,
          quality: 75,
          timeMs: timeMs,
        );
        if (bytes == null || bytes.isEmpty) continue;
        final path =
            '${dir.path}/verificacion_${widget.ordenId}_${DateTime.now().microsecondsSinceEpoch}_$i.jpg';
        final file = File(path);
        await file.writeAsBytes(bytes);
        archivos.add(file);
      } catch (_) {
        // Si un fotograma puntual falla, seguimos con los demás — con un
        // par de fotogramas ya alcanza para el análisis.
      }
    }

    if (archivos.isEmpty) {
      throw Exception('No se pudo extraer ningún fotograma del video');
    }
    return archivos;
  }

  String get _tituloInstruccion => widget.esUnboxing
      ? 'Graba el unboxing antes de abrir tu paquete'
      : 'Graba el embalaje de tu envío';

  String get _cuerpoInstruccion => widget.esUnboxing
      ? 'Ubica el paquete horizontal y derecho dentro de la rejilla, igual '
          'como lo grabó el vendedor. Esto nos permite verificar que llegó '
          'sin alteraciones antes de que lo abras.'
      : 'Sella el paquete con los 4 sellos de seguridad en todos los '
          'cierres de la caja y muéstralos en cámara. Ubica el paquete '
          'horizontal y derecho dentro de la rejilla.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.esUnboxing ? 'Verificar unboxing' : 'Verificar embalaje'),
      ),
      body: _errorInicializacion != null
          ? _buildError()
          : _controller == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : FutureBuilder<void>(
                  future: _initFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                          child: CircularProgressIndicator(color: Colors.white));
                    }
                    return _buildCamara();
                  },
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(_errorInicializacion!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildCamara() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: CameraPreview(_controller!)),
        const RejillaEmpaqueOverlay(),

        // Banner de instrucciones.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.75), Colors.transparent],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tituloInstruccion,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(_cuerpoInstruccion,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
              ],
            ),
          ),
        ),

        // Cronómetro mientras graba.
        if (_grabando)
          Positioned(
            top: 110,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_segundos}s / ${_duracionMaximaSegundos}s',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),

        // Botón de grabar / detener.
        Positioned(
          bottom: 36,
          left: 0,
          right: 0,
          child: Center(
            child: _procesando
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 10),
                      Text('Procesando video...',
                          style: TextStyle(color: Colors.white)),
                    ],
                  )
                : GestureDetector(
                    onTap: _alternarGrabacion,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: _grabando ? BoxShape.rectangle : BoxShape.circle,
                          borderRadius:
                              _grabando ? BorderRadius.circular(6) : null,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
