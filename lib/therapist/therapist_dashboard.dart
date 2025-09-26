import 'package:flutter/material.dart';
import 'recommendation_page.dart';

class TherapistDashboard extends StatelessWidget {
  const TherapistDashboard({super.key});

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
                    "Therapist Dashboard",
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
                  "Manage your students and therapy sessions",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                    fontFamily: 'Inter',
                  ),
                ),
                
                const Spacer(),
                
                // Management Cards
                _buildOptionCard(
                  context,
                  icon: Icons.people_rounded,
                  title: "Student Profiles",
                  subtitle: "View and manage student information",
                  colors: [const Color(0xFFE91E63), const Color(0xFFAD1457)],
                  onTap: () {
                    // TODO: Navigate to student profiles
                  },
                ),
                
                const SizedBox(height: 20),
                
                _buildOptionCard(
                  context,
                  icon: Icons.healing_rounded,
                  title: "Therapy Management",
                  subtitle: "Schedule and track therapy sessions",
                  colors: [const Color(0xFF2196F3), const Color(0xFF1565C0)],
                  onTap: () {
                    // TODO: Navigate to therapy management
                  },
                ),
                
                const SizedBox(height: 20),
                
                _buildOptionCard(
                  context,
                  icon: Icons.assessment_rounded,
                  title: "Assessments & Recommendations",
                  subtitle: "Review test results and create plans",
                  colors: [const Color(0xFF9C27B0), const Color(0xFF6A1B9A)],
                  onTap: () {
                    // TODO: Navigate to assessments
                  },
                ),
                
                const SizedBox(height: 20),
                
                _buildOptionCard(
                  context,
                  icon: Icons.smart_toy_rounded,
                  title: "Therapist Assistant",
                  subtitle: "AI-powered therapy recommendations",
                  colors: [const Color(0xFFFF9800), const Color(0xFFE65100)],
                  onTap: () {
                    // TODO: Navigate to AI assistant
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecommendationPage(),
                      ),
                    );
                  },
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