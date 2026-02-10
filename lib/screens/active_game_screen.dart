/// AURA Active Game Screen
/// In-session game view that routes to the appropriate game

import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';
import '../services/api_service.dart';
import '../games/magnet_catch_game.dart';
import '../games/sound_match_game.dart';
import '../games/emotion_slider_game.dart';
import '../games/jumping_numbers_game.dart';
import '../games/invisible_maze_game.dart';
import '../games/alphabet_fish_game.dart';
import '../games/simon_says_game.dart';
import '../games/glow_race_game.dart';

class ActiveGameScreen extends StatefulWidget {
  final Map<String, dynamic> game;
  final Map<String, dynamic> session;
  final String childName;

  const ActiveGameScreen({
    super.key,
    required this.game,
    required this.session,
    required this.childName,
  });

  @override
  State<ActiveGameScreen> createState() => _ActiveGameScreenState();
}

class _ActiveGameScreenState extends State<ActiveGameScreen>
    with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  
  // Timer
  Timer? _timer;
  int _seconds = 0;
  
  // Scores (0-100)
  int _eyeContactScore = 50;
  int _speechScore = 50;
  int _motorScore = 50;
  int _gameScore = 0;
  
  // Game state
  bool _showGame = true;
  bool _gameCompleted = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_gameCompleted) {
        setState(() => _seconds++);
      }
    });
  }

  String get _formattedTime {
    final minutes = _seconds ~/ 60;
    final remainingSeconds = _seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _onGameComplete(int score, int eyeContact, int motor) {
    setState(() {
      _gameScore = score;
      _eyeContactScore = eyeContact;
      _motorScore = motor;
      _speechScore = ((eyeContact + motor) / 2).round();
      _gameCompleted = true;
      _showGame = false;
    });
    _endSession();
  }

  void _endSession() async {
    _timer?.cancel();
    
    // Record scores
    final sessionId = widget.session['id'];
    if (sessionId != null && sessionId != 0) {
      await _api.recordScore(
        sessionId: sessionId,
        eyeContactScore: _eyeContactScore,
        speechScore: _speechScore,
        motorScore: _motorScore,
      );
      await _api.stopGame(sessionId);
    }

    // Show completion dialog
    if (mounted) {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    final overallScore = (_eyeContactScore + _speechScore + _motorScore) ~/ 3;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AuraTheme.success.withAlpha((0.15 * 255).round()),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  size: 40,
                  color: AuraTheme.success,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Great Job!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AuraTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.childName} completed ${widget.game['name']}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AuraTheme.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Game Score
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AuraTheme.accentCornflower.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, color: Colors.amber, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      'Score: $_gameScore',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AuraTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Time: $_formattedTime',
                style: const TextStyle(
                  fontSize: 14,
                  color: AuraTheme.textMedium,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close game screen
                    Navigator.pop(context); // Close detail screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuraTheme.accentCornflower,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGame() {
    final gameId = widget.game['id'] ?? 'G1';
    
    switch (gameId) {
      case 'G1': // Magnet Catch
        return MagnetCatchGame(onGameComplete: _onGameComplete);
      case 'G2': // Sound Match
        return SoundMatchGame(onGameComplete: _onGameComplete);
      case 'G3': // Invisible Maze
        return InvisibleMazeGame(onGameComplete: _onGameComplete);
      case 'G4': // Jumping Numbers
        return JumpingNumbersGame(onGameComplete: _onGameComplete);
      case 'G5': // Alphabet Fish
        return AlphabetFishGame(onGameComplete: _onGameComplete);
      case 'G6': // Emotion Slider
        return EmotionSliderGame(onGameComplete: _onGameComplete);
      case 'G7': // Simon Says
        return SimonSaysGame(onGameComplete: _onGameComplete);
      case 'G8': // Glow Race
        return GlowRaceGame(onGameComplete: _onGameComplete);
      default:
        // Fallback to placeholder for unimplemented games
        return _buildPlaceholderGame();
    }
  }

  Widget _buildPlaceholderGame() {
    final gameId = widget.game['id'] ?? 'G1';
    final gameColor = AuraTheme.getGameColor(gameId);
    final gameIcon = AuraTheme.getGameIcon(gameId);

    return Container(
      color: gameColor,
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Timer
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.8 * 255).round()),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 20,
                          color: AuraTheme.textDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formattedTime,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AuraTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // End Button
                  GestureDetector(
                    onTap: () {
                      _onGameComplete(0, 50, 50);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AuraTheme.error.withAlpha((0.15 * 255).round()),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AuraTheme.error.withAlpha((0.3 * 255).round()),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.stop_rounded,
                            size: 20,
                            color: AuraTheme.error,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'End',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AuraTheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Game Area
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: AuraTheme.shadowDark.withAlpha((0.2 * 255).round()),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Icon(
                        gameIcon,
                        size: 80,
                        color: AuraTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      widget.game['name'] ?? 'Game',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AuraTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Playing as ${widget.childName}',
                      style: TextStyle(
                        fontSize: 16,
                        color: AuraTheme.textDark.withAlpha((0.7 * 255).round()),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.8 * 255).round()),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '🚧 This game is coming soon!\nTap "End" to finish the session.',
                        style: TextStyle(
                          fontSize: 16,
                          color: AuraTheme.textMedium,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showGame ? _buildGame() : Container(
        color: AuraTheme.surfaceLight,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
