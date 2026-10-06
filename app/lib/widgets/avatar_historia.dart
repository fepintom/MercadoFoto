import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/historias_service.dart';
import '../theme/app_theme.dart';
import 'avatar_usuario.dart';

/// Foto del usuario con el anillo de "historia", como en Instagram.
///
/// - Con historia publicada ([tieneHistoria]): anillo degradado (amarillo →
///   naranjo → rojo → magenta) que gira despacio, para que "brille" y llame
///   a tocarlo.
/// - Sin historia: un borde fino y neutro.
///
/// Si se pasa [userId], el anillo se enciende solo cuando ese usuario tiene
/// una historia vigente (HistoriasService.activos) y al tocar la foto se
/// abren sus historias; si no tiene, se usa [onTap] (p. ej. ir al perfil).
class AvatarHistoria extends StatefulWidget {
  final String? fotoUrl;
  final String nombre;
  final double tamano;
  final bool tieneHistoria;
  final VoidCallback? onTap;
  final int? userId;

  const AvatarHistoria({
    super.key,
    required this.fotoUrl,
    required this.nombre,
    this.tamano = 30,
    this.tieneHistoria = false,
    this.onTap,
    this.userId,
  });

  @override
  State<AvatarHistoria> createState() => _AvatarHistoriaState();
}

class _AvatarHistoriaState extends State<AvatarHistoria>
    with SingleTickerProviderStateMixin {
  AnimationController? _giro;

  static const _degradado = [
    Color(0xFFFEDA75),
    Color(0xFFFA7E1E),
    Color(0xFFD62976),
    Color(0xFF962FBF),
    Color(0xFFFEDA75),
  ];

  bool get _activa =>
      widget.tieneHistoria ||
      (widget.userId != null && HistoriasService.tiene(widget.userId));

  void _cambioActivos() {
    if (!mounted) return;
    final antes = _giro != null;
    _sincronizar();
    if (antes != (_giro != null)) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    HistoriasService.activos.addListener(_cambioActivos);
    _sincronizar();
  }

  @override
  void didUpdateWidget(covariant AvatarHistoria old) {
    super.didUpdateWidget(old);
    if (old.tieneHistoria != widget.tieneHistoria ||
        old.userId != widget.userId) {
      _sincronizar();
    }
  }

  /// La animación solo corre si hay historia: cientos de tarjetas sin
  /// historia no deben gastar batería girando nada.
  void _sincronizar() {
    if (_activa) {
      _giro ??= AnimationController(
          vsync: this, duration: const Duration(seconds: 4))
        ..repeat();
    } else {
      _giro?.dispose();
      _giro = null;
    }
  }

  @override
  void dispose() {
    HistoriasService.activos.removeListener(_cambioActivos);
    _giro?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tamano;
    final foto = Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(color: colors.surface, shape: BoxShape.circle),
      child: AvatarUsuario(
          fotoUrl: widget.fotoUrl, nombre: widget.nombre, tamano: t - 6),
    );

    Widget anillo;
    final giro = _giro;
    if (giro != null) {
      anillo = Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: giro,
            builder: (_, __) => Container(
              width: t,
              height: t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: _degradado,
                  transform: GradientRotation(giro.value * 2 * math.pi),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFA7E1E).withValues(
                        alpha: 0.25 + 0.2 * math.sin(giro.value * 2 * math.pi)),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          foto,
        ],
      );
    } else {
      anillo = Container(
        width: t,
        height: t,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.divider, width: 1),
        ),
        child: foto,
      );
    }

    return GestureDetector(
      onTap: () async {
        final uid = widget.userId;
        if (uid != null && HistoriasService.tiene(uid)) {
          final hubo = await HistoriasService.abrir(context,
              userId: uid, nombre: widget.nombre, fotoUrl: widget.fotoUrl);
          if (hubo) return;
        }
        widget.onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(width: t, height: t, child: anillo),
    );
  }
}
