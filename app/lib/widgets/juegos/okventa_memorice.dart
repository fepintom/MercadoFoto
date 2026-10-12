import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Memorice OkVenta: 16 cartas (8 parejas) con Okventín y los logos de la
/// app. Se dan vuelta de a dos; si son iguales quedan a la vista, si no se
/// vuelven a tapar. Gana quien encuentra todas; se cuentan intentos y
/// tiempo, y se guarda el mejor puntaje de la sesión.
///
/// Las cartas (assets ya existentes de la app):
///   1. Okventín (OK con la mano)        2. Okventín chateando
///   3. Okventín "compra exitosa"        4. Okventín técnico (OkServicios)
///   5. Okventín vendiendo (con caja)    6. Logo OkVenta carrito (OkMarket)
///   7. Logo OkVenta etiqueta (ofertas)  8. Logo OkVenta chat (Comunidad)
class OkVentaMemorice extends StatefulWidget {
  const OkVentaMemorice({super.key});

  @override
  State<OkVentaMemorice> createState() => _OkVentaMemoriceState();
}

class CartaMemorice {
  final String imagen;
  final String nombre;
  const CartaMemorice(this.imagen, this.nombre);
}

const List<CartaMemorice> kCartasMemorice = [
  CartaMemorice('assets/images/okventin.png', 'Okventín'),
  CartaMemorice('assets/images/okventin_chat.png', 'Chat'),
  CartaMemorice('assets/images/okventin_compra.png', 'Compra exitosa'),
  CartaMemorice('assets/images/okventin_servicios.png', 'OkServicios'),
  CartaMemorice('assets/images/okventin_vender.png', 'Vender'),
  CartaMemorice('assets/images/carrito.png', 'OkMarket'),
  CartaMemorice('assets/images/chekin.png', 'Ofertas'),
  CartaMemorice('assets/images/mensajes.png', 'Comunidad'),
];

class _Carta {
  final int pareja; // índice en kCartasMemorice
  bool visible = false;
  bool encontrada = false;
  _Carta(this.pareja);
}

int? _mejorIntentos; // récord de la sesión

class _OkVentaMemoriceState extends State<OkVentaMemorice> {
  late List<_Carta> _cartas;
  final List<int> _abiertas = [];
  int _intentos = 0;
  bool _bloqueado = false;
  DateTime? _inicio;
  Duration _tiempo = Duration.zero;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _nueva();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  void _nueva() {
    final r = Random();
    _cartas = [
      for (var i = 0; i < kCartasMemorice.length; i++) ...[_Carta(i), _Carta(i)]
    ]..shuffle(r);
    _abiertas.clear();
    _intentos = 0;
    _bloqueado = false;
    _inicio = null;
    _tiempo = Duration.zero;
    _reloj?.cancel();
  }

  bool get _gano => _cartas.every((c) => c.encontrada);

  void _tocar(int i) {
    final c = _cartas[i];
    if (_bloqueado || c.visible || c.encontrada) return;
    if (_inicio == null) {
      _inicio = DateTime.now();
      _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !_gano) {
          setState(() => _tiempo = DateTime.now().difference(_inicio!));
        }
      });
    }
    HapticFeedback.selectionClick();
    setState(() {
      c.visible = true;
      _abiertas.add(i);
    });
    if (_abiertas.length < 2) return;

    _intentos++;
    final a = _cartas[_abiertas[0]];
    final b = _cartas[_abiertas[1]];
    if (a.pareja == b.pareja) {
      HapticFeedback.mediumImpact();
      setState(() {
        a.encontrada = b.encontrada = true;
        _abiertas.clear();
      });
      if (_gano) {
        _reloj?.cancel();
        if (_mejorIntentos == null || _intentos < _mejorIntentos!) {
          _mejorIntentos = _intentos;
        }
      }
    } else {
      _bloqueado = true;
      Future.delayed(const Duration(milliseconds: 750), () {
        if (!mounted) return;
        setState(() {
          a.visible = b.visible = false;
          _abiertas.clear();
          _bloqueado = false;
        });
      });
    }
  }

  String get _reloj2 =>
      '${_tiempo.inMinutes}:${(_tiempo.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final encontradas = _cartas.where((c) => c.encontrada).length ~/ 2;
    return Container(
      color: const Color(0xFFF3F3F6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(children: [
              _dato(Icons.style_rounded, '$encontradas/8'),
              const SizedBox(width: 14),
              _dato(Icons.touch_app_rounded, '$_intentos intentos'),
              const Spacer(),
              _dato(Icons.timer_outlined, _reloj2),
            ]),
          ),
          Expanded(
            child: Stack(
              children: [
                LayoutBuilder(builder: (context, c) {
                  // 4 × 4 que quepa entero en el espacio disponible.
                  const gap = 8.0;
                  final lado = min((c.maxWidth - 24 - gap * 3) / 4,
                      (c.maxHeight - 12 - gap * 3) / 4);
                  return Center(
                    child: SizedBox(
                      width: lado * 4 + gap * 3,
                      height: lado * 4 + gap * 3,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: gap,
                          crossAxisSpacing: gap,
                        ),
                        itemCount: _cartas.length,
                        itemBuilder: (_, i) => _CartaVista(
                          carta: _cartas[i],
                          onTap: () => _tocar(i),
                        ),
                      ),
                    ),
                  );
                }),
                if (_gano) _victoria(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dato(IconData icono, String texto) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: const Color(0xFFE53935)),
          const SizedBox(width: 4),
          Text(texto,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1C1E))),
        ],
      );

  Widget _victoria() {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/okventin_compra.png', height: 90),
          const SizedBox(height: 8),
          const Text('¡Memoria de vendedor!',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1C1C1E))),
          const SizedBox(height: 4),
          Text('$_intentos intentos · $_reloj2'
              '${_mejorIntentos != null ? '\nRécord: $_mejorIntentos intentos' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1E))),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => setState(_nueva),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Jugar de nuevo',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

/// Una carta con animación de giro (eje Y).
class _CartaVista extends StatelessWidget {
  final _Carta carta;
  final VoidCallback onTap;
  const _CartaVista({required this.carta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final abierta = carta.visible || carta.encontrada;
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: abierta ? 1 : 0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        builder: (_, t, __) {
          final mostrarFrente = t > 0.5;
          final angulo = t * pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(angulo),
            child: mostrarFrente
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _frente(),
                  )
                : _dorso(),
          );
        },
      ),
    );
  }

  Widget _dorso() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF3B3B), Color(0xFFB30F1F)],
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(children: [
        // Trama de bolsitas
        Positioned.fill(
          child: Opacity(
            opacity: 0.18,
            child: GridView.count(
              crossAxisCount: 3,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(4),
              children: List.generate(
                  9,
                  (_) => const Icon(Icons.shopping_bag_rounded,
                      color: Colors.white, size: 12)),
            ),
          ),
        ),
        const Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.all(6),
              child: Text('OK',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -1)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _frente() {
    final c = kCartasMemorice[carta.pareja];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: carta.encontrada
                ? const Color(0xFF34C759)
                : const Color(0xFFE0E0E5),
            width: carta.encontrada ? 2.5 : 1),
      ),
      padding: const EdgeInsets.all(5),
      child: Image.asset(c.imagen, fit: BoxFit.contain, cacheWidth: 240),
    );
  }
}
