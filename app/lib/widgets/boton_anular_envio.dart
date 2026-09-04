import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ventana para arrepentirse de un envío. Igual en los dos chats.
///
/// Pasado el plazo el mensaje queda permanente: el chat es la prueba de lo
/// conversado si hay una disputa, y un historial que se puede editar a
/// cualquier hora no sirve como prueba. El servidor valida el mismo plazo,
/// así que esconder el botón es comodidad, no la regla.
const Duration kVentanaAnular = Duration(seconds: 60);

/// ¿Este mensaje todavía se puede anular?
///
/// [fechaTexto] es el `fecha` que devuelve el servidor. Se compara en UTC
/// porque el servidor guarda las horas en UTC: usar la hora local del
/// teléfono daría diferencias de horas según el país.
bool sePuedeAnular(String? fechaTexto) {
  return segundosRestantesAnular(fechaTexto) > 0;
}

/// Segundos que quedan para anular; 0 si ya no se puede.
int segundosRestantesAnular(String? fechaTexto) {
  if (fechaTexto == null || fechaTexto.isEmpty) return 0;
  final fecha = DateTime.tryParse(fechaTexto);
  if (fecha == null) return 0;
  final edad = DateTime.now().toUtc().difference(
      fecha.isUtc ? fecha : DateTime.utc(fecha.year, fecha.month, fecha.day,
          fecha.hour, fecha.minute, fecha.second));
  if (edad.isNegative) return kVentanaAnular.inSeconds;
  final restan = kVentanaAnular.inSeconds - edad.inSeconds;
  return restan > 0 ? restan : 0;
}

/// El botón "Anular envío" con su cuenta regresiva.
///
/// Lleva su propio reloj en vez de depender de que el chat se redibuje: el
/// chat se refresca cada 5 s y la cuenta se vería saltando de 5 en 5. Cuando
/// el plazo termina, el botón se retira solo.
class BotonAnularEnvio extends StatefulWidget {
  /// El `fecha` del mensaje, tal como llega del servidor.
  final String? fecha;

  /// Qué hacer al confirmar. Quien lo usa llama al servidor y quita el
  /// mensaje de la lista.
  final VoidCallback onAnular;

  const BotonAnularEnvio({
    super.key,
    required this.fecha,
    required this.onAnular,
  });

  @override
  State<BotonAnularEnvio> createState() => _BotonAnularEnvioState();
}

class _BotonAnularEnvioState extends State<BotonAnularEnvio> {
  Timer? _reloj;
  int _restan = 0;

  @override
  void initState() {
    super.initState();
    _restan = segundosRestantesAnular(widget.fecha);
    if (_restan > 0) {
      _reloj = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        final r = segundosRestantesAnular(widget.fecha);
        setState(() => _restan = r);
        if (r <= 0) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_restan <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GestureDetector(
        onTap: widget.onAnular,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.primary, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.undo_rounded, size: 13, color: colors.primary),
              const SizedBox(width: 5),
              Text(
                'Anular envío',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                // Cuenta regresiva: deja claro que la opción se acaba, sin
                // tener que explicarlo con un texto largo.
                '0:${_restan.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.grayMid,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
