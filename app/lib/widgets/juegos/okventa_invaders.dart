import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// OkVenta Invaders: Okventín (la bolsa de OkVenta, vista desde arriba)
/// defiende el mercado de las ofertas falsas disparando ✓ de "compra
/// verificada". Enemigos: cajas truchas, etiquetas de precio falsas y
/// bichos de spam. Juego propio (formas y temática nuevas), hecho con
/// CustomPainter + Ticker, sin dependencias.
const Color _fondo = Color(0xFF1B1F2A);
const Color _rojo = Color(0xFFE53935);
const Color _verde = Color(0xFF34C759);

class OkVentaInvaders extends StatefulWidget {
  const OkVentaInvaders({super.key});

  @override
  State<OkVentaInvaders> createState() => _OkVentaInvadersState();
}

// ── Constantes del juego (coordenadas lógicas) ─────────────────────────────
const double _gW = 300.0; // ancho lógico
const double _gH = 360.0; // alto lógico
const double _pW = 36.0; // player width
const double _pH = 14.0; // player height
const double _pY = _gH - 32.0; // player Y fijo
const double _iW = 26.0; // invader width
const double _iH = 16.0; // invader height
const double _bW = 3.0; // bullet width
const double _pbH = 12.0; // player bullet height
const double _ebH = 8.0; // enemy bullet height

// ── Entidades ──────────────────────────────────────────────────────────────
class _Inv {
  double x, y;
  bool alive;
  final int type; // 0=rojo(30pts) 1=naranja(20pts) 2=amarillo(10pts)
  _Inv({required this.x, required this.y, this.alive = true, required this.type});
}

class _Bullet {
  double x, y;
  _Bullet({required this.x, required this.y});
}

