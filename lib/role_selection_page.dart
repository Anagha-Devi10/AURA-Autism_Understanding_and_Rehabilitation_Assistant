import 'package:flutter/material.dart';
import 'parent/parent_login_page.dart';
import 'therapist/therapist_login_page.dart';
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final isMobile = width < 600;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Plain gradient background matching intro
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1a1a2e),
                      Color(0xFF16213e),
                      Color(0xFF0f0f23),
                    ],
                  ),
                ),
              ),

              // Top-right corner logo
              Positioned(
                top: isMobile ? 40 : 60,
                right: isMobile ? 24 : 50,
                child: Image.asset(
                  'assets/images/logo_j.png',
                  height: isMobile ? 50 : 70,
                  width: isMobile ? 50 : 70,
                ),
              ),

              // Main content
              SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 24 : width * 0.15,
                    vertical: isMobile ? 80 : 100,
                  ),
                  child: Column(
                    children: [
                      // Header section
                      Column(
                        children: [
                          // Main logo
                          Image.asset(
                            "assets/images/logo.png",
                            height: isMobile ? 80 : 120,
                            width: isMobile ? 80 : 120,
                          ),
                          SizedBox(height: isMobile ? 20 : 30),
                          
                          // App name with gradient
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFF7B42F6),
                                Color(0xFFB01EFF),
                                Color(0xFF42A5F5),
                              ],
                            ).createShader(bounds),
                            child: Text(
                              "AURA",
                              style: TextStyle(
                                fontSize: isMobile ? 32 : 42,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: isMobile ? 3 : 5,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                          
                          SizedBox(height: isMobile ? 8 : 12),
                          
                          // Subtitle
                          Text(
                            "Choose Your Role",
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                              fontFamily: 'Inter',
                            ),
                          ),
                          
                          SizedBox(height: isMobile ? 6 : 8),
                          
                          // Description
                          Text(
                            "Select your role to get personalized features",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w300,
                              color: Colors.white.withOpacity(0.7),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: isMobile ? 40 : 60),

                      // Role selection cards
                      _buildRoleCard(
                        context,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFFAD1457)],
                        ),
                        icon: Icons.favorite_rounded,
                        title: "Parent",
                        subtitle: "Access assessments and track your child's progress",
                        isMobile: isMobile,
                      ),
                      
                      SizedBox(height: isMobile ? 20 : 25),
                      
                      _buildRoleCard(
                        context,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                        ),
                        icon: Icons.psychology_rounded,
                        title: "Therapist",
                        subtitle: "Manage students and therapy sessions",
                        isMobile: isMobile,
                      ),
                      
                      SizedBox(height: isMobile ? 20 : 25),
                      
                      _buildRoleCard(
                        context,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
                        ),
                        icon: Icons.admin_panel_settings_rounded,
                        title: "Admin",
                        subtitle: "System administration and user management",
                        isMobile: isMobile,
                      ),

                      SizedBox(height: isMobile ? 40 : 50),

                      // Sign up link
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 20 : 30,
                            vertical: isMobile ? 12 : 15,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            "Need to register? Sign up",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context,
      {required LinearGradient gradient,
      required IconData icon,
      required String title,
      required String subtitle,
      required bool isMobile}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors[0].withOpacity(0.3),
            offset: const Offset(0, 8),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
           onTap: () {
    if (title == "Parent") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ParentLoginPage()),
      );
    }
    if (title == "Therapist") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TherapistLoginPage()),
      );
    }
    // Later you can add Therapist and Admin navigation similarly
  },
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 20 : 28),
            child: Row(
              children: [
                // Icon container
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isMobile ? 24 : 28,
                  ),
                ),
                
                SizedBox(width: isMobile ? 16 : 20),
                
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isMobile ? 18 : 22,
                          color: Colors.white,
                          fontFamily: 'Inter',
                        ),
                      ),
                      SizedBox(height: isMobile ? 4 : 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          color: Colors.white.withOpacity(0.9),
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.7),
                  size: isMobile ? 16 : 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}