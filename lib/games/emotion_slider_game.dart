/// Emotion Slider Game
/// Emotional Awareness Training - Match emotions to faces

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';

class EmotionSliderGame extends StatefulWidget {
  final Function(int score, int eyeContact, int motor) onGameComplete;

  const EmotionSliderGame({
    super.key,
    required this.onGameComplete,
  });

  @override
  State<EmotionSliderGame> createState() => _EmotionSliderGameState();
}

class _EmotionSliderGameState extends State<EmotionSliderGame>
    with SingleTickerProviderStateMixin {
  final Random _random = Random();
  int _currentRound = 0;
  int _score = 0;
  int _correctAnswers = 0;
  final int _totalRounds = 10;
  bool _showFeedback = false;
  bool _isCorrect = false;
  late AnimationController _feedbackController;
  late Animation<double> _scaleAnimation;

  // Emotion data with icons instead of emojis for web compatibility
  final List<EmotionData> _emotions = [
    EmotionData(
      name: 'Happy',
      icon: Icons.sentiment_very_satisfied,
      color: const Color(0xFFFFE066),
    ),
    EmotionData(
      name: 'Sad',
      icon: Icons.sentiment_very_dissatisfied,
      color: const Color(0xFF87CEEB),
    ),
    EmotionData(
      name: 'Angry',
      icon: Icons.mood_bad,
      color: const Color(0xFFFF6B6B),
    ),
    EmotionData(
      name: 'Surprised',
      icon: Icons.sentiment_satisfied_alt,
      color: const Color(0xFFDDA0DD),
    ),
    EmotionData(
      name: 'Scared',
      icon: Icons.sentiment_neutral,
      color: const Color(0xFF98D8C8),
    ),
    EmotionData(
      name: 'Sleepy',
      icon: Icons.bedtime,
      color: const Color(0xFFB0C4DE),
    ),
  ];

  late EmotionData _currentEmotion;
  late List<EmotionData> _choices;

  @override
  void initState() {
    super.initState();
    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _feedbackController, curve: Curves.elasticOut),
    );
    _generateRound();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _generateRound() {
    // Pick a random emotion for this round
    _currentEmotion = _emotions[_random.nextInt(_emotions.length)];

    // Generate 3 choices including the correct one
    final otherEmotions = _emotions
        .where((e) => e.name != _currentEmotion.name)
        .toList()
      ..shuffle();

    _choices = [_currentEmotion, ...otherEmotions.take(2)]..shuffle();
  }

  void _selectAnswer(EmotionData selected) {
    if (_showFeedback) return;

    final correct = selected.name == _currentEmotion.name;

    setState(() {
      _showFeedback = true;
      _isCorrect = correct;
      if (correct) {
        _score += 10;
        _correctAnswers++;
        _feedbackController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _feedbackController.reset();
        setState(() {
          _showFeedback = false;
          _currentRound++;

          if (_currentRound >= _totalRounds) {
            _endGame();
          } else {
            _generateRound();
          }
        });
      }
    });
  }

  void _endGame() {
    final eyeContactScore = ((_correctAnswers / _totalRounds) * 100).round();
    final motorScore = eyeContactScore;
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
            AuraTheme.gameG6,
            const Color(0xFFFFF0F5),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Progress and Score
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Progress
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
                        'Round ${_currentRound + 1}/$_totalRounds',
                        style: const TextStyle(
                          fontSize: 16,
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

                // Progress Bar
                const SizedBox(height: 16),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(150),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (_currentRound + 1) / _totalRounds,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AuraTheme.accentCornflower,
                            AuraTheme.success,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Question
                const Text(
                  'How does this face feel?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AuraTheme.textDark,
                  ),
                ),
                const SizedBox(height: 30),

                // Large Face Icon
                ScaleTransition(
                  scale: _isCorrect ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: _showFeedback
                          ? (_isCorrect
                              ? AuraTheme.success.withAlpha(50)
                              : AuraTheme.error.withAlpha(50))
                          : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _currentEmotion.color.withAlpha(150),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                      border: Border.all(
                        color: _showFeedback
                            ? (_isCorrect ? AuraTheme.success : AuraTheme.error)
                            : _currentEmotion.color,
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _currentEmotion.icon,
                        size: 100,
                        color: _currentEmotion.color,
                      ),
                    ),
                  ),
                ),
                
                // Show emotion name hint
                const SizedBox(height: 16),
                Text(
                  '?',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AuraTheme.textMedium.withAlpha(100),
                  ),
                ),

                // Feedback Message
                if (_showFeedback)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _isCorrect
                            ? AuraTheme.success.withAlpha(220)
                            : AuraTheme.error.withAlpha(220),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isCorrect ? Icons.check_circle : Icons.cancel,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isCorrect 
                                ? 'Correct! It\'s ${_currentEmotion.name}!' 
                                : 'Try again!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 40),

                // Answer Choices
                const Text(
                  'Tap the matching emotion:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AuraTheme.textMedium,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _choices.map((emotion) {
                    final isSelected = _showFeedback &&
                        emotion.name == _currentEmotion.name;
                    
                    return GestureDetector(
                      onTap: () => _selectAnswer(emotion),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 100,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AuraTheme.success.withAlpha(50)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AuraTheme.success
                                : emotion.color,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: emotion.color.withAlpha(80),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              emotion.icon,
                              size: 40,
                              color: emotion.color,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              emotion.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AuraTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmotionData {
  final String name;
  final IconData icon;
  final Color color;

  EmotionData({
    required this.name,
    required this.icon,
    required this.color,
  });
}
