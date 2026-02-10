/// Sound Match Game - Pronunciation Training
/// Children see letters/words, pronounce them, parents verify correctness

import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';

class SoundMatchGame extends StatefulWidget {
  final Function(int score, int eyeContact, int motor) onGameComplete;

  const SoundMatchGame({
    super.key,
    required this.onGameComplete,
  });

  @override
  State<SoundMatchGame> createState() => _SoundMatchGameState();
}

class _SoundMatchGameState extends State<SoundMatchGame>
    with TickerProviderStateMixin {
  int _currentRound = 0;
  int _score = 0;
  int _correctAnswers = 0;
  final int _totalRounds = 10;
  bool _showFeedback = false;
  bool _isCorrect = false;
  int _currentMode = 0; // 0 = Letters, 1 = Words, 2 = Mixed

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  // Letters with phonetic hints
  final List<PronunciationItem> _letters = [
    PronunciationItem(text: 'A', hint: 'Say "Aah" like in Apple 🍎', color: const Color(0xFFFF6B6B)),
    PronunciationItem(text: 'B', hint: 'Say "Buh" like in Ball ⚽', color: const Color(0xFFFFB347)),
    PronunciationItem(text: 'C', hint: 'Say "Kuh" like in Cat 🐱', color: const Color(0xFF87CEEB)),
    PronunciationItem(text: 'D', hint: 'Say "Duh" like in Dog 🐕', color: const Color(0xFF98D8C8)),
    PronunciationItem(text: 'E', hint: 'Say "Eh" like in Egg 🥚', color: const Color(0xFFDDA0DD)),
    PronunciationItem(text: 'F', hint: 'Say "Fuh" like in Fish 🐟', color: const Color(0xFFFFE066)),
    PronunciationItem(text: 'G', hint: 'Say "Guh" like in Goat 🐐', color: const Color(0xFF98D8C8)),
    PronunciationItem(text: 'H', hint: 'Say "Huh" like in Hat 🎩', color: const Color(0xFFFF6B6B)),
    PronunciationItem(text: 'I', hint: 'Say "Ih" like in Igloo 🏔️', color: const Color(0xFF87CEEB)),
    PronunciationItem(text: 'J', hint: 'Say "Juh" like in Jam 🍯', color: const Color(0xFFFFB347)),
    PronunciationItem(text: 'K', hint: 'Say "Kuh" like in Kite 🪁', color: const Color(0xFFDDA0DD)),
    PronunciationItem(text: 'L', hint: 'Say "Luh" like in Lion 🦁', color: const Color(0xFFFFE066)),
    PronunciationItem(text: 'M', hint: 'Say "Muh" like in Moon 🌙', color: const Color(0xFF98D8C8)),
    PronunciationItem(text: 'N', hint: 'Say "Nuh" like in Nest 🪹', color: const Color(0xFFFF6B6B)),
    PronunciationItem(text: 'O', hint: 'Say "Oh" like in Orange 🍊', color: const Color(0xFFFFB347)),
    PronunciationItem(text: 'P', hint: 'Say "Puh" like in Pig 🐷', color: const Color(0xFFDDA0DD)),
    PronunciationItem(text: 'Q', hint: 'Say "Kwuh" like in Queen 👑', color: const Color(0xFF87CEEB)),
    PronunciationItem(text: 'R', hint: 'Say "Ruh" like in Rain 🌧️', color: const Color(0xFF98D8C8)),
    PronunciationItem(text: 'S', hint: 'Say "Sss" like in Sun ☀️', color: const Color(0xFFFFE066)),
    PronunciationItem(text: 'T', hint: 'Say "Tuh" like in Tree 🌳', color: const Color(0xFF98D8C8)),
    PronunciationItem(text: 'U', hint: 'Say "Uh" like in Umbrella ☂️', color: const Color(0xFF87CEEB)),
    PronunciationItem(text: 'V', hint: 'Say "Vuh" like in Van 🚐', color: const Color(0xFFFF6B6B)),
    PronunciationItem(text: 'W', hint: 'Say "Wuh" like in Water 💧', color: const Color(0xFFDDA0DD)),
    PronunciationItem(text: 'X', hint: 'Say "Ks" like in Box 📦', color: const Color(0xFFFFB347)),
    PronunciationItem(text: 'Y', hint: 'Say "Yuh" like in Yellow 💛', color: const Color(0xFFFFE066)),
    PronunciationItem(text: 'Z', hint: 'Say "Zz" like in Zebra 🦓', color: const Color(0xFF98D8C8)),
  ];

  // Simple words for pronunciation
  final List<PronunciationItem> _words = [
    PronunciationItem(text: 'CAT', hint: 'Say "K-A-T" 🐱', color: const Color(0xFFFF6B6B)),
    PronunciationItem(text: 'DOG', hint: 'Say "D-O-G" 🐕', color: const Color(0xFFFFB347)),
    PronunciationItem(text: 'SUN', hint: 'Say "S-U-N" ☀️', color: const Color(0xFFFFE066)),
    PronunciationItem(text: 'MOM', hint: 'Say "M-O-M" 👩', color: const Color(0xFFDDA0DD)),
    PronunciationItem(text: 'DAD', hint: 'Say "D-A-D" 👨', color: const Color(0xFF87CEEB)),
    PronunciationItem(text: 'BUS', hint: 'Say "B-U-S" 🚌', color: const Color(0xFF98D8C8)),
    PronunciationItem(text: 'CUP', hint: 'Say "C-U-P" ☕', color: const Color(0xFFFF6B6B)),
    PronunciationItem(text: 'HAT', hint: 'Say "H-A-T" 🎩', color: const Color(0xFFFFB347)),
    PronunciationItem(text: 'BIG', hint: 'Say "B-I-G" 🐘', color: const Color(0xFF98D8C8)),
    PronunciationItem(text: 'RED', hint: 'Say "R-E-D" ❤️', color: const Color(0xFFFF6B6B)),
    PronunciationItem(text: 'BEE', hint: 'Say "B-E-E" 🐝', color: const Color(0xFFFFE066)),
    PronunciationItem(text: 'TOP', hint: 'Say "T-O-P" 🔝', color: const Color(0xFF87CEEB)),
    PronunciationItem(text: 'BOX', hint: 'Say "B-O-X" 📦', color: const Color(0xFFDDA0DD)),
    PronunciationItem(text: 'PEN', hint: 'Say "P-E-N" ✏️', color: const Color(0xFF98D8C8)),
    PronunciationItem(text: 'TOY', hint: 'Say "T-O-Y" 🧸', color: const Color(0xFFFFB347)),
  ];

  late PronunciationItem _currentItem;
  late List<PronunciationItem> _availableItems;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _setupItems();
    _selectNextItem();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _setupItems() {
    switch (_currentMode) {
      case 0:
        _availableItems = List.from(_letters);
        break;
      case 1:
        _availableItems = List.from(_words);
        break;
      case 2:
        _availableItems = [..._letters, ..._words];
        break;
    }
    _availableItems.shuffle();
  }

  void _selectNextItem() {
    if (_availableItems.isEmpty) {
      _setupItems();
    }
    _currentItem = _availableItems.removeAt(0);
    _bounceController.forward(from: 0);
  }

  void _onParentResponse(bool isCorrect) {
    if (_showFeedback) return;

    setState(() {
      _showFeedback = true;
      _isCorrect = isCorrect;
      if (isCorrect) {
        _score += 10;
        _correctAnswers++;
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showFeedback = false;
          _currentRound++;

          if (_currentRound >= _totalRounds) {
            _endGame();
          } else {
            _selectNextItem();
          }
        });
      }
    });
  }

  void _endGame() {
    final speechScore = ((_correctAnswers / _totalRounds) * 100).round();
    widget.onGameComplete(_score, speechScore, speechScore);
  }

  void _changeMode(int mode) {
    setState(() {
      _currentMode = mode;
      _currentRound = 0;
      _score = 0;
      _correctAnswers = 0;
      _setupItems();
      _selectNextItem();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AuraTheme.gameG2,
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
                  // Mode Selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(200),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeButton('Letters', 0),
                        _buildModeButton('Words', 1),
                        _buildModeButton('Mixed', 2),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress and Score
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(220),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Round ${_currentRound + 1}/$_totalRounds',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AuraTheme.textDark),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(220),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars, color: Colors.amber, size: 24),
                            const SizedBox(width: 6),
                            Text('$_score', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AuraTheme.textDark)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _currentRound / _totalRounds,
                      minHeight: 10,
                      backgroundColor: Colors.white.withAlpha(150),
                      valueColor: AlwaysStoppedAnimation<Color>(_currentItem.color),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Instruction
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(200),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic, color: _currentItem.color, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Say this out loud!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AuraTheme.textDark),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Main Display Card
                  ScaleTransition(
                    scale: _bounceAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: _currentItem.color, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: _currentItem.color.withAlpha(80),
                            blurRadius: 25,
                            spreadRadius: 5,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // The Letter/Word
                          Text(
                            _currentItem.text,
                            style: TextStyle(
                              fontSize: _currentItem.text.length == 1 ? 120 : 72,
                              fontWeight: FontWeight.bold,
                              color: _currentItem.color,
                              letterSpacing: _currentItem.text.length > 1 ? 8 : 0,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Phonetic Hint
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _currentItem.color.withAlpha(30),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              _currentItem.hint,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: _currentItem.color.withAlpha(200),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Feedback Display
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _showFeedback ? 80 : 0,
                    child: _showFeedback
                        ? Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                              decoration: BoxDecoration(
                                color: _isCorrect ? AuraTheme.success : const Color(0xFFFFB347),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isCorrect ? AuraTheme.success : const Color(0xFFFFB347)).withAlpha(100),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isCorrect ? Icons.celebration : Icons.refresh,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isCorrect ? 'Excellent! +10 ⭐' : 'Good try! Keep going!',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 30),

                  // Parent Section Label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AuraTheme.textDark.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.family_restroom, color: AuraTheme.textMedium, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Parent: Did they say it correctly?',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AuraTheme.textMedium),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Parent Verification Buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _onParentResponse(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4CAF50).withAlpha(100),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white, size: 40),
                                SizedBox(height: 8),
                                Text(
                                  'Correct!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _onParentResponse(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFB347), Color(0xFFFFCC80)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFB347).withAlpha(100),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.refresh, color: Colors.white, size: 40),
                                SizedBox(height: 8),
                                Text(
                                  'Try Again',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, int mode) {
    final isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () => _changeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _currentItem.color : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AuraTheme.textMedium,
          ),
        ),
      ),
    );
  }
}

class PronunciationItem {
  final String text;
  final String hint;
  final Color color;

  PronunciationItem({required this.text, required this.hint, required this.color});
}