// ── Estado ─────────────────────────────────────────────────────────────────
class _OkVentaInvadersState extends State<OkVentaInvaders>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _prev = Duration.zero;

  double _px = _gW / 2 - _pW / 2;
  int _lives = 3;
  int _score = 0;
  bool _over = false;
  bool _win = false;

  final List<_Inv> _invaders = [];
  final List<_Bullet> _pBullets = [];
  final List<_Bullet> _eBullets = [];

  double _invDir = 1.0;
  double _invMoveTimer = 0;
  double _invMoveInterval = 0.75;
  double _eBulletTimer = 0;
  double _eBulletInterval = 1.8;

  bool _moveL = false;
  bool _moveR = false;

  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _resetGame();
    _ticker = createTicker(_tick)..start();
  }

  void _resetGame() {
    _px = _gW / 2 - _pW / 2;
    _lives = 3;
    _score = 0;
    _over = false;
    _win = false;
    _moveL = _moveR = false;
    _pBullets.clear();
    _eBullets.clear();
    _invaders.clear();
    _invDir = 1.0;
    _invMoveTimer = 0;
    _invMoveInterval = 0.75;
    _eBulletTimer = 0;
    _eBulletInterval = 1.8;

    // Grilla 5 columnas × 3 filas
    const cols = 5, rows = 3;
    const colGap = 14.0, rowGap = 12.0;
    const startX = (_gW - (cols * _iW + (cols - 1) * colGap)) / 2;
    const startY = 30.0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        _invaders.add(_Inv(
          x: startX + c * (_iW + colGap),
          y: startY + r * (_iH + rowGap),
          type: r,
        ));
      }
    }
  }

  // ── Game loop ────────────────────────────────────────────────────────────
  void _tick(Duration elapsed) {
    if (_over || _win) return;
    final dt = ((elapsed - _prev).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _prev = elapsed;

    setState(() {
      // Mover jugador
      if (_moveL) _px = (_px - 140 * dt).clamp(0, _gW - _pW);
      if (_moveR) _px = (_px + 140 * dt).clamp(0, _gW - _pW);

      // Balas del jugador (suben)
      for (final b in _pBullets) b.y -= 260 * dt;
      _pBullets.removeWhere((b) => b.y < -_pbH);

      // Balas enemigas (bajan)
      for (final b in _eBullets) b.y += 110 * dt;
      _eBullets.removeWhere((b) => b.y > _gH);

      // Movimiento de invasores (en pasos)
      _invMoveTimer += dt;
      if (_invMoveTimer >= _invMoveInterval) {
        _invMoveTimer = 0;
        final alive = _invaders.where((i) => i.alive).toList();
        if (alive.isEmpty) {
          _win = true;
          return;
        }
        final maxX = alive.map((i) => i.x + _iW).reduce(max);
        final minX = alive.map((i) => i.x).reduce(min);
        final hitWall = (_invDir > 0 && maxX >= _gW - 4) ||
            (_invDir < 0 && minX <= 4);

        if (hitWall) {
          _invDir *= -1;
          for (final i in _invaders) i.y += 10;
          _invMoveInterval = max(0.12, _invMoveInterval * 0.9);
        } else {
          for (final i in _invaders) i.x += _invDir * 18;
        }

        // ¿Invasor llegó a la línea del jugador?
        for (final i in _invaders.where((i) => i.alive)) {
          if (i.y + _iH >= _pY) {
            _over = true;
            return;
          }
        }
      }

      // Invasores disparan
      _eBulletTimer += dt;
      if (_eBulletTimer >= _eBulletInterval) {
        _eBulletTimer = 0;
        final alive = _invaders.where((i) => i.alive).toList();
        if (alive.isNotEmpty) {
          final shooter = alive[_rng.nextInt(alive.length)];
          _eBullets.add(_Bullet(x: shooter.x + _iW / 2, y: shooter.y + _iH));
        }
        _eBulletInterval = max(0.6, _eBulletInterval - 0.04);
      }

      // Colisión: balas del jugador vs invasores
      outer:
      for (final b in List.of(_pBullets)) {
        for (final inv in _invaders.where((i) => i.alive)) {
          if (b.x >= inv.x && b.x <= inv.x + _iW &&
              b.y >= inv.y && b.y <= inv.y + _iH) {
            inv.alive = false;
            _pBullets.remove(b);
            _score += (3 - inv.type) * 10;
            continue outer;
          }
        }
      }

      // Colisión: balas enemigas vs jugador
      for (final b in List.of(_eBullets)) {
        if (b.x >= _px &&
            b.x <= _px + _pW &&
            b.y >= _pY - 4 &&
            b.y <= _pY + _pH) {
          _eBullets.remove(b);
          _lives--;
          if (_lives <= 0) {
            _over = true;
            return;
          }
        }
      }

      if (_invaders.every((i) => !i.alive)) _win = true;
    });
  }

  void _fire() {
    if (_over || _win || _pBullets.length >= 2) return;
    _pBullets.add(_Bullet(x: _px + _pW / 2, y: _pY - _pH));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _fondo,
      child: Column(
        children: [
          // Barra score / vidas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FRAUDES DETENIDOS  $_score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                Row(
                  children: List.generate(
                    3,
                    (i) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.shopping_bag_rounded,
                        size: 14,
                        color: i < _lives
                            ? _rojo
                            : Colors.white24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Canvas del juego
          Expanded(
            child: LayoutBuilder(builder: (ctx, cns) {
              return CustomPaint(
                size: Size(cns.maxWidth, cns.maxHeight),
                painter: _PintorInvaders(
                  px: _px,
                  invaders: _invaders,
                  pBullets: _pBullets,
                  eBullets: _eBullets,
                  sx: cns.maxWidth / _gW,
                  sy: cns.maxHeight / _gH,
                  over: _over,
                  win: _win,
                ),
              );
            }),
          ),

          // Estado fin de juego
          if (_over || _win)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(
                _win
                    ? '¡MERCADO SEGURO!  +$_score'
                    : 'TE GANARON LAS OFERTAS FALSAS',
                style: TextStyle(
                  color: _win ? _verde : _rojo,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),

          // Controles / botón reiniciar
          _buildControls(),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildControls() {
    if (_over || _win) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: GestureDetector(
          onTap: () => setState(_resetGame),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _rojo,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'JUGAR DE NUEVO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ctrlBtn(
            icon: Icons.chevron_left_rounded,
            onDown: () => _moveL = true,
            onUp: () => _moveL = false,
          ),
          _fireBtn(),
          _ctrlBtn(
            icon: Icons.chevron_right_rounded,
            onDown: () => _moveR = true,
            onUp: () => _moveR = false,
          ),
        ],
      ),
    );
  }

  Widget _ctrlBtn({
    required IconData icon,
    required VoidCallback onDown,
    required VoidCallback onUp,
  }) {
    return Listener(
      onPointerDown: (_) => setState(onDown),
      onPointerUp: (_) => setState(onUp),
      onPointerCancel: (_) => setState(onUp),
      child: Container(
        width: 56,
        height: 42,
        decoration: BoxDecoration(
          color: _verde.withOpacity(0.08),
          border: Border.all(color: _verde.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _verde, size: 28),
      ),
    );
  }

  Widget _fireBtn() {
    return GestureDetector(
      onTap: _fire,
      child: Container(
        width: 62,
        height: 42,
        decoration: BoxDecoration(
          color: _rojo.withOpacity(0.12),
          border: Border.all(color: _rojo.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.keyboard_arrow_up_rounded,
          color: _rojo,
          size: 26,
        ),
      ),
    );
  }
}

// ── Pintor (vista desde arriba) ─────────────────────────────────────────────
class _PintorInvaders extends CustomPainter {
  final double px;
  final List<_Inv> invaders;
  final List<_Bullet> pBullets, eBullets;
  final double sx, sy;
  final bool over, win;

  const _PintorInvaders({
    required this.px,
    required this.invaders,
    required this.pBullets,
    required this.eBullets,
    required this.sx,
    required this.sy,
    required this.over,
    required this.win,
  });

  // Caja trucha: cartón visto desde arriba, cinta en cruz y un "?" rojo.
  void _caja(Canvas c, Rect r) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.08));
    c.drawRRect(rr, Paint()..color = const Color(0xFFC08A4E));
    c.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF7A5228));
    final cinta = Paint()..color = const Color(0xFFE8D2A8);
    c.drawRect(
        Rect.fromCenter(
            center: r.center, width: r.width, height: r.height * 0.2),
        cinta);
    c.drawRect(
        Rect.fromCenter(
            center: r.center, width: r.width * 0.2, height: r.height),
        cinta);
    final p = Paint()
      ..color = _rojo
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.6, r.width * 0.09)
      ..strokeCap = StrokeCap.round;
    final q = Path()
      ..moveTo(r.left + r.width * 0.36, r.top + r.height * 0.32)
      ..quadraticBezierTo(r.left + r.width * 0.5, r.top + r.height * 0.05,
          r.left + r.width * 0.64, r.top + r.height * 0.32)
      ..quadraticBezierTo(r.left + r.width * 0.66, r.top + r.height * 0.48,
          r.left + r.width * 0.5, r.top + r.height * 0.58);
    c.drawPath(q, p);
    c.drawCircle(Offset(r.center.dx, r.top + r.height * 0.84),
        r.width * 0.05, Paint()..color = _rojo);
  }

  // Etiqueta de precio falsa: amarilla, con su hoyito y tachada.
  void _etiqueta(Canvas c, Rect r) {
    final path = Path()
      ..moveTo(r.left + r.width * 0.28, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.left + r.width * 0.28, r.bottom)
      ..lineTo(r.left, r.center.dy)
      ..close();
    c.drawPath(path, Paint()..color = const Color(0xFFFFC93C));
    c.drawCircle(Offset(r.left + r.width * 0.24, r.center.dy),
        r.height * 0.12, Paint()..color = _fondo);
    final x = Paint()
      ..color = _rojo
      ..strokeWidth = max(1.6, r.height * 0.13)
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(r.left + r.width * 0.45, r.top + r.height * 0.22),
        Offset(r.right - r.width * 0.12, r.bottom - r.height * 0.22), x);
    c.drawLine(Offset(r.right - r.width * 0.12, r.top + r.height * 0.22),
        Offset(r.left + r.width * 0.45, r.bottom - r.height * 0.22), x);
  }

  // Bicho de spam visto desde arriba: caparazón morado, patitas y antenas.
  void _bicho(Canvas c, Rect r) {
    final patas = Paint()
      ..color = const Color(0xFF3A2A55)
      ..strokeWidth = max(1.0, r.width * 0.05)
      ..strokeCap = StrokeCap.round;
    for (final f in [0.3, 0.5, 0.7]) {
      final y = r.top + r.height * f;
      c.drawLine(Offset(r.left + r.width * 0.2, y), Offset(r.left, y + 2), patas);
      c.drawLine(Offset(r.right - r.width * 0.2, y), Offset(r.right, y + 2), patas);
    }
    c.drawLine(Offset(r.center.dx - 2, r.top + r.height * 0.15),
        Offset(r.left + r.width * 0.25, r.top - 3), patas);
    c.drawLine(Offset(r.center.dx + 2, r.top + r.height * 0.15),
        Offset(r.right - r.width * 0.25, r.top - 3), patas);
    final cuerpo = Rect.fromLTRB(r.left + r.width * 0.18, r.top + r.height * 0.1,
        r.right - r.width * 0.18, r.bottom);
    c.drawOval(cuerpo, Paint()..color = const Color(0xFF8E5BD8));
    c.drawLine(Offset(cuerpo.center.dx, cuerpo.top + 2),
        Offset(cuerpo.center.dx, cuerpo.bottom - 1),
        Paint()
          ..color = const Color(0xFF5B3696)
          ..strokeWidth = 1.2);
    final ojo = Paint()..color = Colors.white;
    c.drawCircle(Offset(cuerpo.center.dx - cuerpo.width * 0.2, cuerpo.top + cuerpo.height * 0.28),
        cuerpo.width * 0.1, ojo);
    c.drawCircle(Offset(cuerpo.center.dx + cuerpo.width * 0.2, cuerpo.top + cuerpo.height * 0.28),
        cuerpo.width * 0.1, ojo);
  }

  void _drawInvader(Canvas c, _Inv inv) {
    final r = Rect.fromLTWH(inv.x * sx, inv.y * sy, _iW * sx, _iH * sy);
    switch (inv.type) {
      case 0:
        _bicho(c, r);
        break;
      case 1:
        _etiqueta(c, r);
        break;
      default:
        _caja(c, r);
    }
  }

  // Okventín visto desde arriba: la bolsa blanca abierta (adentro oscuro),
  // costado rojo, las dos manillas rojas y las zapatillas asomando.
  void _drawPlayer(Canvas c) {
    final w = _pW * sx;
    final h = (_pH + 10) * sy;
    final ox = px * sx;
    final oy = (_pY - 10) * sy;
    final zap = Paint()..color = _rojo;
    // zapatillas (delante, apuntando hacia arriba)
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(ox + w * 0.18, oy - h * 0.12, w * 0.2, h * 0.3),
            Radius.circular(w * 0.1)),
        zap);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(ox + w * 0.62, oy - h * 0.12, w * 0.2, h * 0.3),
            Radius.circular(w * 0.1)),
        zap);
    final cuerpo = RRect.fromRectAndRadius(
        Rect.fromLTWH(ox, oy + h * 0.08, w, h * 0.84), Radius.circular(w * 0.12));
    c.drawRRect(cuerpo, Paint()..color = Colors.white);
    // costado rojo
    c.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(ox, oy + h * 0.08, w * 0.16, h * 0.84),
            topLeft: Radius.circular(w * 0.12), bottomLeft: Radius.circular(w * 0.12)),
        Paint()..color = const Color(0xFFC62828));
    // boca de la bolsa (adentro)
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(ox + w * 0.22, oy + h * 0.28, w * 0.66, h * 0.44),
            Radius.circular(w * 0.06)),
        Paint()..color = const Color(0xFF3A3A40));
    // manillas
    final man = Paint()
      ..color = _rojo
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.0, w * 0.07)
      ..strokeCap = StrokeCap.round;
    c.drawArc(Rect.fromLTWH(ox + w * 0.26, oy + h * 0.1, w * 0.58, h * 0.5), pi, pi,
        false, man);
    c.drawArc(Rect.fromLTWH(ox + w * 0.26, oy + h * 0.42, w * 0.58, h * 0.5), 0, pi,
        false, man);
  }

  // ✓ de compra verificada (disparo de Okventín)
  void _check(Canvas c, Offset p) {
    final paint = Paint()
      ..color = _verde
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(p.dx - 4, p.dy + 3)
      ..lineTo(p.dx - 1, p.dy + 6)
      ..lineTo(p.dx + 5, p.dy - 2);
    c.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Piso de bodega visto desde arriba: baldosas.
    canvas.drawRect(Offset.zero & size, Paint()..color = _fondo);
    final linea = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    final paso = size.width / 8;
    for (double x = 0; x <= size.width; x += paso) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linea);
    }
    for (double y = 0; y <= size.height; y += paso) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linea);
    }

    if (over || win) return;

    // Línea roja de la tienda (lo que hay que defender)
    canvas.drawLine(
      Offset(0, (_pY + _pH + 8) * sy),
      Offset(size.width, (_pY + _pH + 8) * sy),
      Paint()
        ..color = _rojo.withValues(alpha: 0.45)
        ..strokeWidth = 2,
    );

    for (final inv in invaders.where((i) => i.alive)) {
      _drawInvader(canvas, inv);
    }
    _drawPlayer(canvas);

    for (final b in pBullets) {
      _check(canvas, Offset(b.x * sx, b.y * sy));
    }
    final spam = Paint()..color = const Color(0xFFFF6B9A);
    for (final b in eBullets) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(b.x * sx - 2.5, b.y * sy, 5, _ebH * sy),
              const Radius.circular(3)),
          spam);
    }
  }

  @override
  bool shouldRepaint(covariant _PintorInvaders old) => true;
}
