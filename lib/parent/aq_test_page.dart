// aq_test_page.dart
import 'package:flutter/material.dart';

class AqTestPage extends StatelessWidget {
  const AqTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("AQ Test Page",
            style: TextStyle(color: Colors.white, fontSize: 24)),
      ),
      backgroundColor: Color(0xFF0f0f23),
    );
  }
}
