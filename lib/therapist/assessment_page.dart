// assessment_page.dart
import 'package:flutter/material.dart';
import 'student_profiles_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AssessmentResult {
  final String id;
  final String studentId;
  final DateTime date;
  final Map<String, dynamic> answers;
  final int score;
  final String aiRecommendation; // placeholder for AI output

  AssessmentResult({required this.id, required this.studentId, required this.date, required this.answers, required this.score, required this.aiRecommendation});
}

class AssessmentPage extends StatefulWidget {
  const AssessmentPage({super.key});

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  // Q-CHAT 10 questions
  final List<String> _questions = [
    "Does your child look at you when you call their name?", // A1
    "Does your child point to ask for something?", // A2
    "Does your child point to share interest with you?", // A3
    "Does your child pretend play (e.g., pretend to drink from a cup, pretend to talk on the phone)?", // A4
    "Does your child imitate you (e.g., wave, clap, make faces)?", // A5
    "Does your child respond to your smile by smiling back?", // A6
    "Does your child show interest in other children?", // A7
    "Does your child bring objects to show you?", // A8
    "Does your child follow where you are looking?", // A9
    "Does your child make eye contact with you during interaction?", // A10
  ];
  final Map<int, int> _answers = {}; // index -> 0 (No) or 1 (Yes)

  // Additional required inputs
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _scoreController = TextEditingController();
  String? _sex;
  String? _ethnicity;
  String? _jaundice;
  String? _familyASD;
  String? _whoCompleted;

  bool _loading = false;
  String? _resultText;

  Future<void> _submitAssessment() async {
    if (_answers.length != _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Answer all questions')));
      return;
    }
    if (_ageController.text.isEmpty || _scoreController.text.isEmpty || _sex == null || _ethnicity == null || _jaundice == null || _familyASD == null || _whoCompleted == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all details')));
      return;
    }
    setState(() { _loading = true; _resultText = null; });
    // Prepare payload
    final Map<String, dynamic> payload = {
      for (int i = 0; i < _questions.length; i++) 'A${i+1}': _answers[i],
      'Age_Mons': int.tryParse(_ageController.text) ?? 0,
      'Qchat-10-Score': int.tryParse(_scoreController.text) ?? 0,
      'Sex': _sex,
      'Ethnicity': _ethnicity,
      'Jaundice': _jaundice,
      'Family_mem_with_ASD': _familyASD,
      'Who completed the test': _whoCompleted,
    };
    try {
      final uri = Uri.parse('http://localhost:5000/detect_autism');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (resp.statusCode == 200) {
        final result = jsonDecode(resp.body);
        setState(() {
          _loading = false;
          _resultText = 'Autism detected: ${result['autism_detected'] ? "Yes" : "No"}\nProbability: ${result['probability']?.toStringAsFixed(2) ?? "N/A"}';
        });
      } else {
        setState(() {
          _loading = false;
          _resultText = 'Error: ${resp.body}';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _resultText = 'Error submitting assessment: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autism Assessment (Q-CHAT 10)', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF16213e),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
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
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                const SizedBox(height: 12),
                ...List.generate(_questions.length, (idx) => Card(
                  color: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Q${idx+1}: ${_questions[idx]}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                      Row(children: [
                        Expanded(
                          child: RadioListTile<int>(
                            value: 1,
                            groupValue: _answers[idx],
                            title: const Text('Yes', style: TextStyle(color: Colors.white)),
                            onChanged: (v) => setState(() => _answers[idx] = v!),
                            activeColor: Color(0xFF7B42F6),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<int>(
                            value: 0,
                            groupValue: _answers[idx],
                            title: const Text('No', style: TextStyle(color: Colors.white)),
                            onChanged: (v) => setState(() => _answers[idx] = v!),
                            activeColor: Color(0xFF7B42F6),
                          ),
                        ),
                      ])
                    ]),
                  ),
                )),
                const SizedBox(height: 16),
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Age (months)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _scoreController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Qchat-10-Score',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _sex,
                  dropdownColor: const Color(0xFF1a1a2e),
                  items: ['M', 'F'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setState(() => _sex = v),
                  decoration: const InputDecoration(labelText: 'Sex', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _ethnicity,
                  dropdownColor: const Color(0xFF1a1a2e),
                  items: ['Asian', 'Black', 'White', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setState(() => _ethnicity = v),
                  decoration: const InputDecoration(labelText: 'Ethnicity', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _jaundice,
                  dropdownColor: const Color(0xFF1a1a2e),
                  items: ['yes', 'no'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setState(() => _jaundice = v),
                  decoration: const InputDecoration(labelText: 'Jaundice', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _familyASD,
                  dropdownColor: const Color(0xFF1a1a2e),
                  items: ['yes', 'no'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setState(() => _familyASD = v),
                  decoration: const InputDecoration(labelText: 'Family member with ASD', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _whoCompleted,
                  dropdownColor: const Color(0xFF1a1a2e),
                  items: ['Parent', 'Health worker', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setState(() => _whoCompleted = v),
                  decoration: const InputDecoration(labelText: 'Who completed the test', labelStyle: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _submitAssessment,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Submit Assessment', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                      backgroundColor: const Color(0xFF7B42F6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                if (_loading) const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
                if (_resultText != null) Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_resultText!, style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
