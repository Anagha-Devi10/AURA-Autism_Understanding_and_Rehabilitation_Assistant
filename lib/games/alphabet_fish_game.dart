/// Alphabet Fish Game
/// Letter Recognition Training - Catch fish with letters to spell words

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';

class AlphabetFishGame extends StatefulWidget {
  final Function(int score, int eyeContact, int motor) onGameComplete;

  const AlphabetFishGame({
    super.key,
    required this.onGameComplete,
  });

  @override
  State<AlphabetFishGame> createState() => _AlphabetFishGameState();
}

class _AlphabetFishGameState extends State<AlphabetFishGame>
    with TickerProviderStateMixin {
  // Game state
  Timer? _gameTimer;
  Timer? _spawnTimer;
  int _timeRemaining = 60;
  int _score = 0;
  int _wordsCompleted = 0;
  bool _isGameOver = false;
  
  // Word state
  final List<String> _words = ['CAT', 'DOG', 'SUN', 'HAT', 'CUP', 'BEE', 'PIG', 'BAT', 'FOX', 'HEN'];
  late String _currentWord;
  int _currentLetterIndex = 0;
  List<String> _collectedLetters = [];
  
  // Fish state
  final List<SwimmingFish> _fishes = [];
  final Random _random = Random();
  
  // Fish colors
  final List<Color> _fishColors = [
    const Color(0xFFFFB5BA), // Pink
    const Color(0xFFB5D8FF), // Blue
    const Color(0xFFB5FFB8), // Green
    const Color(0xFFFFE5B5), // Orange
    const Color(0xFFE5B5FF), // Purple
    const Color(0xFFFFEB3B), // Yellow
  ];

  @override
  void initState() {
    super.initState();
    _selectNewWord();
    _startGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    for (var fish in _fishes) {
      fish.controller.dispose();
    }
    super.dispose();
  }

  void _selectNewWord() {
    _currentWord = _words[_random.nextInt(_words.length)];
    _currentLetterIndex = 0;
    _collectedLetters = [];
  }

  void _startGame() {
    // Spawn fish periodically
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (!_isGameOver && _fishes.length < 6) {
        _spawnFish();
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

    // Spawn initial fish
    for (int i = 0; i < 4; i++) {
      Future.delayed(Duration(milliseconds: i * 300), () {
        if (mounted && !_isGameOver) _spawnFish();
      });
    }
  }

  void _spawnFish() {
    if (!mounted) return;

    final size = MediaQuery.of(context).size;
    final fishSize = 70.0 + _random.nextDouble() * 30;
    
    // Decide if this fish should have a needed letter
    String letter;
    if (_random.nextDouble() < 0.4 && _currentLetterIndex < _currentWord.length) {
      // 40% chance to spawn the next needed letter
      letter = _currentWord[_currentLetterIndex];
    } else {
      // Random letter
      letter = String.fromCharCode(65 + _random.nextInt(26));
    }
    
    final fromLeft = _random.nextBool();
    final startX = fromLeft ? -fishSize : size.width;
    final endX = fromLeft ? size.width : -fishSize;
    final y = 150 + _random.nextDouble() * (size.height - 350);

    final controller = AnimationController(
      duration: Duration(milliseconds: 4000 + _random.nextInt(2000)),
      vsync: this,
    );

    final fish = SwimmingFish(
      id: DateTime.now().millisecondsSinceEpoch + _random.nextInt(1000),
      startX: startX,
      endX: endX,
      y: y,
      size: fishSize,
      letter: letter,
      color: _fishColors[_random.nextInt(_fishColors.length)],
      controller: controller,
      facingLeft: !fromLeft,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _fishes.removeWhere((f) => f.id == fish.id);
        });
        controller.dispose();
      }
    });

    setState(() {
      _fishes.add(fish);
    });

    controller.forward();
  }

  void _catchFish(SwimmingFish fish) {
    if (_isGameOver) return;

    final neededLetter = _currentLetterIndex < _currentWord.length
        ? _currentWord[_currentLetterIndex]
        : '';

    if (fish.letter == neededLetter) {
      // Correct letter!
      setState(() {
        _collectedLetters.add(fish.letter);
        _currentLetterIndex++;
        _score += 15;
        _fishes.removeWhere((f) => f.id == fish.id);
      });
      fish.controller.dispose();

      // Check if word is complete
      if (_currentLetterIndex >= _currentWord.length) {
        _onWordComplete();
      }
    } else {
      // Wrong letter - small penalty
      setState(() {
        _score = max(0, _score - 5);
      });
    }
  }

  void _onWordComplete() {
    _wordsCompleted++;
    _score += 30; // Bonus for completing word
    
    // Show celebration briefly then new word
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_isGameOver) {
        setState(() {
          _selectNewWord();
        });
      }
    });
  }

  void _endGame() {
    _isGameOver = true;
    _gameTimer?.cancel();
    _spawnTimer?.cancel();

    // Calculate scores
    final eyeContactScore = min(100, _wordsCompleted * 20 + 40);
    final motorScore = min(100, _score ~/ 2);

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
            AuraTheme.gameG5,
            const Color(0xFF81D4FA),
            const Color(0xFF4FC3F7),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Water bubbles decoration
          ...List.generate(8, (index) => Positioned(
            left: _random.nextDouble() * MediaQuery.of(context).size.width,
            top: _random.nextDouble() * MediaQuery.of(context).size.height,
            child: Container(
              width: 20 + _random.nextDouble() * 20,
              height: 20 + _random.nextDouble() * 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(40),
              ),
            ),
          )),

          // Swimming fish
          ..._fishes.map((fish) => AnimatedBuilder(
            animation: fish.controller,
            builder: (context, child) {
              final currentX = fish.startX + (fish.endX - fish.startX) * fish.controller.value;
              final wobble = sin(fish.controller.value * 8 * pi) * 10;

              return Positioned(
                left: currentX,
                top: fish.y + wobble,
                child: GestureDetector(
                  onTap: () => _catchFish(fish),
                  child: Transform.scale(
                    scaleX: fish.facingLeft ? -1 : 1,
                    child: Container(
                      width: fish.size,
                      height: fish.size * 0.7,
                      decoration: BoxDecoration(
                        color: fish.color,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(fish.size * 0.5),
                          topRight: Radius.circular(fish.size * 0.3),
                          bottomLeft: Radius.circular(fish.size * 0.5),
                          bottomRight: Radius.circular(fish.size * 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: fish.color.withAlpha(100),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Fish tail
                          Positioned(
                            right: -fish.size * 0.15,
                            top: fish.size * 0.1,
                            child: Transform.rotate(
                              angle: 0.3,
                              child: Container(
                                width: fish.size * 0.3,
                                height: fish.size * 0.4,
                                decoration: BoxDecoration(
                                  color: fish.color,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          // Fish eye
                          Positioned(
                            left: fish.size * 0.15,
                            top: fish.size * 0.15,
                            child: Container(
                              width: fish.size * 0.15,
                              height: fish.size * 0.15,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: fish.size * 0.08,
                                  height: fish.size * 0.08,
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Letter on fish
                          Center(
                            child: Text(
                              fish.letter,
                              style: TextStyle(
                                fontSize: fish.size * 0.4,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withAlpha(50),
                                    blurRadius: 3,
                                    offset: const Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          )),

          // UI Overlay
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Score
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                            const Icon(Icons.stars, color: Colors.amber, size: 28),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: _timeRemaining <= 10
                              ? AuraTheme.error.withAlpha(220)
                              : Colors.white.withAlpha(220),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer,
                              color: _timeRemaining <= 10 ? Colors.white : AuraTheme.textDark,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_timeRemaining',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _timeRemaining <= 10 ? Colors.white : AuraTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Word to spell
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Spell the word:',
                        style: TextStyle(
                          fontSize: 14,
                          color: AuraTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_currentWord.length, (index) {
                          final isCollected = index < _collectedLetters.length;
                          final isNext = index == _currentLetterIndex;
                          return Container(
                            width: 45,
                            height: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isCollected
                                  ? AuraTheme.success.withAlpha(50)
                                  : isNext
                                      ? AuraTheme.accentCornflower.withAlpha(50)
                                      : Colors.grey.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCollected
                                    ? AuraTheme.success
                                    : isNext
                                        ? AuraTheme.accentCornflower
                                        : Colors.grey.withAlpha(100),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                isCollected ? _collectedLetters[index] : _currentWord[index],
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: isCollected
                                      ? AuraTheme.success
                                      : isNext
                                          ? AuraTheme.accentCornflower
                                          : Colors.grey.withAlpha(150),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Instructions
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(200),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '🐟 ',
                        style: TextStyle(fontSize: 24),
                      ),
                      Text(
                        'Tap fish with "${_currentLetterIndex < _currentWord.length ? _currentWord[_currentLetterIndex] : '✓'}" to spell!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AuraTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SwimmingFish {
  final int id;
  final double startX;
  final double endX;
  final double y;
  final double size;
  final String letter;
  final Color color;
  final AnimationController controller;
  final bool facingLeft;

  SwimmingFish({
    required this.id,
    required this.startX,
    required this.endX,
    required this.y,
    required this.size,
    required this.letter,
    required this.color,
    required this.controller,
    required this.facingLeft,
  });
}
