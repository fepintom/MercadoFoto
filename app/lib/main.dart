import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MercadoFotoApp());
}

class MercadoFotoApp extends StatelessWidget {
  const MercadoFotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OK Venta',
      theme: AppTheme.theme,
      home: const HomeScreen(),
    );
  }
}
