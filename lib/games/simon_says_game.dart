/// Simon Says Game
/// Following Instructions Training - Remember and repeat color patterns

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/aura_theme.dart';

class SimonSaysGame extends StatefulWidget {
  final Function(int score, int eyeContact, int motor) onGameComplete;

  const SimonSaysGame({
    super.key,
    required this.onGameComplete,
  });

  @override
  State<SimonSaysGame> createState() => _SimonSaysGameState();
}

class _SimonSaysGameState extends State<SimonSaysGame>
    with TickerProviderStateMixin {
  // Game state
  Timer? _gameTimer;
  int _timeRemaining = 60;
  int _score = 0;
  int _level = 1;
  bool _isGameOver = false;
  
  // Pattern state
  List<int> _pattern = [];
  int _playerIndex = 0;
  bool _isShowingPattern = false;
  bool _isPlayerTurn = false;
  int? _activeButton;
  
  // Colors for the 4 buttons
  final List<Color> _buttonColors = [
    const Color(0xFFEF5350), // Red
    const Color(0xFF42A5F5), // Blue
    const Color(0xFF66BB6A), // Green
    const Color(0xFFFFCA28), // Yellow
  ];
  
  final List<Color> _buttonActiveColors = [
    const Color(0xFFFF8A80), // Light Red
    const Color(0xFF82B1FF), // Light Blue
    const Color(0xFFB9F6CA), // Light Green
    const Color(0xFFFFFF8D), // Light Yellow
  ];
  
  final Random _random = Random();
  
  // Animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _startGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startGame() {
    // Game countdown timer
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isShowingPattern) {
        setState(() {
          _timeRemaining--;
          if (_timeRemaining <= 0) {
            _endGame();
          }
        });
      }
    });

    // Start first round
    _startNewRound();
  }

  void _startNewRound() {
    // Add new color to pattern
    _pattern.add(_random.nextInt(4));
    _playerIndex = 0;
    _isPlayerTurn = false;
    
    // Show pattern to player
    _showPattern();
  }

  void _showPattern() async {
    setState(() {
      _isShowingPattern = true;
      _isPlayerTurn = false;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    for (int i = 0; i < _pattern.length; i++) {
      if (_isGameOver || !mounted) return;
      
      // Light up button
      setState(() {
        _activeButton = _pattern[i];
      });
      
      HapticFeedback.lightImpact();
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Turn off button
      setState(() {
        _activeButton = null;
      });
      
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted && !_isGameOver) {
      setState(() {
        _isShowingPattern = false;
        _isPlayerTurn = true;
      });
    }
  }

  void _onButtonTap(int buttonIndex) {
    if (!_isPlayerTurn || _isShowingPattern || _isGameOver) return;

    HapticFeedback.selectionClick();
    
    // Flash the button
    setState(() {
      _activeButton = buttonIndex;
    });
    
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _activeButton = null;
        });
      }
    });

    if (buttonIndex == _pattern[_playerIndex]) {
      // Correct!
      _playerIndex++;
      _score += 10;

      if (_playerIndex >= _pattern.length) {
        // Completed the pattern!
        _level++;
        _score += _level * 5; // Bonus for completing level
        
        setState(() {
          _isPlayerTurn = false;
        });
        
        // Show success and start next round
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && !_isGameOver) {
            _startNewRound();
          }
        });
      }
    } else {
      // Wrong! Reset pattern
      _onMistake();
    }
    
    setState(() {});
  }

  void _onMistake() {
    HapticFeedback.heavyImpact();
    
    setState(() {
      _score = max(0, _score - 15);
      _pattern = [];
      _level = max(1, _level - 1);
      _playerIndex = 0;
      _isPlayerTurn = false;
    });

    // Start fresh after a delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && !_isGameOver) {
        _startNewRound();
      }
    });
  }

  void _endGame() {
    _isGameOver = true;
    _gameTimer?.cancel();

    // Calculate scores
    final maxLevel = _level;
    final eyeContactScore = min(100, maxLevel * 15 + 30);
    final motorScore = min(100, _score ~/ 3);

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
            AuraTheme.gameG7,
            const Color(0xFFFFF9C4),
            Colors.white,
          ],
        ),
      ),
      child: SafeArea(
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
                  // Level
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(220),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up, color: AuraTheme.success, size: 24),
                        const SizedBox(width: 6),
                        Text(
                          'Level $_level',
                          style: const TextStyle(
                            fontSize: 18,
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

            // Status message
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(220),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isShowingPattern 
                        ? Icons.visibility
                        : _isPlayerTurn 
                            ? Icons.touch_app
                            : Icons.hourglass_empty,
                    color: _isPlayerTurn ? AuraTheme.success : AuraTheme.accentCornflower,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isShowingPattern 
                        ? 'Watch the pattern...'
                        : _isPlayerTurn 
                            ? 'Your turn! Repeat the pattern'
                            : 'Get ready...',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AuraTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),

            // Pattern progress
            if (_isPlayerTurn)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pattern.length, (index) {
                    final isCompleted = index < _playerIndex;
                    final isCurrent = index == _playerIndex;
                    return Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted 
                            ? AuraTheme.success 
                            : isCurrent 
                                ? AuraTheme.accentCornflower
                                : Colors.grey.withAlpha(100),
                        border: Border.all(
                          color: isCurrent ? AuraTheme.accentCornflower : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: isCompleted 
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : null,
                    );
                  }),
                ),
              ),

            const SizedBox(height: 20),

            // Simon buttons grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final buttonSize = min(constraints.maxWidth, constraints.maxHeight) / 2 - 16;
                    return Center(
                      child: SizedBox(
                        width: buttonSize * 2 + 16,
                        height: buttonSize * 2 + 16,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSimonButton(0, buttonSize),
                                const SizedBox(width: 16),
                                _buildSimonButton(1, buttonSize),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildSimonButton(2, buttonSize),
                                const SizedBox(width: 16),
                                _buildSimonButton(3, buttonSize),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Instructions
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(200),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '🎮 Watch the colors light up, then tap them in the same order!',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AuraTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimonButton(int index, double size) {
    final isActive = _activeButton == index;
    final baseColor = _buttonColors[index];
    final activeColor = _buttonActiveColors[index];
    
    return GestureDetector(
      onTap: () => _onButtonTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isActive ? activeColor : baseColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isActive ? activeColor : baseColor).withAlpha(isActive ? 180 : 100),
              blurRadius: isActive ? 25 : 15,
              spreadRadius: isActive ? 5 : 2,
            ),
            if (isActive)
              BoxShadow(
                color: Colors.white.withAlpha(150),
                blurRadius: 20,
                spreadRadius: -5,
              ),
          ],
          border: Border.all(
            color: Colors.white.withAlpha(isActive ? 200 : 100),
            width: 4,
          ),
        ),
        child: Center(
          child: Icon(
            _getButtonIcon(index),
            size: size * 0.35,
            color: Colors.white.withAlpha(isActive ? 255 : 180),
          ),
        ),
      ),
    );
  }

  IconData _getButtonIcon(int index) {
    switch (index) {
      case 0: return Icons.favorite;
      case 1: return Icons.water_drop;
      case 2: return Icons.eco;
      case 3: return Icons.star;
      default: return Icons.circle;
    }
  }
}
