import 'package:flutter/material.dart';

/// El punto azul que marca dónde está el usuario en un mapa.
///
/// Vive en un archivo propio para que los mapas de productos y de servicios
/// muestren exactamente el mismo indicador, y para que el día que pasemos a
/// Google Maps haya un solo lugar que revisar: allá los marcadores se
/// definen con imágenes en vez de widgets, así que este es el punto de
/// cambio.
class PuntoUbicacion extends StatelessWidget {
  final double tamano;

  const PuntoUbicacion({super.key, this.tamano = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: Colors.blue.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 2),
        ],
      ),
    );
  }
}
