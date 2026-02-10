/// AURA Progress Screen
/// Shows therapy progress and session history

import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';
import '../widgets/neumorphic_widgets.dart';
import '../services/api_service.dart';

class ProgressScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const ProgressScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _progressData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    _progressData = await _api.getProgress(widget.childId);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraTheme.surfaceLight,
      appBar: AppBar(
        title: Text('${widget.childName}\'s Progress'),
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
              onRefresh: _loadProgress,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(),
                    const SizedBox(height: 24),
                    _buildScoresSection(),
                    const SizedBox(height: 24),
                    _buildRecentSessions(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    final progress = _progressData?['progress'] ?? {};
    final totalSessions = progress['total_sessions'] ?? 0;
    final avgOverall = (progress['avg_overall'] ?? 0).toDouble();
    final favoriteGame = progress['favorite_game'] ?? 'None yet';

    return NeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChildAvatar(name: widget.childName, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.childName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AuraTheme.textDark,
                      ),
                    ),
                    Text(
                      '$totalSessions therapy sessions',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AuraTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'Overall',
                  value: '${avgOverall.toStringAsFixed(0)}%',
                  color: AuraTheme.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: 'Sessions',
                  value: '$totalSessions',
                  color: AuraTheme.accentCornflower,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  label: 'Favorite',
                  value: favoriteGame.toString().split(' ').first,
                  color: AuraTheme.gameG6,
                  isText: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoresSection() {
    final progress = _progressData?['progress'] ?? {};
    final eyeContact = (progress['avg_eye_contact'] ?? 0).toDouble();
    final speech = (progress['avg_speech'] ?? 0).toDouble();
    final motor = (progress['avg_motor'] ?? 0).toDouble();

    return NeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Therapy Scores',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AuraTheme.textDark,
            ),
          ),
          const SizedBox(height: 24),
          _buildScoreBar('Eye Contact', eyeContact, AuraTheme.gameG1, Icons.visibility),
          const SizedBox(height: 16),
          _buildScoreBar('Speech', speech, AuraTheme.gameG2, Icons.record_voice_over),
          const SizedBox(height: 16),
          _buildScoreBar('Motor Skills', motor, AuraTheme.gameG3, Icons.touch_app),
        ],
      ),
    );
  }

  Widget _buildScoreBar(String label, double value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AuraTheme.textDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AuraTheme.textMedium,
                        ),
                      ),
                      Text(
                        '${value.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _getProgressColor(value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: color.withAlpha((0.3 * 255).round()),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (value / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getProgressColor(value),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getProgressColor(double value) {
    if (value >= 70) return AuraTheme.success;
    if (value >= 40) return AuraTheme.warning;
    return AuraTheme.error;
  }

  Widget _buildRecentSessions() {
    final sessions = List<Map<String, dynamic>>.from(
      _progressData?['recent_sessions'] ?? [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Sessions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AuraTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),
        if (sessions.isEmpty)
          NeumorphicCard(
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    size: 48,
                    color: AuraTheme.textLight.withAlpha((0.5 * 255).round()),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No sessions yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: AuraTheme.textMedium,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Play some games to see progress!',
                    style: TextStyle(
                      fontSize: 12,
                      color: AuraTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...sessions.take(5).map((session) => _buildSessionCard(session)),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final gameName = session['game_name'] ?? 'Game';
    final gameId = session['game_id'] ?? 'G1';
    final overallScore = session['overall_score'] ?? 0;
    final startTime = session['start_time'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeumorphicCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AuraTheme.getGameColor(gameId),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                AuraTheme.getGameIcon(gameId),
                color: AuraTheme.textDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AuraTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(startTime),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AuraTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getProgressColor(overallScore.toDouble()).withAlpha((0.15 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$overallScore%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _getProgressColor(overallScore.toDouble()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return 'Today';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return isoDate;
    }
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isText;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    this.isText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: isText ? 14 : 22,
              fontWeight: FontWeight.w800,
              color: color.withAlpha((0.9 * 255).round()),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color.withAlpha((0.7 * 255).round()),
            ),
          ),
        ],
      ),
    );
  }
}
