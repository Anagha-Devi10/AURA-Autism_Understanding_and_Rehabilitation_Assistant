import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';



class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  final TextEditingController _complaintsController = TextEditingController();
  final Map<String, String> _symptoms = {
    'Social Smile': 'No',
    'Attention': 'No',
    'Eye contact': 'No',
    'Sitting behavio': 'No',
    'Hyperactivity': 'No',
    'Echolalia': 'No',
    'Recognition of parents': 'No',
    'Excessive crying': 'No',
    'Restlessness': 'No',
    'Temper tantrums': 'No',
    'Self-injurious behaviour (when young)': 'No',
    'Head banging': 'No',
    'Vacant staring': 'No',
    'Self-muttering': 'No',
    'Stubborn': 'No',
    'Laziness': 'No'
  };

  bool _loading = false;
  List<String> _recommendations = [];

  Future<void> _getRecommendation() async {
  setState(() {
    _loading = true;
    _recommendations.clear();
  });

  final url = Uri.parse("http://10.144.63.247:5000/predict"); // web URL

  try {
    final response = await http
        .post(
          url,
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            "chief_complaints": _complaintsController.text,
            "symptoms": _symptoms,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final rec = data["recommended_therapy"] ?? data["recommended_therapies"];
      setState(() {
        _recommendations = List<String>.from(rec ?? []);
      });
    } else {
      setState(() {
        _recommendations = ["Error ${response.statusCode}: ${response.body}"];
      });
    }
  } catch (e) {
    // This will catch timeouts and any other errors
    setState(() {
      _recommendations = ["Error: $e"];
    });
    print("Exception during request: $e");
  } finally {
    setState(() {
      _loading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Therapist Assistant"),
        backgroundColor: const Color(0xFF16213e),
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chief Complaints Input
                  TextField(
                    controller: _complaintsController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Chief Complaints",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Symptoms Radio Buttons
                  ..._symptoms.keys.map((symptom) {
                    return Card(
                      color: Colors.white.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(symptom,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14)),
                            ),
                            Row(
                              children: [
                                Radio<String>(
                                  value: "Yes",
                                  groupValue: _symptoms[symptom],
                                  onChanged: (val) {
                                    setState(() {
                                      _symptoms[symptom] = val!;
                                    });
                                  },
                                ),
                                const Text("Yes",
                                    style: TextStyle(color: Colors.white)),
                                Radio<String>(
                                  value: "No",
                                  groupValue: _symptoms[symptom],
                                  onChanged: (val) {
                                    setState(() {
                                      _symptoms[symptom] = val!;
                                    });
                                  },
                                ),
                                const Text("No",
                                    style: TextStyle(color: Colors.white)),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 20),

                  // Submit Button
                  Center(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _getRecommendation,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 14),
                        backgroundColor: const Color(0xFF7B42F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text("Get Recommendation",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Results
                  if (_recommendations.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Recommended Therapies:",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ..._recommendations.map((therapy) => Card(
                              color: Colors.white.withOpacity(0.15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  therapy,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                              ),
                            )),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}