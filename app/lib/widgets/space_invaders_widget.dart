import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Space Invaders mini-game para la pantalla de espera de análisis IA.
/// Implementado con CustomPainter + Ticker. Sin dependencias externas.
/// Los colores aquí son intencionalmente retro/arcade, no AppColors.
class SpaceInvadersWidget extends StatefulWidget {
  const SpaceInvadersWidget({super.key});

  @override
  State<SpaceInvadersWidget> createState() => _SpaceInvadersWidgetState();
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
class _SpaceInvadersWidgetState extends State<SpaceInvadersWidget>
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
      color: const Color(0xFF080818),
      child: Column(
        children: [
          // Barra score / vidas
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SCORE  $_score',
                  style: const TextStyle(
                    color: Color(0xFF00FF88),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Row(
                  children: List.generate(
                    3,
                    (i) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.favorite,
                        size: 13,
                        color: i < _lives
                            ? const Color(0xFFFF4444)
                            : const Color(0xFF2A2A3A),
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
                painter: _GamePainter(
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
                _win ? '¡GANASTE!  +$_score PTS' : 'GAME OVER',
                style: TextStyle(
                  color: _win
                      ? const Color(0xFF00FF88)
                      : const Color(0xFFFF4444),
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
              border: Border.all(color: const Color(0xFF00FF88)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'JUGAR DE NUEVO',
              style: TextStyle(
                color: Color(0xFF00FF88),
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
          color: const Color(0xFF00FF88).withOpacity(0.08),
          border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF00FF88), size: 28),
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
          color: const Color(0xFFFF4444).withOpacity(0.12),
          border: Border.all(color: const Color(0xFFFF4444).withOpacity(0.5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.keyboard_arrow_up_rounded,
          color: Color(0xFFFF4444),
          size: 26,
        ),
      ),
    );
  }
}

// ── CustomPainter ─────────────────────────────────────────────────────────
class _GamePainter extends CustomPainter {
  final double px;
  final List<_Inv> invaders;
  final List<_Bullet> pBullets, eBullets;
  final double sx, sy;
  final bool over, win;

  const _GamePainter({
    required this.px,
    required this.invaders,
    required this.pBullets,
    required this.eBullets,
    required this.sx,
    required this.sy,
    required this.over,
    required this.win,
  });

  static const _green = Color(0xFF00FF88);
  static const _red = Color(0xFFFF4444);
  static const _orange = Color(0xFFFF8800);
  static const _yellow = Color(0xFFFFDD00);
  static const _cyan = Color(0xFF00FFEE);

  // Partes del invasor definidas como fracciones de (0..1 × 0..1) del bbox
  // [left, top, right, bottom]
  static const _parts0 = [
    [0.30, 0.00, 0.70, 0.35], // cabeza
    [0.05, 0.20, 0.95, 0.60], // cuerpo
    [0.00, 0.35, 0.18, 0.65], // brazo izq
    [0.82, 0.35, 1.00, 0.65], // brazo der
    [0.18, 0.60, 0.40, 1.00], // pata izq
    [0.60, 0.60, 0.82, 1.00], // pata der
  ];
  static const _parts1 = [
    [0.20, 0.00, 0.80, 0.40],
    [0.00, 0.25, 0.15, 0.60],
    [0.85, 0.25, 1.00, 0.60],
    [0.10, 0.40, 0.90, 0.78],
    [0.10, 0.78, 0.35, 1.00],
    [0.65, 0.78, 0.90, 1.00],
  ];
  static const _parts2 = [
    [0.12, 0.00, 0.88, 0.45],
    [0.00, 0.20, 0.22, 0.68],
    [0.78, 0.20, 1.00, 0.68],
    [0.18, 0.45, 0.82, 0.82],
    [0.18, 0.82, 0.42, 1.00],
    [0.58, 0.82, 0.82, 1.00],
  ];

  void _drawInvader(Canvas c, _Inv inv) {
    final color = inv.type == 0 ? _red : inv.type == 1 ? _orange : _yellow;
    final p = Paint()..color = color;
    final iw = _iW * sx;
    final ih = _iH * sy;
    final ox = inv.x * sx;
    final oy = inv.y * sy;
    final parts = inv.type == 0 ? _parts0 : inv.type == 1 ? _parts1 : _parts2;
    for (final r in parts) {
      c.drawRect(
        Rect.fromLTWH(
          ox + r[0] * iw,
          oy + r[1] * ih,
          (r[2] - r[0]) * iw,
          (r[3] - r[1]) * ih,
        ),
        p,
      );
    }
  }

  void _drawPlayer(Canvas c) {
    final p = Paint()..color = _green;
    final ox = px * sx;
    final oy = _pY * sy;
    final w = _pW * sx;
    final h = _pH * sy;
    // Cuerpo
    c.drawRect(Rect.fromLTWH(ox + w * 0.08, oy + h * 0.3, w * 0.84, h * 0.7), p);
    // Cañón
    c.drawRect(Rect.fromLTWH(ox + w * 0.40, oy, w * 0.20, h * 0.5), p);
    // Patas
    c.drawRect(Rect.fromLTWH(ox, oy + h * 0.65, w * 0.14, h * 0.35), p);
    c.drawRect(Rect.fromLTWH(ox + w * 0.86, oy + h * 0.65, w * 0.14, h * 0.35), p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF080818),
    );

    // Estrellas estáticas
    final sp = Paint()..color = const Color(0xFFFFFFFF).withOpacity(0.3);
    for (int i = 0; i < 45; i++) {
      canvas.drawCircle(
        Offset((i * 71 + 13) % size.width, (i * 53 + 7) % size.height),
        (i % 4 == 0) ? 1.5 : 0.7,
        sp,
      );
    }

    if (over || win) return;

    // Línea de suelo
    canvas.drawLine(
      Offset(0, (_pY + _pH + 8) * sy),
      Offset(size.width, (_pY + _pH + 8) * sy),
      Paint()
        ..color = _green.withOpacity(0.25)
        ..strokeWidth = 1,
    );

    // Invasores
    for (final inv in invaders.where((i) => i.alive)) {
      _drawInvader(canvas, inv);
    }

    // Jugador
    _drawPlayer(canvas);

    // Balas del jugador
    final pbp = Paint()..color = _cyan;
    for (final b in pBullets) {
      canvas.drawRect(
        Rect.fromLTWH(b.x * sx - _bW / 2, b.y * sy, _bW, _pbH * sy),
        pbp,
      );
    }

    // Balas enemigas
    final ebp = Paint()..color = _red.withOpacity(0.85);
    for (final b in eBullets) {
      canvas.drawRect(
        Rect.fromLTWH(b.x * sx - _bW / 2, b.y * sy, _bW, _ebH * sy),
        ebp,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) => true;
}
