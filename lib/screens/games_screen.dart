/// AURA Games Screen
/// Grid of 8 therapy games

import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';
import '../widgets/neumorphic_widgets.dart';
import '../services/api_service.dart';
import 'game_detail_screen.dart';

class GamesScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedChild;

  const GamesScreen({
    super.key,
    this.selectedChild,
  });

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _games = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() => _isLoading = true);
    _games = await _api.getGames();
    setState(() => _isLoading = false);
  }

  void _openGame(Map<String, dynamic> game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameDetailScreen(
          game: game,
          selectedChild: widget.selectedChild,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Therapy Games'),
        backgroundColor: AuraTheme.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadGames,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.selectedChild != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            ChildAvatar(
                              name: widget.selectedChild!['name'],
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Playing as ${widget.selectedChild!['name']}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AuraTheme.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _games.length,
                        itemBuilder: (context, index) {
                          final game = _games[index];
                          return GameCard(
                            gameId: game['id'] ?? 'G${index + 1}',
                            name: game['name'] ?? 'Game ${index + 1}',
                            description: game['description'] ?? '',
                            therapyFocus: game['therapy_focus'] ?? 'Therapy',
                            onTap: () => _openGame(game),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
