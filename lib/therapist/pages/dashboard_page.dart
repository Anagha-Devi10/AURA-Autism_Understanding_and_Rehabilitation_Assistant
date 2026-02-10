import 'package:flutter/material.dart';
import 'child_detail_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DashboardPage extends StatefulWidget {
  final int? therapistId;
  const DashboardPage({super.key, this.therapistId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class Student {
  final int id;
  final String name;
  final int? age;
  final String? guardian;
  final String? notes;

  Student({
    required this.id,
    required this.name,
    this.age,
    this.guardian,
    this.notes,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      age: json['age'],
      guardian: json['guardian'],
      notes: json['notes'],
    );
  }
}

class _DashboardPageState extends State<DashboardPage> {
  List<Student> students = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      String url;
      if (widget.therapistId != null) {
        // Use the direct MySQL endpoint for therapist's students
        url = 'http://localhost:5000/students/${widget.therapistId}';
      } else {
        url = 'http://localhost:5000/api/students';
      }

      print('Fetching students from: $url');

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        
        List<dynamic> studentList;
        
        // Handle different response formats
        if (data is List) {
          // Direct list response (from /students/<therapist_id>)
          studentList = data;
        } else if (data is Map) {
          // Object response (from /api/students)
          studentList = data['students'] ?? data['children'] ?? [];
        } else {
          studentList = [];
        }

        setState(() {
          students = studentList
              .map((json) => Student.fromJson(json as Map<String, dynamic>))
              .toList();
          isLoading = false;
        });
        
        print('Loaded ${students.length} students');
      } else {
        setState(() {
          errorMessage = 'Failed to load students (${response.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching students: $e');
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: const Text('My Students'),
        backgroundColor: const Color(0xFF16213e),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStudents,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.purple),
            )
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _fetchStudents,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                )
              : students.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          const Text(
                            "No students assigned yet",
                            style:
                                TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Therapist ID: ${widget.therapistId ?? 'Not set'}",
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchStudents,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: students.length,
                        itemBuilder: (context, index) {
                          final student = students[index];
                          return _buildStudentCard(student);
                        },
                      ),
                    ),
    );
  }

  Widget _buildStudentCard(Student student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.purple.withOpacity(0.2),
          child: Text(
            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.purple,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (student.age != null)
                Text(
                  'Age: ${student.age}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              if (student.guardian != null && student.guardian!.isNotEmpty)
                Text(
                  'Guardian: ${student.guardian}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChildDetailPage(
                childName: student.name,
                id: student.id,
                therapistId: widget.therapistId,
              ),
            ),
          );
        },
      ),
    );
  }
}
