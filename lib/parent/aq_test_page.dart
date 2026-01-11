// aq_test_page.dart
import 'package:flutter/material.dart';

class AqTestPage extends StatefulWidget {
  const AqTestPage({super.key});

  @override
  State<AqTestPage> createState() => _AqTestPageState();
}

class _AqTestPageState extends State<AqTestPage> {
  // Parent-oriented AQ-10 questions
  final List<String> questions = [
    "Does your child often notice small sounds that others do not?",
    "Does your child usually focus on details rather than the bigger picture?",
    "Does your child find it easy to do more than one thing at once?",
    "If there is an interruption, does your child find it easy to return to what they were doing?",
    "Does your child find it easy to understand implied meanings in conversations (e.g., jokes, sarcasm)?",
    "Can your child usually tell if someone is bored while talking to them?",
    "When reading or listening to a story, does your child struggle to understand what the characters are thinking or intending?",
    "Does your child enjoy collecting information about categories of things (e.g., cars, trains, animals)?",
    "Can your child easily understand how someone is feeling by looking at their face?",
    "Can your child easily understand how someone is feeling just by listening to their voice?"
  ];

  List<int?> answers = List.filled(10, null);

  // Reverse-scored question indices
  List<int> reverseScored = [2, 3, 4, 5, 6, 9, 10];

  void _calculateScore() {
    int score = 0;

    for (int i = 0; i < answers.length; i++) {
      if (answers[i] != null) {
        if (reverseScored.contains(i + 1)) {
          if (answers[i] == 0) score++; // "No" = 1 point
        } else {
          if (answers[i] == 1) score++; // "Yes" = 1 point
        }
      }
    }

    String result = score >= 6
        ? "There is a chance your child may have Autism Spectrum Disorder (ASD). Please consult a specialist for a detailed evaluation."
        : "It is less likely that your child has ASD, but professional consultation is recommended if you have concerns.";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1e1e2f),
        title: const Text("AQ-10 Test Result", style: TextStyle(color: Colors.white)),
        content: Text(
          "Score: $score / 10\n\n$result",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text("OK", style: TextStyle(color: Colors.blueAccent)),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        title: const Text("AQ-10 Parent Test"),
        backgroundColor: const Color(0xFF1e1e2f),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          return Card(
            color: const Color(0xFF1e1e2f),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(questions[index],
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<int>(
                          value: 1,
                          groupValue: answers[index],
                          activeColor: Colors.blueAccent,
                          title: const Text("Yes", style: TextStyle(color: Colors.white70)),
                          onChanged: (val) {
                            setState(() {
                              answers[index] = val;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<int>(
                          value: 0,
                          groupValue: answers[index],
                          activeColor: Colors.blueAccent,
                          title: const Text("No", style: TextStyle(color: Colors.white70)),
                          onChanged: (val) {
                            setState(() {
                              answers[index] = val;
                            });
                          },
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (answers.contains(null)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please answer all questions.")),
            );
          } else {
            _calculateScore();
          }
        },
        label: const Text("Submit"),
        icon: const Icon(Icons.check),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
