/// Magnet Catch Game
/// Eye Contact Training - Tap floating bubbles to catch them

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';

class MagnetCatchGame extends StatefulWidget {
  final Function(int score, int eyeContact, int motor) onGameComplete;

  const MagnetCatchGame({
    super.key,
    required this.onGameComplete,
  });

  @override
  State<MagnetCatchGame> createState() => _MagnetCatchGameState();
}

class _MagnetCatchGameState extends State<MagnetCatchGame>
    with TickerProviderStateMixin {
  final List<Bubble> _bubbles = [];
  final Random _random = Random();
  int _score = 0;
  int _totalBubbles = 0;
  int _caughtBubbles = 0;
  Timer? _spawnTimer;
  Timer? _gameTimer;
  int _timeRemaining = 60;
  bool _isGameOver = false;

  // Pastel colors for bubbles
  final List<Color> _bubbleColors = [
    const Color(0xFFFFB5BA), // Pastel pink
    const Color(0xFFB5D8FF), // Pastel blue
    const Color(0xFFB5FFB8), // Pastel green
    const Color(0xFFFFE5B5), // Pastel orange
    const Color(0xFFE5B5FF), // Pastel purple
    const Color(0xFFB5FFFF), // Pastel cyan
  ];

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    for (var bubble in _bubbles) {
      bubble.controller.dispose();
    }
    super.dispose();
  }

  void _startGame() {
    // Spawn bubbles periodically
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!_isGameOver && _bubbles.length < 8) {
        _spawnBubble();
      }
    });

    // Game countdown timer
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeRemaining--;
          if (_timeRemaining <= 0) {
            _endGame();
          }
        });
      }
    });

    // Spawn initial bubbles
    for (int i = 0; i < 4; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted && !_isGameOver) _spawnBubble();
      });
    }
  }

  void _spawnBubble() {
    if (!mounted) return;

    final size = MediaQuery.of(context).size;
    final bubbleSize = 60.0 + _random.nextDouble() * 40; // 60-100px

    final controller = AnimationController(
      duration: Duration(milliseconds: 3000 + _random.nextInt(2000)),
      vsync: this,
    );

    final bubble = Bubble(
      id: DateTime.now().millisecondsSinceEpoch + _random.nextInt(1000),
      x: _random.nextDouble() * (size.width - bubbleSize),
      y: size.height, // Start from bottom
      size: bubbleSize,
      color: _bubbleColors[_random.nextInt(_bubbleColors.length)],
      controller: controller,
      targetY: -bubbleSize, // Float to top and beyond
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _bubbles.removeWhere((b) => b.id == bubble.id);
        });
        controller.dispose();
      }
    });

    setState(() {
      _bubbles.add(bubble);
      _totalBubbles++;
    });

    controller.forward();
  }

  void _popBubble(Bubble bubble) {
    if (_isGameOver) return;

    setState(() {
      _score += 10;
      _caughtBubbles++;
      _bubbles.removeWhere((b) => b.id == bubble.id);
    });

    bubble.controller.dispose();
  }

  void _endGame() {
    _isGameOver = true;
    _spawnTimer?.cancel();
    _gameTimer?.cancel();

    // Calculate scores
    final eyeContactScore = _totalBubbles > 0
        ? ((_caughtBubbles / _totalBubbles) * 100).round()
        : 0;
    final motorScore = _caughtBubbles > 0
        ? min(100, (_score / 5).round())
        : 0;

    widget.onGameComplete(_score, eyeContactScore, motorScore);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AuraTheme.gameG1,
            AuraTheme.primaryPastelBlue,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background decoration
          ...List.generate(5, (index) => Positioned(
            left: _random.nextDouble() * MediaQuery.of(context).size.width,
            top: _random.nextDouble() * MediaQuery.of(context).size.height,
            child: Icon(
              Icons.star,
              size: 20,
              color: Colors.white.withAlpha(50),
            ),
          )),

          // Bubbles
          ..._bubbles.map((bubble) => AnimatedBuilder(
            animation: bubble.controller,
            builder: (context, child) {
              final currentY = bubble.y +
                  (bubble.targetY - bubble.y) * bubble.controller.value;
              
              // Add gentle horizontal wobble
              final wobble = sin(bubble.controller.value * 4 * pi) * 15;

              return Positioned(
                left: bubble.x + wobble,
                top: currentY,
                child: GestureDetector(
                  onTap: () => _popBubble(bubble),
                  child: Container(
                    width: bubble.size,
                    height: bubble.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withAlpha(200),
                          bubble.color,
                          bubble.color.withAlpha(180),
                        ],
                        stops: const [0.0, 0.3, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: bubble.color.withAlpha(100),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.catching_pokemon,
                        size: bubble.size * 0.4,
                        color: Colors.white.withAlpha(180),
                      ),
                    ),
                  ),
                ),
              );
            },
          )),

          // UI Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Top bar with score and timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Score
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(220),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.stars,
                              color: Colors.amber,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_score',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AuraTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Timer
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _timeRemaining <= 10
                              ? AuraTheme.error.withAlpha(220)
                              : Colors.white.withAlpha(220),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer,
                              color: _timeRemaining <= 10
                                  ? Colors.white
                                  : AuraTheme.textDark,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_timeRemaining',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _timeRemaining <= 10
                                    ? Colors.white
                                    : AuraTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(200),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '👆 Tap the bubbles to catch them!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AuraTheme.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Bubble {
  final int id;
  final double x;
  final double y;
  final double size;
  final Color color;
  final AnimationController controller;
  final double targetY;

  Bubble({
    required this.id,
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.controller,
    required this.targetY,
  });
}
