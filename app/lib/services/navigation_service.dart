import 'package:flutter/material.dart';

/// Navigator global para poder navegar desde fuera del árbol de widgets,
/// por ejemplo al tocar una notificación push (no hay BuildContext local
/// disponible en ese momento porque puede llegar con la app en background
/// o recién abriéndose desde cero).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Context válido para navegar / mostrar SnackBars fuera de un widget.
BuildContext? get rootContext => rootNavigatorKey.currentContext;
