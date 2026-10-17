import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Botón "esconder teclado" que aparece SIEMPRE que el teclado está abierto,
/// en cualquier pantalla de la app (va en el builder de MaterialApp).
/// Flota a la derecha, un poco más arriba del teclado para no tapar la caja
/// de texto ni el botón de enviar.
class BotonOcultarTeclado extends StatelessWidget {
  const BotonOcultarTeclado({super.key});

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;
    final visible = teclado > 80;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      right: 10,
      bottom: visible ? teclado + 72 : -60,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: Material(
            color: colors.carbon.withValues(alpha: 0.88),
            shape: const StadiumBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.keyboard_hide_rounded,
                      size: 18, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Ocultar',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
