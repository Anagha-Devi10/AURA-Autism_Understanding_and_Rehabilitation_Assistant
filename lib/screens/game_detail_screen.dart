/// AURA Game Detail Screen
/// Shows game instructions and allows starting a session

import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';
import '../widgets/neumorphic_widgets.dart';
import '../services/api_service.dart';
import 'active_game_screen.dart';

class GameDetailScreen extends StatelessWidget {
  final Map<String, dynamic> game;
  final Map<String, dynamic>? selectedChild;

  const GameDetailScreen({
    super.key,
    required this.game,
    this.selectedChild,
  });

  void _startGame(BuildContext context) async {
    if (selectedChild == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a child profile first'),
          backgroundColor: AuraTheme.warning,
        ),
      );
      return;
    }

    final api = ApiService();
    final result = await api.startGame(
      game['id'],
      selectedChild!['id'],
    );

    if (result != null && result['session'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveGameScreen(
            game: game,
            session: result['session'],
            childName: selectedChild!['name'],
          ),
        ),
      );
    } else {
      // Start in offline mode
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveGameScreen(
            game: game,
            session: {'id': 0, 'status': 'offline'},
            childName: selectedChild?['name'] ?? 'Guest',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameId = game['id'] ?? 'G1';
    final gameColor = AuraTheme.getGameColor(gameId);
    final gameIcon = AuraTheme.getGameIcon(gameId);
    final instructions = List<String>.from(game['instructions'] ?? []);

    return Scaffold(
      backgroundColor: gameColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 20,
                        color: AuraTheme.textDark,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Game Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AuraTheme.shadowDark.withAlpha((0.2 * 255).round()),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        gameIcon,
                        size: 60,
                        color: AuraTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Game Name
                    Text(
                      game['name'] ?? 'Game',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AuraTheme.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Therapy Focus
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.7 * 255).round()),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        game['therapy_focus'] ?? 'Therapy',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AuraTheme.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Description
                    Text(
                      game['description'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: AuraTheme.textDark.withAlpha((0.8 * 255).round()),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Instructions Card
                    if (instructions.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AuraTheme.shadowDark.withAlpha((0.15 * 255).round()),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: AuraTheme.accentCornflower,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'How to Play',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AuraTheme.textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ...instructions.asMap().entries.map((entry) {
                              final index = entry.key;
                              final instruction = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: gameColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AuraTheme.textDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        instruction,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: AuraTheme.textMedium,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Start Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: NeumorphicButton(
                onPressed: () => _startGame(context),
                color: Colors.white,
                height: 64,
                borderRadius: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 28,
                      color: AuraTheme.success,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Start Game',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AuraTheme.textDark,
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
}