import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'net_image.dart';

/// Okventín "de oficio" de cada aviso de OkServicios: el servidor lo arma
/// con las herramientas del tipo de servicio (gasfíter con llave inglesa,
/// pintor con rodillo...). Viene en cada servicio como:
///   okventin_foto  → foto de estudio (para avisos sin foto propia)
///   okventin_sello → figura transparente (sello sobre la foto del aviso)
class OkventinServicio {
  OkventinServicio._();

  static String? _url(dynamic u) {
    final s = (u ?? '').toString();
    if (s.isEmpty) return null;
    return s.startsWith('http') ? s : '${ApiService.baseUrl}$s';
  }

  /// Foto del aviso: la primera foto del proveedor o, si no subió ninguna,
  /// la de Okventín con sus herramientas.
  static String? foto(Map s) {
    final fotos = s['fotos'];
    if (fotos is List && fotos.isNotEmpty) {
      final f = fotos.first.toString();
      return f.startsWith('http') ? f : '${ApiService.baseUrl}$f';
    }
    return _url(s['okventin_foto']);
  }

  /// true si la foto que se muestra es la de Okventín (no hay fotos).
  static bool usaOkventin(Map s) {
    final fotos = s['fotos'];
    return !(fotos is List && fotos.isNotEmpty) &&
        (s['okventin_foto'] ?? '').toString().isNotEmpty;
  }

  static String? sello(Map s) => _url(s['okventin_sello']);
}

/// Okventín chiquito en la esquina de la foto de un servicio (cuando el
/// aviso tiene foto propia): dice de un vistazo qué oficio es.
class SelloOkventin extends StatelessWidget {
  final Map servicio;
  final double tam;
  const SelloOkventin({super.key, required this.servicio, this.tam = 52});

  @override
  Widget build(BuildContext context) {
    final url = OkventinServicio.sello(servicio);
    if (url == null || OkventinServicio.usaOkventin(servicio)) {
      return const SizedBox.shrink();
    }
    // El servidor ya lo entrega dentro del marco rojo con estrellas, con
    // fondo claro y sombra suave: aquí solo se muestra.
    // 65 % de transparencia: el sello acompaña sin tapar la foto.
    return IgnorePointer(
      child: Opacity(
        opacity: 0.35,
        child: SizedBox(
          width: tam,
          height: tam,
          child: NetImage(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
