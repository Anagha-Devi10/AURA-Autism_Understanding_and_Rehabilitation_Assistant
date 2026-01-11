// therapy_management_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'student_profiles_page.dart'; // import Student model or define a shared model
import 'dart:math';

class TherapyEntry {
  String id;
  String studentId;
  DateTime date;
  String summary;
  List<String> goals; // achieved/pending tracked elsewhere

  TherapyEntry({required this.id, required this.studentId, required this.date, required this.summary, this.goals = const []});
}

class TherapyManagementPage extends StatefulWidget {
  final int therapistId;
  const TherapyManagementPage({super.key, required this.therapistId});

  @override
  State<TherapyManagementPage> createState() => _TherapyManagementPageState();
}

class _TherapyManagementPageState extends State<TherapyManagementPage> {
  // MOCK data stores
  final List<Student> _students = [];

  final List<TherapyEntry> _entries = [];

  Student? _selectedStudent;
  static const String baseUrl = "http://localhost:5000"; // change if needed

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/students/${widget.therapistId}'));
      if (resp.statusCode == 200) {
        final List<dynamic> body = json.decode(resp.body);
        setState(() {
          _students.clear();
          _students.addAll(body.map((j) => Student.fromJson(j)).toList());
          if (_students.isNotEmpty && _selectedStudent == null) {
            _selectedStudent = _students.first;
          }
        });
      } else {
        // handle non-200 as needed (log or show SnackBar)
      }
    } catch (e) {
      // handle network error
    }
  }
  List<TherapyEntry> _entriesForStudent(String id) {
    return _entries.where((e) => e.studentId == id).toList()..sort((a,b)=>b.date.compareTo(a.date));
  }

  void _addEntry(String studentId, String summary, List<String> goals) {
    final id = 't${Random().nextInt(100000)}';
    final ent = TherapyEntry(id: id, studentId: studentId, date: DateTime.now(), summary: summary, goals: goals);
    setState(() => _entries.add(ent));
    // TODO: Firestore add
  }

  void _openAddEntry() {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a student first')));
      return;
    }

    final summaryCtl = TextEditingController();
    final goalsCtl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Add Daily Summary for ${_selectedStudent!.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: summaryCtl, decoration: const InputDecoration(labelText: 'Summary'), minLines: 2, maxLines: 5),
            TextField(controller: goalsCtl, decoration: const InputDecoration(labelText: 'Goals (comma separated)')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () {
              final summary = summaryCtl.text.trim();
              final goals = goalsCtl.text.trim().split(',').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList();
              if (summary.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter summary')));
                return;
              }
              _addEntry(_selectedStudent!.id, summary, goals);
              Navigator.pop(context);
            }, child: const Text('Save')),
          ]),
        ),
      ),
    );
  }

  // Simple mocked weekly aggregation: count entries in last 7 days & goals summary
  Map<String, dynamic> _weeklyReport(String studentId) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = _entries.where((e) => e.studentId == studentId && e.date.isAfter(cutoff)).toList();
    final total = recent.length;
    final achieved = recent.expand((e)=>e.goals).length; // mock measure
    return {'entries': total, 'goalsTracked': achieved};
  }

  @override
  Widget build(BuildContext context) {
    final students = _students;
    final selectedEntries = _selectedStudent != null ? _entriesForStudent(_selectedStudent!.id) : [];

    return Scaffold(
      appBar: AppBar(title: const Text('Therapy Management')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          DropdownButtonFormField<Student>(
            value: _selectedStudent,
            hint: const Text('Select student'),
            items: students.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
            onChanged: (v) => setState(() => _selectedStudent = v),
          ),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton.icon(onPressed: _openAddEntry, icon: const Icon(Icons.add), label: const Text('Add Daily Summary')),
            const SizedBox(width: 12),
            ElevatedButton.icon(onPressed: () {
              if (_selectedStudent == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select student'))); return; }
              final report = _weeklyReport(_selectedStudent!.id);
              showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('Weekly Report (mock)'),
                content: Text('Entries this week: ${report['entries']}\nGoals tracked: ${report['goalsTracked']}'),
                actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('OK'))],
              ));
            }, icon: const Icon(Icons.analytics), label: const Text('Weekly Report')),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedStudent == null
                ? const Center(child: Text('Select a student to view therapy entries.'))
                : selectedEntries.isEmpty
                    ? const Center(child: Text('No therapy entries yet for this student.'))
                    : ListView.separated(
                        itemCount: selectedEntries.length,
                        separatorBuilder: (_,__) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final e = selectedEntries[idx];
                          return Card(
                            color: Colors.white.withOpacity(0.04),
                            child: ListTile(
                              title: Text(e.summary),
                              subtitle: Text('On ${e.date.toLocal().toString().split(' ').first} • Goals: ${e.goals.join(', ')}'),
                            ),
                          );
                        },
                      ),
          )
        ]),
      ),
    );
  }
}
