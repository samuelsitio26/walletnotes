import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/database_helper.dart';

// ─────────────────────────────────────────────
//  Constants
// ─────────────────────────────────────────────
const int _kLanes = 3;
const double _kLaneWidth = 90.0;
const double _kPlayerSize = 46.0;
const double _kObjectSize = 38.0;
const double _kInitialSpeed = 220.0; // px per second
const double _kSpeedIncrement = 12.0; // added every 5 s
const double _kSpeedInterval = 5.0; // seconds
const double _kSpeedMax = 560.0;
const double _kPowerUpDuration = 6.0; // seconds

// ─────────────────────────────────────────────
//  Game object types
// ─────────────────────────────────────────────
enum ObjType { obstacle, coin, shield, magnet, doubleScore }

class _GameObject {
  int lane;
  double y;
  ObjType type;
  bool collected = false;

  _GameObject({required this.lane, required this.y, required this.type});
}

// ─────────────────────────────────────────────
//  ArcadeGame widget
// ─────────────────────────────────────────────
class ArcadeGame extends StatefulWidget {
  const ArcadeGame({super.key});

  @override
  State<ArcadeGame> createState() => _ArcadeGameState();
}

class _ArcadeGameState extends State<ArcadeGame>
    with SingleTickerProviderStateMixin {
  // ── Player ──
  int _playerLane = 1; // 0 left | 1 center | 2 right
  double _playerTargetX = 0;
  double _playerCurrentX = 0;

  // ── Game state ──
  bool _running = false;
  bool _gameOver = false;
  bool _started = false;
  int _lives = 3;
  int _score = 0;
  int _coins = 0;
  double _speed = _kInitialSpeed;

  // ── Power-ups ──
  bool _shieldActive = false;
  bool _magnetActive = false;
  bool _doubleScoreActive = false;
  double _shieldTimer = 0;
  double _magnetTimer = 0;
  double _doubleScoreTimer = 0;

  // ── Objects ──
  final List<_GameObject> _objects = [];
  final Random _rng = Random();
  double _spawnTimer = 0;
  double _spawnInterval = 1.4; // seconds between spawns
  double _speedTimer = 0;
  double _invincibleTimer = 0; // brief invincibility after hit

  // ── Layout ──
  double _trackWidth = _kLanes * _kLaneWidth;
  double _trackHeight = 600.0;

  // ── Ticker ──
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  // ── Drag input ──
  double? _dragStartX;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  //  Tick / update loop
  // ─────────────────────────────────────────
  void _onTick(Duration elapsed) {
    if (!_running) return;
    final dt = elapsed == Duration.zero
        ? 0.0
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.1) return; // skip first frame / huge gaps

    setState(() {
      _update(dt);
    });
  }

  void _update(double dt) {
    // Speed ramp
    _speedTimer += dt;
    if (_speedTimer >= _kSpeedInterval && _speed < _kSpeedMax) {
      _speedTimer = 0;
      _speed = min(_speed + _kSpeedIncrement, _kSpeedMax);
      _spawnInterval = max(0.55, _spawnInterval - 0.04);
    }

    // Score
    _score += (_speed * dt * (_doubleScoreActive ? 2 : 1) / 60).round();

    // Power-up timers
    if (_shieldActive) {
      _shieldTimer -= dt;
      if (_shieldTimer <= 0) _shieldActive = false;
    }
    if (_magnetActive) {
      _magnetTimer -= dt;
      if (_magnetTimer <= 0) _magnetActive = false;
    }
    if (_doubleScoreActive) {
      _doubleScoreTimer -= dt;
      if (_doubleScoreTimer <= 0) _doubleScoreActive = false;
    }

    if (_invincibleTimer > 0) _invincibleTimer -= dt;

    // Smooth player lane movement
    _playerCurrentX += (_playerTargetX - _playerCurrentX) * min(1.0, dt * 14);

    // Spawn objects
    _spawnTimer += dt;
    if (_spawnTimer >= _spawnInterval) {
      _spawnTimer = 0;
      _spawnObject();
    }

    // Move objects & check collisions
    final playerY = _trackHeight - 90.0;
    final toRemove = <_GameObject>[];

    for (final obj in _objects) {
      obj.y += _speed * dt;

      if (obj.y > _trackHeight + _kObjectSize) {
        toRemove.add(obj);
        continue;
      }
      if (obj.collected) continue;

      // Collision detection
      final objX = _laneToX(obj.lane);
      final dx = (objX - _playerCurrentX).abs();
      final dy = (obj.y - playerY).abs();
      final hitRadius = (_kPlayerSize / 2 + _kObjectSize / 2) * 0.72;

      if (dx < hitRadius && dy < hitRadius) {
        obj.collected = true;
        _handleCollision(obj.type);
      }

      // Magnet: attract nearby coins
      if (_magnetActive && obj.type == ObjType.coin) {
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 140) {
          obj.lane = _playerLane;
          obj.y -= _speed * dt * 1.8;
        }
      }
    }

    _objects.removeWhere((o) => toRemove.contains(o) || o.collected);
  }

  void _spawnObject() {
    final lane = _rng.nextInt(_kLanes);
    // Weighted random: 40% obstacle, 35% coin, 8% shield, 8% magnet, 9% doubleScore
    final r = _rng.nextDouble();
    ObjType type;
    if (r < 0.40) {
      type = ObjType.obstacle;
    } else if (r < 0.75) {
      type = ObjType.coin;
    } else if (r < 0.83) {
      type = ObjType.shield;
    } else if (r < 0.91) {
      type = ObjType.magnet;
    } else {
      type = ObjType.doubleScore;
    }

    // Avoid spawning obstacle on same lane as another obstacle close by
    if (type == ObjType.obstacle) {
      final blocked = _objects
          .where(
            (o) => o.type == ObjType.obstacle && o.lane == lane && o.y < 120,
          )
          .isNotEmpty;
      if (blocked) return;
    }

    _objects.add(_GameObject(lane: lane, y: -_kObjectSize, type: type));
  }

  void _handleCollision(ObjType type) {
    switch (type) {
      case ObjType.coin:
        _coins++;
        break;
      case ObjType.obstacle:
        if (_shieldActive) {
          _shieldActive = false;
          _shieldTimer = 0;
        } else if (_invincibleTimer <= 0) {
          _lives--;
          _invincibleTimer = 1.5;
          if (_lives <= 0) {
            _endGame();
          }
        }
        break;
      case ObjType.shield:
        _shieldActive = true;
        _shieldTimer = _kPowerUpDuration;
        break;
      case ObjType.magnet:
        _magnetActive = true;
        _magnetTimer = _kPowerUpDuration;
        break;
      case ObjType.doubleScore:
        _doubleScoreActive = true;
        _doubleScoreTimer = _kPowerUpDuration;
        break;
    }
  }

  // ─────────────────────────────────────────
  //  Game flow
  // ─────────────────────────────────────────
  void _startGame() {
    setState(() {
      _running = true;
      _started = true;
      _gameOver = false;
      _lives = 3;
      _score = 0;
      _coins = 0;
      _speed = _kInitialSpeed;
      _spawnInterval = 1.4;
      _speedTimer = 0;
      _spawnTimer = 0;
      _invincibleTimer = 0;
      _shieldActive = false;
      _magnetActive = false;
      _doubleScoreActive = false;
      _playerLane = 1;
      _playerTargetX = _laneToX(1);
      _playerCurrentX = _playerTargetX;
      _objects.clear();
      _lastTick = Duration.zero;
    });
    _ticker.start();
  }

  void _endGame() {
    _running = false;
    _ticker.stop();
    _gameOver = true;
    DatabaseHelper.instance.addGameCoins(_coins, _score);
  }

  void _moveLeft() {
    if (_playerLane > 0) {
      setState(() {
        _playerLane--;
        _playerTargetX = _laneToX(_playerLane);
      });
    }
  }

  void _moveRight() {
    if (_playerLane < _kLanes - 1) {
      setState(() {
        _playerLane++;
        _playerTargetX = _laneToX(_playerLane);
      });
    }
  }

  double _laneToX(int lane) {
    return lane * _kLaneWidth + _kLaneWidth / 2 - _kPlayerSize / 2;
  }

  // ─────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _trackWidth = _kLanes * _kLaneWidth;
    _trackHeight = MediaQuery.of(context).size.height - 200;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Wallet Runner',
          style: TextStyle(
            color: Colors.amberAccent,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHUD(),
          Expanded(
            child: Center(
              child: GestureDetector(
                onHorizontalDragStart: (d) => _dragStartX = d.localPosition.dx,
                onHorizontalDragUpdate: (d) {
                  if (_dragStartX == null) return;
                  final delta = d.localPosition.dx - _dragStartX!;
                  if (delta.abs() > 30) {
                    if (delta > 0) {
                      _moveRight();
                    } else {
                      _moveLeft();
                    }
                    _dragStartX = d.localPosition.dx;
                  }
                },
                onTapUp: (d) {
                  if (!_running && !_gameOver) {
                    _startGame();
                    return;
                  }
                  if (d.localPosition.dx < _trackWidth / 2) {
                    _moveLeft();
                  } else {
                    _moveRight();
                  }
                },
                child: _buildTrack(),
              ),
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildHUD() {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Lives
          Row(
            children: List.generate(
              3,
              (i) => Icon(
                Icons.favorite,
                color: i < _lives ? Colors.redAccent : Colors.grey[800],
                size: 22,
              ),
            ),
          ),
          // Score
          Text(
            'Skor: $_score',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          // Coins
          Row(
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text(
                '$_coins',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrack() {
    return Stack(
      children: [
        // Track background
        Container(
          width: _trackWidth,
          height: _trackHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            border: Border.all(color: Colors.blueGrey.shade800, width: 1),
          ),
          child: CustomPaint(
            painter: _LaneLinePainter(lanes: _kLanes, laneWidth: _kLaneWidth),
          ),
        ),

        // Game objects
        ..._objects.map((obj) => _buildObject(obj)),

        // Player
        _buildPlayer(),

        // Power-up indicators
        if (_shieldActive)
          _buildPowerUpOverlay(Icons.shield, Colors.cyanAccent, _shieldTimer),
        if (_magnetActive)
          Positioned(
            top: 8,
            left: 4,
            child: _powerUpBadge(
              Icons.offline_bolt,
              Colors.pinkAccent,
              _magnetTimer,
            ),
          ),
        if (_doubleScoreActive)
          Positioned(
            top: 8,
            right: 4,
            child: _powerUpBadge(
              Icons.double_arrow,
              Colors.greenAccent,
              _doubleScoreTimer,
            ),
          ),

        // Overlay messages
        if (!_started) _buildCenterMessage('Tap untuk mula!', null),
        if (_gameOver) _buildGameOverOverlay(),
      ],
    );
  }

  Widget _buildObject(_GameObject obj) {
    final x = _laneToX(obj.lane);
    Color color;
    IconData icon;
    switch (obj.type) {
      case ObjType.obstacle:
        color = Colors.redAccent;
        icon = Icons.block;
        break;
      case ObjType.coin:
        color = Colors.amber;
        icon = Icons.monetization_on;
        break;
      case ObjType.shield:
        color = Colors.cyanAccent;
        icon = Icons.shield;
        break;
      case ObjType.magnet:
        color = Colors.pinkAccent;
        icon = Icons.offline_bolt;
        break;
      case ObjType.doubleScore:
        color = Colors.greenAccent;
        icon = Icons.double_arrow;
        break;
    }

    return Positioned(
      left: x + (_kPlayerSize - _kObjectSize) / 2,
      top: obj.y - _kObjectSize / 2,
      child: Icon(icon, color: color, size: _kObjectSize),
    );
  }

  Widget _buildPlayer() {
    final playerY = _trackHeight - 90.0;
    final blink =
        _invincibleTimer > 0 && ((_invincibleTimer * 6).toInt() % 2 == 0);
    return Positioned(
      left: _playerCurrentX,
      top: playerY - _kPlayerSize / 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_shieldActive)
            Container(
              width: _kPlayerSize + 14,
              height: _kPlayerSize + 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.cyanAccent, width: 2.5),
                color: Colors.cyanAccent.withValues(alpha: 0.18),
              ),
            ),
          Icon(
            Icons.account_balance_wallet_rounded,
            color: blink ? Colors.transparent : Colors.amberAccent,
            size: _kPlayerSize,
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left button
          _controlButton(Icons.arrow_back_ios_rounded, _moveLeft),
          // Speed indicator
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.speed, color: Colors.white54, size: 18),
              Text(
                '${_speed.toInt()}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          // Right button
          _controlButton(Icons.arrow_forward_ios_rounded, _moveRight),
        ],
      ),
    );
  }

  Widget _controlButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white70, size: 26),
      ),
    );
  }

  Widget _buildCenterMessage(String msg, Color? color) {
    return Positioned.fill(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color ?? Colors.amberAccent,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Skor: $_score',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            Text(
              'Coins: $_coins',
              style: const TextStyle(color: Colors.amber, fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: _startGame,
              icon: const Icon(Icons.replay),
              label: const Text(
                'Main Lagi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Keluar',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerUpOverlay(IconData icon, Color color, double timer) {
    return Positioned(
      bottom: 12,
      left: 0,
      right: 0,
      child: Center(child: _powerUpBadge(icon, color, timer)),
    );
  }

  Widget _powerUpBadge(IconData icon, Color color, double timer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            '${timer.toStringAsFixed(1)}s',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Lane line painter
// ─────────────────────────────────────────────
class _LaneLinePainter extends CustomPainter {
  final int lanes;
  final double laneWidth;

  const _LaneLinePainter({required this.lanes, required this.laneWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < lanes; i++) {
      final x = i * laneWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Moving road dashes
    final dashPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 2;

    for (int lane = 0; lane < lanes; lane++) {
      final cx = lane * laneWidth + laneWidth / 2;
      for (double y = 0; y < size.height; y += 40) {
        canvas.drawLine(Offset(cx, y), Offset(cx, y + 20), dashPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_LaneLinePainter old) => false;
}
