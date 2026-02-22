import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'aq_test_page.dart';
import 'video_upload_page.dart';
import 'parent_sessions_view.dart';
import '../screens/home_screen.dart';
import 'parent_progress_page.dart';

class ParentHomePage extends StatefulWidget {
  final int? studentId;
  final String? studentName;
  final int? parentId;

  const ParentHomePage({
    super.key,
    this.studentId,
    this.studentName,
    this.parentId,
  });

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  int? _studentId;
  String? _studentName;

  @override
  void initState() {
    super.initState();
    _studentId = widget.studentId;
    _studentName = widget.studentName;
    print('ParentHomePage: parentId=${widget.parentId}, studentId=$_studentId, studentName=$_studentName');
  }

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
                
                // Welcome Card
                if (_studentName != null) _buildWelcomeCard(),
                
                const SizedBox(height: 20),
                
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
                  "Choose an option below",
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
                        // Therapy Sessions Card
                        _buildOptionCard(
                          context,
                          icon: Icons.calendar_today_rounded,
                          title: "Therapy Sessions",
                          subtitle: "View upcoming & completed sessions",
                          colors: [const Color(0xFF00BCD4), const Color(0xFF0097A7)],
                          onTap: () => _navigateToSessions(context),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Progress Card
                        _buildOptionCard(
                          context,
                          icon: Icons.trending_up_rounded,
                          title: "View Progress",
                          subtitle: "Track your child's development",
                          colors: [const Color(0xFF4CAF50), const Color(0xFF2E7D32)],
                          onTap: () => _navigateToProgress(context),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // AQ Test Card
                        _buildOptionCard(
                          context,
                          icon: Icons.psychology_rounded,
                          title: "AQ Test",
                          subtitle: "For adolescents & adults",
                          colors: [const Color(0xFF2196F3), const Color(0xFF1565C0)],
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => const AqTestPage()),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Video Upload Card
                        _buildOptionCard(
                          context,
                          icon: Icons.videocam_rounded,
                          title: "Upload Video",
                          subtitle: "AI behaviour analysis",
                          colors: [const Color(0xFF9C27B0), const Color(0xFF6A1B9A)],
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (context) => VideoUploadPage(
                                studentId: _studentId,
                                studentName: _studentName,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Games Card
                        _buildOptionCard(
                          context,
                          icon: Icons.child_care_rounded,
                          title: "Games",
                          subtitle: "Interactive assessment games",
                          colors: [const Color(0xFFE91E63), const Color(0xFFAD1457)],
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (context) => HomeScreen(
                                studentId: _studentId,
                                studentName: _studentName,
                              ),
                            ),
                          ),
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
              (_studentName ?? 'C')[0].toUpperCase(),
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
                  _studentName ?? 'Your Child',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Keep up the great progress!',
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

  void _navigateToSessions(BuildContext context) {
    if (_studentId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ParentSessionsPage(
            studentId: _studentId!,
            studentName: _studentName ?? 'Your Child',
          ),
        ),
      );
    } else {
      _showNoStudentDialog(context);
    }
  }

  void _navigateToProgress(BuildContext context) {
    if (_studentId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ParentProgressPage(
            studentId: _studentId!,
            studentName: _studentName ?? 'Your Child',
          ),
        ),
      );
    } else {
      _showNoStudentDialog(context);
    }
  }

  void _showNoStudentDialog(BuildContext context) {
    final childNameController = TextEditingController();
    final childAgeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Add Your Child',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please enter your child\'s details to get started.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: childNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Child's Name",
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: childAgeController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Child's Age",
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B42F6),
            ),
            onPressed: () async {
              if (childNameController.text.isEmpty) return;
              
              try {
                final response = await http.post(
                  Uri.parse('http://localhost:5000/api/parents/${widget.parentId}/link_student'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'child_name': childNameController.text,
                    'child_age': int.tryParse(childAgeController.text) ?? 5,
                  }),
                );
                
                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);
                  setState(() {
                    _studentId = data['student_id'];
                    _studentName = data['student_name'];
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Child added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${response.body}')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Server error: $e')),
                );
              }
            },
            child: const Text('Add Child', style: TextStyle(color: Colors.white)),
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