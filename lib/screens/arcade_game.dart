import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────
enum ObstacleType { barrier, car, wall }

class _GameObstacle {
  int lane; // 0,1,2
  double yNorm; // 0.0 (top) → 1.0 (bottom)
  ObstacleType type;
  _GameObstacle({required this.lane, required this.yNorm, required this.type});
}

class _Coin {
  int lane;
  double yNorm;
  bool collected = false;
  _Coin({required this.lane, required this.yNorm});
}

// ─────────────────────────────────────────────
// ENTRY WIDGET
// ─────────────────────────────────────────────
class ArcadeGame extends StatefulWidget {
  const ArcadeGame({super.key});
  @override
  State<ArcadeGame> createState() => _ArcadeGameState();
}

class _ArcadeGameState extends State<ArcadeGame> with TickerProviderStateMixin {
  // ─── lanes ──────────────────────────────────
  static const int _laneCount = 3;
  int _targetLane = 1; // 0=left 1=center 2=right

  // ─── animation ──────────────────────────────
  late AnimationController _runAnim; // legs anim
  late AnimationController _laneAnim; // side move
  late Animation<double> _laneTween;

  double _playerPixelX = 0;

  // ─── game state ─────────────────────────────
  final List<_GameObstacle> _obstacles = [];
  final List<_Coin> _coins = [];
  Timer? _loop;
  int _score = 0;
  int _coinCount = 0;
  bool _running = false;
  bool _gameOver = false;
  double _speed = 0.006;
  double _bgScroll = 0;
  final Random _rand = Random();

  // ─── swipe detection ────────────────────────
  double _swipeStartX = 0;
  static const double _swipeThreshold = 30;

  // ─── sizes (set in build) ───────────────────
  double _screenW = 0;
  double _screenH = 0;

  // ─── player visual ──────────────────────────
  static const double _playerW = 36;
  static const double _playerH = 64;
  late double _playerBaseY;

  // ─── lane helpers ───────────────────────────
  double _laneCenter(int lane) {
    final laneW = _screenW / _laneCount;
    return laneW * lane + laneW / 2 - _playerW / 2;
  }

  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _runAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..repeat(reverse: true);

