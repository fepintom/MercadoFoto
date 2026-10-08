import 'package:flutter/material.dart';

/// Navigator global para poder navegar desde fuera del árbol de widgets,
/// por ejemplo al tocar una notificación push (no hay BuildContext local
/// disponible en ese momento porque puede llegar con la app en background
/// o recién abriéndose desde cero).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Navigator de adentro del Home: el área de contenido sobre la barra de
/// menú. Lo que se abre aquí deja la barra visible.
/// Lo registra el HomeScreen al crearse (cada Home tiene su propia llave,
/// así nunca hay dos widgets con la misma GlobalKey durante una transición).
GlobalKey<NavigatorState>? shellNavigatorKey;

/// Context válido para navegar / mostrar SnackBars fuera de un widget.
/// Con el Home abierto se usa su navegador de adentro (así una notificación
/// abre su pantalla con la barra de menú visible); si no, el raíz.
BuildContext? get rootContext {
  final shell = shellNavigatorKey?.currentContext;
  if (shell != null && shell.mounted) return shell;
  return rootNavigatorKey.currentContext;
}
