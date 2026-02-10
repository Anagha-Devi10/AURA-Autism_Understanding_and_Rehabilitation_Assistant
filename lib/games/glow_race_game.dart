/// Glow Race Game
/// Visual Tracking Training - Follow the glowing light and tap when it stops

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/aura_theme.dart';

class GlowRaceGame extends StatefulWidget {
  final Function(int score, int eyeContact, int motor) onGameComplete;

  const GlowRaceGame({
    super.key,
    required this.onGameComplete,
  });

  @override
  State<GlowRaceGame> createState() => _GlowRaceGameState();
}

class _GlowRaceGameState extends State<GlowRaceGame>
    with TickerProviderStateMixin {
  // Game state
  Timer? _gameTimer;
  int _timeRemaining = 60;
  int _score = 0;
  int _correctTaps = 0;
  int _totalRounds = 0;
  bool _isGameOver = false;
  
  // Orb state
  late AnimationController _orbController;
  late Animation<Offset> _orbAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  
  bool _isMoving = true;
  bool _canTap = false;
  Offset _orbPosition = const Offset(0.5, 0.5);
  Timer? _stopTimer;
  Timer? _restartTimer;
  
  // Orb colors
  final List<Color> _orbColors = [
    const Color(0xFF00E5FF), // Cyan
    const Color(0xFF76FF03), // Lime
    const Color(0xFFFFD600), // Yellow
    const Color(0xFFFF4081), // Pink
    const Color(0xFF7C4DFF), // Purple
  ];
  late Color _currentOrbColor;
  
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _currentOrbColor = _orbColors[0];
    
    // Glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(_glowController);
    
    // Movement animation
    _orbController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startGame();
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _stopTimer?.cancel();
    _restartTimer?.cancel();
    _orbController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _startGame() {
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

    _startNewRound();
  }

  void _startNewRound() {
    if (_isGameOver || !mounted) return;
    
    _totalRounds++;
    _currentOrbColor = _orbColors[_random.nextInt(_orbColors.length)];
    
    final size = MediaQuery.of(context).size;
    final safeWidth = size.width - 100;
    final safeHeight = size.height - 300;
    
    // Generate random path
    final startX = _orbPosition.dx;
    final startY = _orbPosition.dy;
    final endX = 50 + _random.nextDouble() * safeWidth;
    final endY = 150 + _random.nextDouble() * safeHeight;
    
    // Create movement animation
    _orbController.reset();
    _orbAnimation = Tween<Offset>(
      begin: Offset(startX, startY),
      end: Offset(endX, endY),
    ).animate(CurvedAnimation(
      parent: _orbController,
      curve: Curves.easeInOutSine,
    ));
    
    _orbAnimation.addListener(() {
      if (mounted) {
        setState(() {
          _orbPosition = _orbAnimation.value;
        });
      }
    });
    
    setState(() {
      _isMoving = true;
      _canTap = false;
    });
    
    // Start movement
    _orbController.forward();
    
    // Schedule stop after random duration
    final moveDuration = 1500 + _random.nextInt(1500);
    _stopTimer?.cancel();
    _stopTimer = Timer(Duration(milliseconds: moveDuration), () {
      if (mounted && !_isGameOver) {
        _stopOrb();
      }
    });
  }

  void _stopOrb() {
    _orbController.stop();
    
    setState(() {
      _isMoving = false;
      _canTap = true;
    });
    
    HapticFeedback.lightImpact();
    
    // Auto-restart after timeout if not tapped
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted && !_isGameOver && _canTap) {
        // Missed the tap
        setState(() {
          _canTap = false;
          _score = max(0, _score - 10);
        });
        _startNewRound();
      }
    });
  }

  void _onOrbTap() {
    if (!_canTap || _isGameOver) return;
    
    HapticFeedback.mediumImpact();
    _restartTimer?.cancel();
    
    setState(() {
      _correctTaps++;
      _score += 20;
      _canTap = false;
    });
    
    // Show success briefly then start next round
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isGameOver) {
        _startNewRound();
      }
    });
  }

  void _onWrongTap() {
    if (_isMoving && !_isGameOver) {
      HapticFeedback.heavyImpact();
      setState(() {
        _score = max(0, _score - 5);
      });
    }
  }

  void _endGame() {
    _isGameOver = true;
    _gameTimer?.cancel();
    _stopTimer?.cancel();
    _restartTimer?.cancel();
    _orbController.stop();

    // Calculate scores
    final accuracy = _totalRounds > 0 ? (_correctTaps / _totalRounds * 100).round() : 0;
    final eyeContactScore = min(100, accuracy + 20);
    final motorScore = min(100, _score ~/ 3);

    widget.onGameComplete(_score, eyeContactScore, motorScore);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _onWrongTap(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AuraTheme.gameG8,
              const Color(0xFF006064),
              const Color(0xFF004D40),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Star decorations
            ...List.generate(20, (index) => Positioned(
              left: _random.nextDouble() * MediaQuery.of(context).size.width,
              top: _random.nextDouble() * MediaQuery.of(context).size.height,
              child: Icon(
                Icons.star,
                size: 8 + _random.nextDouble() * 12,
                color: Colors.white.withAlpha(30 + _random.nextInt(50)),
              ),
            )),

            // Glowing orb
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Positioned(
                  left: _orbPosition.dx - 40,
                  top: _orbPosition.dy - 40,
                  child: GestureDetector(
                    onTap: _onOrbTap,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white,
                            _currentOrbColor,
                            _currentOrbColor.withAlpha(150),
                            _currentOrbColor.withAlpha(0),
                          ],
                          stops: const [0.0, 0.3, 0.6, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _currentOrbColor.withAlpha(
                              _canTap ? 200 : (100 * _glowAnimation.value).round(),
                            ),
                            blurRadius: _canTap ? 50 : 30 * _glowAnimation.value,
                            spreadRadius: _canTap ? 20 : 10 * _glowAnimation.value,
                          ),
                          if (_canTap)
                            BoxShadow(
                              color: Colors.white.withAlpha(100),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha(_canTap ? 255 : 200),
                          ),
                          child: _canTap
                              ? const Icon(
                                  Icons.touch_app,
                                  color: Colors.teal,
                                  size: 24,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Trail effect when moving
            if (_isMoving)
              ...List.generate(5, (index) {
                final opacity = (5 - index) / 10;
                final scale = 1.0 - (index * 0.15);
                return Positioned(
                  left: _orbPosition.dx - 30 * scale,
                  top: _orbPosition.dy - 30 * scale,
                  child: Container(
                    width: 60 * scale,
                    height: 60 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentOrbColor.withAlpha((opacity * 100).round()),
                    ),
                  ),
                );
              }),

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
                        // Accuracy
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(220),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.gps_fixed, color: AuraTheme.success, size: 24),
                              const SizedBox(width: 6),
                              Text(
                                '$_correctTaps/$_totalRounds',
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

                  // Status indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: _canTap 
                          ? AuraTheme.success.withAlpha(220)
                          : Colors.white.withAlpha(180),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _canTap ? Icons.touch_app : Icons.visibility,
                          color: _canTap ? Colors.white : AuraTheme.textDark,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _canTap ? 'TAP NOW!' : 'Follow the light...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _canTap ? Colors.white : AuraTheme.textDark,
                          ),
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
                    child: const Text(
                      '👀 Watch the glowing orb move. Tap it when it stops!',
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
          ],
        ),
      ),
    );
  }
}
