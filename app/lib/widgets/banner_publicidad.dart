import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// El carrusel de publicidad que corona el home.
///
/// El home tiene su propia versión privada de esto y se deja intacta a
/// propósito: reescribirla arriesgaba romper la pantalla más usada de la app
/// sin ganar nada visible. Esta es la misma pieza —mismo tamaño, mismo
/// intervalo de 4 s, mismos puntitos— disponible para el resto de pantallas.
/// El día que el home se toque por otro motivo, se cambia por esta.
class BannerPublicidad extends StatefulWidget {
  /// Los avisos a rotar. Si no se pasa nada usa los del marketplace.
  final List<Widget>? avisos;

  const BannerPublicidad({super.key, this.avisos});

  @override
  State<BannerPublicidad> createState() => _BannerPublicidadState();
}

class _BannerPublicidadState extends State<BannerPublicidad> {
  final _controller = PageController();
  int _paginaActual = 0;
  Timer? _timer;

  static const _duracion = Duration(seconds: 4);

  List<Widget> get _avisos =>
      widget.avisos ??
      const [
        BannerImagen('assets/images/banner1.jpg'),
        BannerImagen('assets/images/banner2.jpg'),
        BannerImagen('assets/images/banner3.jpg'),
      ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_duracion, (_) {
      if (!mounted || !_controller.hasClients) return;
      final siguiente = (_paginaActual + 1) % _avisos.length;
      _controller.animateToPage(
        siguiente,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avisos = _avisos;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          height: 130,
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _paginaActual = i),
            children: avisos,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(avisos.length, (i) {
            final activo = i == _paginaActual;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: activo ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: activo
                    ? colors.primary
                    : colors.grayMid.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Aviso por imagen (banner1/2/3.jpg) ───────────────────────────────────────

class BannerImagen extends StatelessWidget {
  final String asset;
  const BannerImagen(this.asset, {super.key});

  @override
  Widget build(BuildContext context) {
    // Mantiene el recuadro del carrusel en su tamaño original: la imagen
    // se achica para entrar completa (BoxFit.contain) en vez de recortarse.
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: colors.carbon,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Container(color: colors.carbon),
        ),
      ),
    );
  }
}

// ── Avisos de servicios ──────────────────────────────────────────────────────

/// Los avisos que se muestran en Ofrezco y Busco.
///
/// Hoy son los mismos del marketplace porque todavía no hay publicidad
/// vendida para servicios. Están aquí, en una lista con nombre propio, para
/// que reemplazarlos sea cambiar esta línea y no ir a buscar dentro de la
/// pantalla.
const List<Widget> avisosServicios = [
  BannerImagen('assets/images/banner1.jpg'),
  BannerImagen('assets/images/banner2.jpg'),
  BannerImagen('assets/images/banner3.jpg'),
];
