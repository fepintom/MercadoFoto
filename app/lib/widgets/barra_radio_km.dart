import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_theme.dart';

/// La barra de radio de búsqueda, en un solo lugar.
///
/// Nació dentro del home y se copió a servicios. Copiar significaba que
/// cualquier ajuste había que hacerlo dos veces y que las dos versiones se
/// iban separando solas; ahora es un widget con parámetros y las dos
/// pantallas se ven idénticas por construcción, no por disciplina.
///
/// Quien la usa manda el valor y recibe los cambios: la barra no guarda
/// estado ni sabe qué se está filtrando.
class BarraRadioKm extends StatelessWidget {
  /// Radio actual en kilómetros.
  final double radioKm;

  /// Si el filtro está aplicándose. Apagado, la barra se ve en gris.
  final bool activo;

  /// Sin GPS la barra no se esconde: muestra el aviso para ir a ajustes.
  /// Esconderla dejaría al usuario sin saber por qué no puede filtrar.
  final bool sinGps;

  /// Mientras se pide la ubicación por primera vez.
  final bool cargando;

  final ValueChanged<double> onChanged;

  /// Al soltar el dedo. Es el momento de guardar la preferencia: hacerlo en
  /// cada pixel del arrastre escribiría en disco decenas de veces por gesto.
  final ValueChanged<double>? onChangeEnd;

  /// Toque en el ícono de la izquierda: prende y apaga el filtro.
  final VoidCallback? onToggle;

  /// Algo a la derecha del valor —en servicios va la pastilla de publicar—.
  /// Al ocupar espacio, la barra se acorta sola.
  final Widget? trailing;

  /// Distancia máxima que permite el control.
  final double maxKm;

  const BarraRadioKm({
    super.key,
    required this.radioKm,
    required this.onChanged,
    this.activo = false,
    this.sinGps = false,
    this.cargando = false,
    this.onChangeEnd,
    this.onToggle,
    this.trailing,
    this.maxKm = 2000,
  });

  static String formatRadio(double km) =>
      km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.toStringAsFixed(0)} km';

  @override
  Widget build(BuildContext context) {
    final bool encendido = activo && !sinGps;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 50,
      child: Row(
        children: [
          // Ícono-interruptor.
          GestureDetector(
            onTap: () {
              if (cargando) return;
              if (sinGps) {
                Geolocator.openAppSettings();
                return;
              }
              onToggle?.call();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: encendido
                    ? colors.primarySuave.withValues(alpha: 0.10)
                    : colors.background,
                shape: BoxShape.circle,
              ),
              child: cargando
                  ? Padding(
                      padding: const EdgeInsets.all(7),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: colors.grayMid),
                    )
                  : Icon(
                      sinGps
                          ? Icons.location_off_outlined
                          : Icons.near_me_rounded,
                      size: 15,
                      color: encendido ? colors.primarySuave : colors.grayMid,
                    ),
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: sinGps
                ? GestureDetector(
                    onTap: () => Geolocator.openAppSettings(),
                    child: Text(
                      'GPS no disponible — toca para activar',
                      style: TextStyle(fontSize: 12, color: colors.grayMid),
                    ),
                  )
                : SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: encendido
                          ? colors.primarySuave
                          : colors.grayMid.withValues(alpha: 0.4),
                      inactiveTrackColor: colors.divider,
                      thumbColor:
                          encendido ? colors.primarySuave : colors.grayMid,
                      overlayColor: colors.primarySuave.withValues(alpha: 0.12),
                    ),
                    child: Slider(
                      value: radioKm.clamp(1, maxKm),
                      min: 1,
                      max: maxKm,
                      onChanged: onChanged,
                      onChangeEnd: onChangeEnd,
                    ),
                  ),
          ),

          if (!sinGps && !cargando)
            SizedBox(
              // Más angosto cuando hay algo a la derecha: así la pastilla no
              // le come ancho al slider, que es la parte que se manipula.
              width: trailing == null ? 58 : 46,
              child: Text(
                formatRadio(radioKm),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: encendido ? colors.primarySuave : colors.grayMid,
                ),
              ),
            ),

          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
