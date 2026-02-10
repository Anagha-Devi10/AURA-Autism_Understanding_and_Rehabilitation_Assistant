/// Jumping Numbers Game
/// Counting & Focus Training - Tap numbers in the correct sequence

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';

class JumpingNumbersGame extends StatefulWidget {
  final Function(int score, int eyeContact, int motor) onGameComplete;

  const JumpingNumbersGame({
    super.key,
    required this.onGameComplete,
  });

  @override
  State<JumpingNumbersGame> createState() => _JumpingNumbersGameState();
}

class _JumpingNumbersGameState extends State<JumpingNumbersGame>
    with TickerProviderStateMixin {
  final Random _random = Random();
  int _currentLevel = 1;
  int _nextExpectedNumber = 1;
  int _score = 0;
  int _correctTaps = 0;
  int _totalTaps = 0;
  bool _showLevelComplete = false;
  bool _isGameOver = false;
  bool _isInitialized = false;
  List<JumpingNumber> _numbers = [];

  // Level configurations
  final List<LevelConfig> _levels = [
    LevelConfig(maxNumber: 5, label: 'Level 1: Count to 5'),
    LevelConfig(maxNumber: 7, label: 'Level 2: Count to 7'),
    LevelConfig(maxNumber: 10, label: 'Level 3: Count to 10'),
  ];

  @override
  void initState() {
    super.initState();
    // Don't call _startLevel here - wait for build
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize game after MediaQuery is available
    if (!_isInitialized) {
      _isInitialized = true;
      _startLevel();
    }
  }

  @override
  void dispose() {
    for (var num in _numbers) {
      num.bounceController.dispose();
    }
    super.dispose();
  }

  void _startLevel() {
    // Clear old numbers
    for (var num in _numbers) {
      num.bounceController.dispose();
    }
    _numbers.clear();

    final config = _levels[_currentLevel - 1];
    _nextExpectedNumber = 1;

    // Generate numbers with fixed positions (no MediaQuery needed)
    final positions = _generatePositions(config.maxNumber);

    for (int i = 1; i <= config.maxNumber; i++) {
      final controller = AnimationController(
        duration: Duration(milliseconds: 800 + _random.nextInt(400)),
        vsync: this,
      )..repeat(reverse: true);

      _numbers.add(JumpingNumber(
        value: i,
        x: positions[i - 1].dx,
        y: positions[i - 1].dy,
        color: _getNumberColor(i),
        bounceController: controller,
        isTapped: false,
      ));
    }

    if (mounted) {
      setState(() {});
    }
  }

  List<Offset> _generatePositions(int count) {
    final positions = <Offset>[];
    
    // Use fixed grid layout that works on all screen sizes
    final gridCols = 3;
    final cellWidth = 100.0;
    final cellHeight = 90.0;
    final startX = 30.0;
    final startY = 180.0;

    for (int i = 0; i < count; i++) {
      final row = i ~/ gridCols;
      final col = i % gridCols;

      // Add some randomness within the cell
      final x = startX + col * cellWidth + _random.nextDouble() * 20;
      final y = startY + row * cellHeight + _random.nextDouble() * 10;

      positions.add(Offset(x, y));
    }

    // Shuffle positions so numbers aren't in order visually
    positions.shuffle();
    return positions;
  }

  Color _getNumberColor(int number) {
    final colors = [
      const Color(0xFFFF6B6B), // Red
      const Color(0xFF4ECDC4), // Teal
      const Color(0xFFFFE66D), // Yellow
      const Color(0xFF95E1D3), // Mint
      const Color(0xFFF38181), // Coral
      const Color(0xFFAA96DA), // Purple
      const Color(0xFFFCBF49), // Orange
      const Color(0xFF80ED99), // Green
      const Color(0xFFFF9F1C), // Amber
      const Color(0xFF72DDF7), // Sky
    ];
    return colors[(number - 1) % colors.length];
  }

  void _tapNumber(JumpingNumber number) {
    if (number.isTapped || _showLevelComplete || _isGameOver) return;

    _totalTaps++;

    if (number.value == _nextExpectedNumber) {
      // Correct!
      setState(() {
        number.isTapped = true;
        _nextExpectedNumber++;
        _score += 10;
        _correctTaps++;
      });

      // Check if level complete
      final config = _levels[_currentLevel - 1];
      if (_nextExpectedNumber > config.maxNumber) {
        _completeLevel();
      }
    } else {
      // Wrong number - show feedback
      _showWrongFeedback();
    }
  }

  void _showWrongFeedback() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.close, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Find number $_nextExpectedNumber!',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: AuraTheme.warning,
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _completeLevel() {
    setState(() {
      _showLevelComplete = true;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        if (_currentLevel < _levels.length) {
          setState(() {
            _currentLevel++;
            _showLevelComplete = false;
          });
          _startLevel();
        } else {
          _endGame();
        }
      }
    });
  }

  void _endGame() {
    _isGameOver = true;
    final accuracy = _totalTaps > 0 ? ((_correctTaps / _totalTaps) * 100).round() : 0;
    widget.onGameComplete(_score, accuracy, accuracy);
  }

  @override
  Widget build(BuildContext context) {
    final config = _levels[_currentLevel - 1];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AuraTheme.gameG4,
              const Color(0xFFFFF5E6),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Numbers
            ..._numbers.map((number) {
              return AnimatedBuilder(
                animation: number.bounceController,
                builder: (context, child) {
                  final bounce = sin(number.bounceController.value * pi) * 10;
                  
                  return Positioned(
                    left: number.x,
                    top: number.y - bounce,
                    child: GestureDetector(
                      onTap: () => _tapNumber(number),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: number.isTapped ? 0.3 : 1.0,
                        child: AnimatedScale(
                          scale: number.isTapped ? 1.3 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: number.isTapped
                                  ? AuraTheme.success
                                  : number.color,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: (number.isTapped
                                          ? AuraTheme.success
                                          : number.color)
                                      .withAlpha(150),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: number.isTapped
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 36,
                                    )
                                  : Text(
                                      '${number.value}',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

            // UI Overlay
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Level
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(220),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            config.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AuraTheme.textDark,
                            ),
                          ),
                        ),
                        // Score
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(220),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.stars, color: Colors.amber, size: 24),
                              const SizedBox(width: 6),
                              Text(
                                '$_score',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AuraTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Instruction
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.touch_app,
                            color: AuraTheme.accentCornflower,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Tap number $_nextExpectedNumber',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AuraTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Level Complete Overlay
            if (_showLevelComplete)
              Container(
                color: Colors.black.withAlpha(100),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AuraTheme.success.withAlpha(100),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.celebration,
                          size: 60,
                          color: AuraTheme.success,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _currentLevel < _levels.length
                              ? 'Level $_currentLevel Complete!'
                              : 'All Levels Complete!',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AuraTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Great counting!',
                          style: TextStyle(
                            fontSize: 18,
                            color: AuraTheme.textMedium,
                          ),
                        ),
                      ],
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

class JumpingNumber {
  final int value;
  final double x;
  final double y;
  final Color color;
  final AnimationController bounceController;
  bool isTapped;

  JumpingNumber({
    required this.value,
    required this.x,
    required this.y,
    required this.color,
    required this.bounceController,
    required this.isTapped,
  });
}

class LevelConfig {
  final int maxNumber;
  final String label;

  LevelConfig({required this.maxNumber, required this.label});
}
