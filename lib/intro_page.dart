import 'package:flutter/material.dart';
import 'role_selection_page.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

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
              // Plain gradient background
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

              // Top-right corner logo (company logo)
              Positioned(
                top: isMobile ? 40 : 60,
                right: isMobile ? 24 : 50,
                child: Image.asset(
                  'assets/images/logo_j.png',
                  height: isMobile ? 60 : 80,
                  width: isMobile ? 60 : 80,
                ),
              ),

              // Main content container
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 32 : 64,
                    vertical: isMobile ? 40 : 60,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Main logo - clean and simple
                      Image.asset(
                        'assets/images/logo.png',
                        height: isMobile ? 120 : 180,
                        width: isMobile ? 120 : 180,
                      ),

                      SizedBox(height: isMobile ? 30 : 40),

                      // App name with enhanced typography
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
                            fontSize: isMobile ? 48 : 70,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: isMobile ? 4 : 8,
                            fontFamily: 'Inter', // Modern, clean font
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: isMobile ? 16 : 24),

                      // Subtitle with better styling
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 32,
                          vertical: isMobile ? 12 : 16,
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
                          "Autism Understanding & Rehabilitation Assistant",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 22,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.95),
                            letterSpacing: 1.5,
                            fontFamily: 'Inter',
                            height: 1.4,
                          ),
                        ),
                      ),

                      SizedBox(height: isMobile ? 20 : 30),

                      // Feature highlights
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFeatureChip("AI-Powered", isMobile),
                          _buildFeatureChip("Personalized", isMobile),
                          _buildFeatureChip("Supportive", isMobile),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Enhanced Get Started button
              Positioned(
                bottom: isMobile ? 40 : 60,
                left: isMobile ? width * 0.08 : width * 0.25,
                right: isMobile ? width * 0.08 : width * 0.25,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Encouraging text above button
                    Text(
                      "Begin your journey to understanding",
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withOpacity(0.8),
                        fontFamily: 'Inter',
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 20),
                    
                    // Main CTA button
                    SizedBox(
                      width: double.infinity,
                      height: isMobile ? 60 : 70,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(35),
                          ),
                          elevation: 12,
                          shadowColor: const Color(0xFF7B42F6).withOpacity(0.6),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  const RoleSelectionPage(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 300),
                            ),
                          );
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF7B42F6),
                                Color(0xFFB01EFF),
                                Color(0xFF42A5F5),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(35),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7B42F6).withOpacity(0.3),
                                offset: const Offset(0, 8),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Get Started",
                                  style: TextStyle(
                                    fontSize: isMobile ? 18 : 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontFamily: 'Inter',
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(width: isMobile ? 8 : 12),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: isMobile ? 20 : 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeatureChip(String text, bool isMobile) {
    return Text(
      text,
      style: TextStyle(
        fontSize: isMobile ? 14 : 16,
        fontWeight: FontWeight.w500,
        color: Colors.white.withOpacity(0.8),
        fontFamily: 'Inter',
        letterSpacing: 0.5,
      ),
    );
  }
}