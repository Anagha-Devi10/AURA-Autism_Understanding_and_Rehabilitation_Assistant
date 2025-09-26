import 'package:flutter/material.dart';
import 'qchat_test_page.dart';
import 'aq_test_page.dart';
import 'video_upload_page.dart';

class ParentHomePage extends StatelessWidget {
  const ParentHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Header
                const SizedBox(height: 40),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF7B42F6), Color(0xFFB01EFF), Color(0xFF42A5F5)],
                  ).createShader(bounds),
                  child: const Text(
                    "Parent Dashboard",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'Inter',
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Text(
                  "Choose an assessment for your child",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                    fontFamily: 'Inter',
                  ),
                ),
                
                const Spacer(),
                
                // Assessment Cards
                _buildOptionCard(
                  context,
                  icon: Icons.child_care_rounded,
                  title: "Q-CHAT Test",
                  subtitle: "For toddlers & children",
                  colors: [const Color(0xFFE91E63), const Color(0xFFAD1457)],
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QChatTestPage())),
                ),
                
                const SizedBox(height: 20),
                
                _buildOptionCard(
                  context,
                  icon: Icons.psychology_rounded,
                  title: "AQ Test",
                  subtitle: "For adolescents & adults",
                  colors: [const Color(0xFF2196F3), const Color(0xFF1565C0)],
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AqTestPage())),
                ),
                
                const SizedBox(height: 20),
                
                _buildOptionCard(
                  context,
                  icon: Icons.videocam_rounded,
                  title: "Upload Video",
                  subtitle: "AI behaviour analysis",
                  colors: [const Color(0xFF9C27B0), const Color(0xFF6A1B9A)],
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VideoUploadPage())),
                ),
                
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.3),
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.7),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}