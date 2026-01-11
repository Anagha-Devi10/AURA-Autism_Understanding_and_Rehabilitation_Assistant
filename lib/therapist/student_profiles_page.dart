// student_profiles_page.dart
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class ApiConfig {
  static const String baseUrl = "http://localhost:5000";
}

class Student {
  String id;
  String name;
  int age;
  String guardian;
  String notes;

  Student({
    required this.id,
    required this.name,
    required this.age,
    required this.guardian,
    this.notes = '',
  });

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: json['id'] == null ? '' : json['id'].toString(),
    name: json['name'] ?? '',
    age: json['age'] is int ? json['age'] : int.tryParse(json['age']?.toString() ?? '') ?? 0,
    guardian: json['guardian'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': int.tryParse(id) ?? id,
    'name': name,
    'age': age,
    'guardian': guardian,
  };
}

class StudentProfilesPage extends StatefulWidget {
  final int therapistId;

  const StudentProfilesPage({
    super.key,
    required this.therapistId,
  });

  @override
  State<StudentProfilesPage> createState() => _StudentProfilesPageState();
}

class _StudentProfilesPageState extends State<StudentProfilesPage> {
  int get therapistId => widget.therapistId;
  
  // Key to refresh the FutureBuilder
  int _refreshKey = 0;

  // ---------- API CALLS ----------
  Future<List<Student>> _fetchStudents() async {
    try {
      final url = "${ApiConfig.baseUrl}/students/$therapistId";
      print("🔍 Fetching students from: $url");
      print("📋 Therapist ID: $therapistId");
      
      final res = await http.get(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
      );
      
      print("📡 Response status: ${res.statusCode}");
      print("📦 Response body: ${res.body}");
      
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        print("✅ Found ${data.length} students");
        return data.map((e) => Student(
          id: e["id"].toString(),
          name: e["name"],
          age: e["age"],
          guardian: e["guardian"],
          notes: e["notes"] ?? "",
        )).toList();
      } else {
        throw Exception('Server returned ${res.statusCode}: ${res.body}');
      }
    } on TimeoutException {
      throw Exception('Request timed out. Check backend or increase timeout.');
    } on http.ClientException catch (e) {
      throw Exception('ClientException: ${e.message}. Check network/CORS/backend.');
    } on SocketException {
      throw Exception('Network error. Is the backend running and reachable?');
    } catch (e) {
      print("❌ Error in _fetchStudents: $e");
      throw Exception('Error fetching students: $e');
    }
  }

  Future<void> _addStudent(Student s) async {
    try {
      await http.post(
        Uri.parse("${ApiConfig.baseUrl}/students"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "therapist_id": therapistId,
          "name": s.name,
          "age": s.age,
          "guardian": s.guardian,
          "notes": s.notes,
        }),
      );
      setState(() {
        _refreshKey++; // Force rebuild
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding student: $e')),
        );
      }
    }
  }

  Future<void> _updateStudent(Student s) async {
    try {
      await http.put(
        Uri.parse("${ApiConfig.baseUrl}/students/${s.id}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": s.name,
          "age": s.age,
          "guardian": s.guardian,
          "notes": s.notes,
        }),
      );
      setState(() {
        _refreshKey++;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating student: $e')),
        );
      }
    }
  }

  Future<void> _deleteStudent(String id) async {
    try {
      await http.delete(
        Uri.parse("${ApiConfig.baseUrl}/students/$id"),
      );
      setState(() {
        _refreshKey++;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting student: $e')),
        );
      }
    }
  }

  // --------------------------------

  void _openAddEdit({Student? student}) {
    final isEdit = student != null;
    final nameCtl = TextEditingController(text: student?.name ?? '');
    final ageCtl = TextEditingController(text: student?.age.toString() ?? '');
    final guardianCtl = TextEditingController(text: student?.guardian ?? '');
    final notesCtl = TextEditingController(text: student?.notes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEdit ? 'Edit Student' : 'Add Student',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: ageCtl,
              decoration: const InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: guardianCtl,
              decoration: const InputDecoration(labelText: 'Guardian'),
            ),
            TextField(
              controller: notesCtl,
              decoration: const InputDecoration(labelText: 'Notes'),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final name = nameCtl.text.trim();
                final age = int.tryParse(ageCtl.text.trim()) ?? 0;
                final guardian = guardianCtl.text.trim();
                final notes = notesCtl.text.trim();

                if (name.isEmpty || guardian.isEmpty || age <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill required fields')),
                  );
                  return;
                }

                if (isEdit) {
                  final updated = Student(
                    id: student!.id,
                    name: name,
                    age: age,
                    guardian: guardian,
                    notes: notes,
                  );
                  _updateStudent(updated);
                } else {
                  final newId = 's${Random().nextInt(100000)}';
                  final newStudent = Student(
                    id: newId,
                    name: name,
                    age: age,
                    guardian: guardian,
                    notes: notes,
                  );
                  _addStudent(newStudent);
                }
                Navigator.pop(context);
              },
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _openDetail(Student s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailPage(
          student: s,
          onDelete: () => _deleteStudent(s.id),
          onEdit: () => _openAddEdit(student: s),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profiles'),
      ),
      body: FutureBuilder<List<Student>>(
        key: ValueKey(_refreshKey), // Forces rebuild when key changes
        future: _fetchStudents(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snap.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _refreshKey++;
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(
              child: Text('No students yet. Add one using the + button.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final s = list[index];
              return ListTile(
                tileColor: Colors.white.withOpacity(0.04),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(s.name),
                subtitle: Text('Age: ${s.age} • Guardian: ${s.guardian}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _openDetail(s),
                onLongPress: () => _openAddEdit(student: s),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddEdit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class StudentDetailPage extends StatelessWidget {
  final Student student;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const StudentDetailPage({
    super.key,
    required this.student,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(student.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete student?'),
                  content: const Text('This will remove the student profile.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        onDelete();
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name: ${student.name}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text('Age: ${student.age}'),
            const SizedBox(height: 8),
            Text('Guardian: ${student.guardian}'),
            const SizedBox(height: 12),
            const Text(
              'Notes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(student.notes.isEmpty ? 'No notes.' : student.notes),
          ],
        ),
      ),
    );
  }
}