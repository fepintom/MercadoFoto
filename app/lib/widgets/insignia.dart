import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Las insignias de OkVenta (dorado, en `assets/images/insignias/`).
///
/// - [TipoInsignia.certificado]: el profesional tiene su título o
///   certificación revisada por OkVenta (CFT, instituto, universidad…).
///   Va en los avisos de OkServicios con `certificado_verificado`.
/// - [TipoInsignia.instalacion]: el vendedor de este producto también lo
///   instala. Va en los avisos de productos con `instalacion_vendedor`.
///
/// Un solo widget para que se vean igual en toda la app. Tocarla explica
/// qué significa: una insignia que nadie entiende no genera confianza.
enum TipoInsignia { certificado, instalacion }

class Insignia extends StatelessWidget {
  final TipoInsignia tipo;
  final double tamano;

  /// Si al tocarla se abre la explicación. Se apaga donde el toque ya hace
  /// otra cosa (por ejemplo, un pin del mapa).
  final bool explicable;

  const Insignia({
    super.key,
    required this.tipo,
    this.tamano = 20,
    this.explicable = true,
  });

  const Insignia.certificado(
      {super.key, this.tamano = 20, this.explicable = true})
      : tipo = TipoInsignia.certificado;

  const Insignia.instalacion(
      {super.key, this.tamano = 20, this.explicable = true})
      : tipo = TipoInsignia.instalacion;

  static const _kCft = 'assets/images/insignias/insignia_cft.png';
  static const _kInstalacion = 'assets/images/insignias/insignia_instalacion.png';

  /// Dorado de las insignias, para textos que las acompañan.
  static const Color dorado = Color(0xFFB8860B);

  String get _asset =>
      tipo == TipoInsignia.certificado ? _kCft : _kInstalacion;

  String get titulo => tipo == TipoInsignia.certificado
      ? 'Profesional certificado'
      : 'Lo instala el vendedor';

  String get _explicacion => tipo == TipoInsignia.certificado
      ? 'OkVenta revisó el título o la certificación de este profesional '
          '(por ejemplo, de un CFT, instituto o universidad).'
      : 'El vendedor de este producto también hace la instalación. '
          'Coordínala con él por el chat: se acuerda aparte del precio '
          'del producto.';

  static void mostrarExplicacion(BuildContext context, TipoInsignia tipo) {
    final i = Insignia(tipo: tipo, tamano: 88, explicable: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              i,
              const SizedBox(height: 14),
              Text(i.titulo,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary)),
              const SizedBox(height: 8),
              Text(i._explicacion,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, height: 1.4, color: colors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      _asset,
      width: tamano,
      height: tamano,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      // Si el archivo faltara, un ícono y no un recuadro de error.
      errorBuilder: (_, __, ___) => Icon(
        tipo == TipoInsignia.certificado
            ? Icons.verified_rounded
            : Icons.handyman_rounded,
        size: tamano,
        color: dorado,
      ),
    );
    final conEtiqueta = Semantics(label: titulo, image: true, child: img);
    if (!explicable) return conEtiqueta;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => mostrarExplicacion(context, tipo),
      child: conEtiqueta,
    );
  }
}
