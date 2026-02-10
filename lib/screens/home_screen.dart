/// AURA Home Screen
/// Welcome screen with child selector and quick access to games

import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';
import '../widgets/neumorphic_widgets.dart';
import '../services/api_service.dart';
import 'games_screen.dart';
import 'progress_screen.dart';
import 'children_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _children = [];
  Map<String, dynamic>? _selectedChild;
  bool _isLoading = true;
  bool _isBackendOnline = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _isBackendOnline = await _api.checkHealth();
    if (_isBackendOnline) {
      _children = await _api.getChildren();
      if (_children.isNotEmpty && _selectedChild == null) {
        _selectedChild = _children.first;
      }
    }
    
    setState(() => _isLoading = false);
  }

  void _navigateToGames() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GamesScreen(
          selectedChild: _selectedChild,
        ),
      ),
    );
  }

  void _navigateToProgress() {
    if (_selectedChild != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProgressScreen(
            childId: _selectedChild!['id'],
            childName: _selectedChild!['name'],
          ),
        ),
      );
    }
  }

  void _navigateToChildren() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChildrenScreen(),
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildConnectionStatus(),
                    const SizedBox(height: 24),
                    _buildChildSelector(),
                    const SizedBox(height: 32),
                    _buildQuickActions(),
                    const SizedBox(height: 32),
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AuraTheme.accentCornflower, AuraTheme.primaryPastelBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AuraTheme.accentCornflower.withAlpha((0.4 * 255).round()),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AURA',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AuraTheme.textDark,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'Autism Understanding & Rehabilitation',
                style: TextStyle(
                  fontSize: 12,
                  color: AuraTheme.textMedium.withAlpha((0.8 * 255).round()),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    return NeumorphicCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isBackendOnline ? AuraTheme.success : AuraTheme.error,
              boxShadow: [
                BoxShadow(
                  color: (_isBackendOnline ? AuraTheme.success : AuraTheme.error).withAlpha((0.5 * 255).round()),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isBackendOnline ? 'Connected to AURA Server' : 'Offline Mode',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AuraTheme.textMedium,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadData,
            color: AuraTheme.textMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildChildSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Active Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AuraTheme.textDark,
              ),
            ),
            TextButton.icon(
              onPressed: _navigateToChildren,
              icon: const Icon(Icons.people_outline, size: 18),
              label: const Text('Manage'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_children.isEmpty)
          NeumorphicButton(
            onPressed: _navigateToChildren,
            height: 80,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: AuraTheme.accentCornflower),
                SizedBox(width: 12),
                Text(
                  'Add a Child Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AuraTheme.accentCornflower,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _children.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final child = _children[index];
                final isSelected = _selectedChild?['id'] == child['id'];
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedChild = child),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 140,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? AuraTheme.accentCornflower.withAlpha((0.2 * 255).round())
                        : AuraTheme.backgroundWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected 
                          ? AuraTheme.accentCornflower 
                          : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AuraTheme.shadowDark.withAlpha((0.15 * 255).round()),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChildAvatar(
                          name: child['name'],
                          size: 40,
                          backgroundColor: isSelected 
                            ? AuraTheme.accentCornflower 
                            : AuraTheme.textMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          child['name'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected 
                              ? AuraTheme.accentCornflower 
                              : AuraTheme.textDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AuraTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.games_rounded,
                title: 'Play Games',
                subtitle: '8 therapy games',
                color: AuraTheme.gameG1,
                onTap: _navigateToGames,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ActionCard(
                icon: Icons.insights_rounded,
                title: 'Progress',
                subtitle: 'View reports',
                color: AuraTheme.gameG6,
                onTap: _selectedChild != null ? _navigateToProgress : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About AURA',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AuraTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),
        NeumorphicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Therapy Games for Children',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AuraTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "AURA provides interactive games designed to help children develop essential skills.",
                style: TextStyle(
                  fontSize: 14,
                  color: AuraTheme.textMedium.withAlpha((0.9 * 255).round()),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _buildSkillItem(Icons.visibility, 'Eye Contact'),
              _buildSkillItem(Icons.record_voice_over, 'Speech & Hearing'),
              _buildSkillItem(Icons.touch_app, 'Fine Motor Skills'),
              _buildSkillItem(Icons.emoji_emotions, 'Emotional Awareness'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkillItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AuraTheme.accentCornflower),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AuraTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(20),
        decoration: neumorphicDecoration(
          color: color,
          radius: AuraTheme.radiusLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.7 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: AuraTheme.textDark),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AuraTheme.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AuraTheme.textMedium.withAlpha((0.8 * 255).round()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