    _laneAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    // Initialize _laneTween with a dummy tween so it's not late-uninitialized
    _laneTween = Tween<double>(begin: 0, end: 0).animate(_laneAnim);
  }

  @override
  void dispose() {
    _loop?.cancel();
    _runAnim.dispose();
    _laneAnim.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  void _initGame() {
    _obstacles.clear();
    _coins.clear();
    _score = 0;
    _coinCount = 0;
    _targetLane = 1;
    _speed = 0.006;
    _bgScroll = 0;
    _gameOver = false;
    _running = true;
    _playerPixelX = _laneCenter(1);
    _playerBaseY = _screenH - _playerH - 60;

    _loop?.cancel();
    _loop = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    _runAnim.repeat(reverse: true);
  }

  void _tick() {
    if (!_running || !mounted) return;

    // background scroll
    _bgScroll = (_bgScroll + _speed) % 1.0;

    // speed increase
    _speed += 0.000002;

    // spawn obstacles (~2% per tick, 1 per lane max)
    if (_rand.nextDouble() < 0.022) {
      final lane = _rand.nextInt(_laneCount);
      final conflict = _obstacles.any((o) => o.lane == lane && o.yNorm < 0.15);
      if (!conflict) {
        _obstacles.add(
          _GameObstacle(
            lane: lane,
            yNorm: -0.12,
            type:
                ObstacleType.values[_rand.nextInt(ObstacleType.values.length)],
          ),
        );
      }
    }

    // spawn coins
    if (_rand.nextDouble() < 0.03) {
      final lane = _rand.nextInt(_laneCount);
      _coins.add(_Coin(lane: lane, yNorm: -0.08));
    }

    // move obstacles & coins
    for (var o in _obstacles) {
      o.yNorm += _speed;
    }
    for (var c in _coins) {
      c.yNorm += _speed;
    }

    // remove cleared
    _obstacles.removeWhere((o) => o.yNorm > 1.15);
    _coins.removeWhere((c) => c.yNorm > 1.15);

    _score += 1;

    // collision detect
    const double obsW = 60;
    const double obsH = 44;
    final double px = _playerPixelX;
    final double py = _playerBaseY;

    for (var o in _obstacles) {
      final ox = _laneCenter(o.lane) + (_playerW - obsW) / 2;
      final oy = o.yNorm * _screenH - obsH / 2;
      final oRect = Rect.fromLTWH(ox, oy, obsW, obsH);
      final pRect = Rect.fromLTWH(px + 4, py + 10, _playerW - 8, _playerH - 10);
      if (pRect.overlaps(oRect)) {
        _triggerGameOver();
        return;
      }
    }

    // coin collect
    for (var c in _coins) {
      if (c.collected) continue;
      if (c.lane != _targetLane) continue;
      final cy = c.yNorm * _screenH;
      final coinRect = Rect.fromLTWH(
        _laneCenter(c.lane) + _playerW / 2 - 10,
        cy - 10,
        20,
        20,
      );
      final pRect = Rect.fromLTWH(px, py, _playerW, _playerH);
      if (pRect.overlaps(coinRect)) {
        c.collected = true;
        _coinCount++;
      }
    }

    setState(() {});
  }

  void _triggerGameOver() {
    _loop?.cancel();
    _running = false;
    _runAnim.stop();
    _gameOver = true;
    setState(() {});

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A2A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '💀 Game Over',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Skor: ${(_score / 60).round()}',
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_coinCount koin',
                    style: const TextStyle(color: Colors.amber, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Keluar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _initGame();
                  _runAnim.repeat(reverse: true);
                });
              },
              child: const Text(
                'Main Lagi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ─── swipe ───────────────────────────────────
  void _onSwipeStart(DragStartDetails d) {
    _swipeStartX = d.localPosition.dx;
  }

  void _onSwipeEnd(DragEndDetails d) {
    final dx = d.velocity.pixelsPerSecond.dx;
    if (dx.abs() > 100) {
      _movePlayer(dx > 0 ? 1 : -1);
    }
  }

  void _onSwipeUpdate(DragUpdateDetails d) {
    final dx = d.localPosition.dx - _swipeStartX;
    if (dx.abs() > _swipeThreshold) {
      _movePlayer(dx > 0 ? 1 : -1);
      _swipeStartX = d.localPosition.dx;
    }
  }

  void _movePlayer(int dir) {
    final newLane = (_targetLane + dir).clamp(0, _laneCount - 1);
    if (newLane == _targetLane) return;
    _targetLane = newLane;

    final to = _laneCenter(newLane);
    final from = _playerPixelX;

    _laneAnim.reset();
    _laneTween =
        Tween<double>(begin: from, end: to).animate(
          CurvedAnimation(parent: _laneAnim, curve: Curves.easeOutCubic),
        )..addListener(() {
          setState(() => _playerPixelX = _laneTween.value);
        });
    _laneAnim.forward();
  }

  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _screenW = MediaQuery.of(context).size.width;
    _screenH =
        MediaQuery.of(context).size.height -
        kToolbarHeight -
        MediaQuery.of(context).padding.top;

    // init on first frame
    if (!_running && !_gameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(_initGame));
    }

    final laneW = _screenW / _laneCount;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1A0E),
        title: Row(
          children: [
            const Icon(Icons.person_pin_circle, color: Colors.greenAccent),
            const SizedBox(width: 8),
            const Text(
              'Wallet Runner',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            const Icon(Icons.timer, color: Colors.white54, size: 18),
            const SizedBox(width: 4),
            Text(
              '${(_score / 60).round()}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            Text(
              '$_coinCount',
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: GestureDetector(
        onHorizontalDragStart: _onSwipeStart,
        onHorizontalDragUpdate: _onSwipeUpdate,
        onHorizontalDragEnd: _onSwipeEnd,
        child: Stack(
          children: [
            // ── Scrolling Road Background ──────────────
            CustomPaint(
              size: Size(_screenW, _screenH),
              painter: _RoadPainter(scroll: _bgScroll, laneCount: _laneCount),
            ),

            // ── Coins ──────────────────────────────────
            for (var c in _coins)
              if (!c.collected)
                Positioned(
                  left: _laneCenter(c.lane) + _playerW / 2 - 10,
                  top: c.yNorm * _screenH - 10,
                  child: const _CoinWidget(),
                ),

            // ── Obstacles ──────────────────────────────
            for (var o in _obstacles)
              Positioned(
                left: _laneCenter(o.lane) + (_playerW - 60) / 2,
                top: o.yNorm * _screenH - 44 / 2,
                width: 60,
                height: 44,
                child: _ObstacleWidget(type: o.type),
              ),

            // ── Player ─────────────────────────────────
            if (_running || _gameOver)
              Positioned(
                left: _playerPixelX,
                top: _playerBaseY,
                width: _playerW,
                height: _playerH,
                child: AnimatedBuilder(
                  animation: _runAnim,
                  builder: (context2, child) => CustomPaint(
                    painter: _PlayerPainter(
                      runT: _runAnim.value,
                      dead: _gameOver,
                    ),
                  ),
                ),
              ),

            // ── Lane tap areas (left / right) ──────────
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: laneW,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _movePlayer(-1),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.chevron_left,
                      color: Colors.white.withValues(alpha: 0.2),
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: laneW,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _movePlayer(1),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.white.withValues(alpha: 0.2),
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),

            // ── Hint text ───────────────────────────────
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Geser kiri / kanan untuk pindah jalur',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ROAD PAINTER (scrolling track)
// ─────────────────────────────────────────────
class _RoadPainter extends CustomPainter {
  final double scroll;
  final int laneCount;
  _RoadPainter({required this.scroll, required this.laneCount});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // road surface
    final roadPaint = Paint()..color = const Color(0xFF1C1C1C);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), roadPaint);

    // scrolling dashed lane dividers
    final linePaint = Paint()
      ..color = const Color(0xFF3A3A3A)
      ..strokeWidth = 2;

    const dashH = 40.0;
    const gapH = 30.0;
    const period = dashH + gapH;

    for (int i = 1; i < laneCount; i++) {
      final x = w / laneCount * i;
      double yStart = -(period * (1 - scroll % 1));
      while (yStart < h) {
        canvas.drawLine(
          Offset(x, yStart),
          Offset(x, yStart + dashH),
          linePaint,
        );
        yStart += period;
      }
    }

    // road edge glow lines
    final edgePaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.15)
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(4, 0), Offset(4, h), edgePaint);
    canvas.drawLine(Offset(w - 4, 0), Offset(w - 4, h), edgePaint);
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.scroll != scroll;
}

// ─────────────────────────────────────────────
// PLAYER PAINTER (animated running character)
// ─────────────────────────────────────────────
class _PlayerPainter extends CustomPainter {
  final double runT; // 0.0 → 1.0
  final bool dead;
  _PlayerPainter({required this.runT, required this.dead});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final bodyColor = dead ? Colors.red.shade400 : Colors.greenAccent;
    final skinColor = dead ? Colors.grey.shade400 : const Color(0xFFFFD39B);

    final bodyPaint = Paint()..color = bodyColor;
    final skinPaint = Paint()..color = skinColor;
    final darkPaint = Paint()..color = Colors.black87;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h - 4), width: 28, height: 8),
      shadowPaint,
    );

    // legs (animated)
    final legAngle = (runT - 0.5) * 0.8;
    final legPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final hipY = h * 0.56;
    final lLegEnd = Offset(
      cx - 8 + sin(legAngle) * 14,
      hipY + 22 + cos(legAngle.abs()) * 4,
    );
    final rLegEnd = Offset(
      cx + 8 - sin(legAngle) * 14,
      hipY + 22 + cos(legAngle.abs()) * 4,
    );
    canvas.drawLine(Offset(cx - 5, hipY), lLegEnd, legPaint);
    canvas.drawLine(Offset(cx + 5, hipY), rLegEnd, legPaint);

    // shoes
    final shoePaint = Paint()
      ..color = Colors.orange.shade700
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(lLegEnd, lLegEnd + const Offset(8, 0), shoePaint);
    canvas.drawLine(rLegEnd, rLegEnd + const Offset(8, 0), shoePaint);

    // torso
    final torsoRect = Rect.fromCenter(
      center: Offset(cx, h * 0.43),
      width: 20,
      height: 22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(6)),
      bodyPaint,
    );

    // backpack
    final bpPaint = Paint()..color = bodyColor.withValues(alpha: 0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx - 10, h * 0.42),
          width: 8,
          height: 14,
        ),
        const Radius.circular(3),
      ),
      bpPaint,
    );

    // arms (swing opposite to legs)
    final armPaint = Paint()
      ..color = bodyColor
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final shoulderY = h * 0.36;
    final lArmEnd = Offset(
      cx - 12 - sin(legAngle) * 10,
      shoulderY + 12 + cos(legAngle.abs()) * 3,
    );
    final rArmEnd = Offset(
      cx + 12 + sin(legAngle) * 10,
      shoulderY + 12 + cos(legAngle.abs()) * 3,
    );
    canvas.drawLine(Offset(cx - 8, shoulderY), lArmEnd, armPaint);
    canvas.drawLine(Offset(cx + 8, shoulderY), rArmEnd, armPaint);

    // neck
    canvas.drawLine(
      Offset(cx, h * 0.35),
      Offset(cx, h * 0.28),
      Paint()
        ..color = skinColor
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // head
    canvas.drawCircle(Offset(cx, h * 0.23), 12, skinPaint);

    // hair
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, h * 0.23), width: 24, height: 24),
      pi,
      pi,
      false,
      Paint()
        ..color = Colors.brown.shade800
        ..style = PaintingStyle.fill,
    );

    // eyes
    if (!dead) {
      canvas.drawCircle(Offset(cx - 4, h * 0.22), 2, darkPaint);
      canvas.drawCircle(Offset(cx + 4, h * 0.22), 2, darkPaint);
    } else {
      // X eyes when dead
      final ep = Paint()
        ..color = Colors.black
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(cx - 6, h * 0.21), Offset(cx - 2, h * 0.23), ep);
      canvas.drawLine(Offset(cx - 6, h * 0.23), Offset(cx - 2, h * 0.21), ep);
      canvas.drawLine(Offset(cx + 2, h * 0.21), Offset(cx + 6, h * 0.23), ep);
      canvas.drawLine(Offset(cx + 2, h * 0.23), Offset(cx + 6, h * 0.21), ep);
    }
  }

  @override
  bool shouldRepaint(_PlayerPainter old) =>
      old.runT != runT || old.dead != dead;
}

// ─────────────────────────────────────────────
// OBSTACLE WIDGET
// ─────────────────────────────────────────────
class _ObstacleWidget extends StatelessWidget {
  final ObstacleType type;
  const _ObstacleWidget({required this.type});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String label;
    switch (type) {
      case ObstacleType.barrier:
        color = Colors.red.shade700;
        icon = Icons.warning_rounded;
        label = 'STOP';
      case ObstacleType.car:
        color = Colors.blue.shade700;
        icon = Icons.directions_car;
        label = 'CAR';
      case ObstacleType.wall:
        color = Colors.orange.shade700;
        icon = Icons.safety_divider;
        label = 'WALL';
    }

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COIN WIDGET
// ─────────────────────────────────────────────
class _CoinWidget extends StatelessWidget {
  const _CoinWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.amber,
        boxShadow: [
          BoxShadow(color: Colors.amber.withValues(alpha: 0.6), blurRadius: 8),
        ],
      ),
      child: const Center(
        child: Text(
          '\$',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
