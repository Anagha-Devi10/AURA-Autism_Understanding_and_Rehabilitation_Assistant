// qchat_test_page.dart
import 'package:flutter/material.dart';

class QChatTestPage extends StatelessWidget {
  const QChatTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Q-CHAT Test Page",
            style: TextStyle(color: Colors.white, fontSize: 24)),
      ),
      backgroundColor: Color(0xFF0f0f23),
    );
  }
}
