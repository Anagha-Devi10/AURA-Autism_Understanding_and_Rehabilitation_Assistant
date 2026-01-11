// qchat_test_page.dart
import 'package:flutter/material.dart';

class QChatTestPage extends StatefulWidget {
  const QChatTestPage({super.key});

  @override
  State<QChatTestPage> createState() => _QChatTestPageState();
}

class _QChatTestPageState extends State<QChatTestPage> {
  final List<String> questions = [
    "Does your child look at you when you call their name?",
    "Does your child point to ask for something?",
    "Does your child point to share interest with you?",
    "Does your child pretend play (e.g., pretend to drink from a cup, pretend to talk on the phone)?",
    "Does your child imitate you (e.g., wave, clap, make faces)?",
    "Does your child respond to your smile by smiling back?",
    "Does your child show interest in other children?",
    "Does your child bring objects to show you?",
    "Does your child follow where you are looking?",
    "Does your child make eye contact with you during interaction?",
  ];

  List<int?> answers = List.filled(10, null);

  void _calculateScore() {
    int score = 0;

    // In Q-CHAT, "No" usually indicates risk (except some reversed items)
    for (int i = 0; i < answers.length; i++) {
      if (answers[i] != null) {
        if (answers[i] == 0) score++; // No = 1 risk point
      }
    }

    String result = score >= 3
        ? "There may be a chance of Autism Spectrum Disorder (ASD). Please seek professional evaluation."
        : "Lower likelihood of ASD, but continue monitoring development.";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1e1e2f),
        title: const Text("Q-CHAT Result", style: TextStyle(color: Colors.white)),
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
        title: const Text("Q-CHAT (Toddlers)"),
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
