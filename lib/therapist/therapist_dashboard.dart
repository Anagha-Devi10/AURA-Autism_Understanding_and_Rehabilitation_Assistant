// Therapist Dashboard Page

import 'package:flutter/material.dart';
import 'recommendation_page.dart';

// Import existing pages
import 'student_profiles_page.dart';
import 'pages/dashboard_page.dart';

// Import new pages
import 'sessions_page.dart';
import 'unreviewed_assesments_page.dart';

class TherapistDashboard extends StatelessWidget {
  final String? therapistId;
  final String? therapistName;
  
  const TherapistDashboard({
    super.key, 
    this.therapistId,
    this.therapistName,
  });

  int get _therapistIdInt => therapistId != null ? (int.tryParse(therapistId!) ?? 0) : 0;

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
                const SizedBox(height: 20),
                
                // Welcome Card (optional - shows if therapistName is provided)
                if (therapistName != null) ...[
                  _buildWelcomeCard(),
                  const SizedBox(height: 20),
                ],
                
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
                
                const SizedBox(height: 30),
                
                // Scrollable Options
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // NEW: Therapy Sessions Card
                        _buildOptionCard(
                          context,
                          icon: Icons.calendar_today_rounded,
                          title: "Therapy Sessions",
                          subtitle: "Schedule, manage & complete sessions",
                          colors: [const Color(0xFF00BCD4), const Color(0xFF0097A7)],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TherapySessionsPage(
                                  therapistId: _therapistIdInt,
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // NEW: Review Assessments Card
                        _buildOptionCard(
                          context,
                          icon: Icons.rate_review_rounded,
                          title: "Review Assessments",
                          subtitle: "Review & assign therapy sessions",
                          colors: [const Color(0xFFFF5722), const Color(0xFFE64A19)],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UnreviewedAssessmentsPage(
                                  therapistId: _therapistIdInt,
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // EXISTING: Student Profiles Card
                        _buildOptionCard(
                          context,
                          icon: Icons.people_rounded,
                          title: "Student Profiles",
                          subtitle: "View and manage student information",
                          colors: [const Color(0xFFE91E63), const Color(0xFFAD1457)],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentProfilesPage(
                                  therapistId: _therapistIdInt,
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // EXISTING: Therapy Management (DashboardPage)
                        _buildOptionCard(
                          context,
                          icon: Icons.healing_rounded,
                          title: "Therapy Management",
                          subtitle: "Schedule and track therapy sessions",
                          colors: [const Color(0xFF2196F3), const Color(0xFF1565C0)],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DashboardPage(
                                  therapistId: _therapistIdInt,
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // EXISTING: Therapist Assistant Card
                        _buildOptionCard(
                          context,
                          icon: Icons.smart_toy_rounded,
                          title: "Therapist Assistant",
                          subtitle: "AI-powered therapy recommendations",
                          colors: [const Color(0xFFFF9800), const Color(0xFFE65100)],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RecommendationPage(),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF7B42F6).withOpacity(0.3),
            child: Text(
              (therapistName ?? 'T')[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${therapistName ?? 'Therapist'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Have a productive day!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
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
