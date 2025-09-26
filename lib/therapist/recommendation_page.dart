/*
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  final TextEditingController _chiefComplaintController = TextEditingController();
  final Map<String, String> _symptomAnswers = {};

  final List<String> symptoms = [
    'Social Smile',
    'Attention',
    'Eye contact',
    'Sitting behavior',
    'Hyperactivity',
    'Echolalia',
    'Recognition of parents',
    'Excessive crying',
    'Restlessness',
    'Temper tantrums',
    'Self-injurious behaviour (when young)',
    'Head banging',
    'Vacant staring',
    'Self-muttering',
    'Stubborn',
    'Laziness',
  ];

  bool _loading = false;
  String? _result;

  Future<void> _submitData() async {
    setState(() {
      _loading = true;
      _result = null;
    });

    final url = Uri.parse("http://127.0.0.1:5000/predict"); // Change to your backend API
    final body = {
      "chief_complaints": _chiefComplaintController.text,
      "symptoms": _symptomAnswers,
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _result = "Prediction: ${data['prediction']}\nRecommendation: ${data['recommendation']}";
        });
      } else {
        setState(() {
          _result = "Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _result = "Failed to connect to backend: $e";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildRadioOption(String symptom) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(symptom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Row(
              children: [
                Radio<String>(
                  value: "Yes",
                  groupValue: _symptomAnswers[symptom],
                  onChanged: (value) {
                    setState(() {
                      _symptomAnswers[symptom] = value!;
                    });
                  },
                ),
                const Text("Yes"),
                Radio<String>(
                  value: "No",
                  groupValue: _symptomAnswers[symptom],
                  onChanged: (value) {
                    setState(() {
                      _symptomAnswers[symptom] = value!;
                    });
                  },
                ),
                const Text("No"),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Therapist Assistant"),
        backgroundColor: const Color(0xFF1a1a2e),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Chief Complaints", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _chiefComplaintController,
                maxLines: 2,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  hintText: "Enter chief complaints...",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),

              const Text("Symptoms", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              ...symptoms.map((s) => _buildRadioOption(s)).toList(),

              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _loading ? null : _submitData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B42F6),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Get Recommendation", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              if (_result != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_result!, style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
*/
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    'Sitting behavior': 'No',
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
    'Laziness': 'No',
  };

  bool _loading = false;
  List<String> _recommendations = [];

  Future<void> _getRecommendation() async {
    setState(() {
      _loading = true;
      _recommendations.clear();
    });

    final url = Uri.parse("http://127.0.0.1:5000/predict"); // Change when deploying
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "chief_complaints": _complaintsController.text,
        "symptoms": _symptoms,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      setState(() {
        if (data["recommended_therapy"] != null) {
          _recommendations = [data["recommended_therapy"]];
        } else if (data["recommended_therapies"] != null) {
          _recommendations = List<String>.from(data["recommended_therapies"]);
        }
      });
    } else {
      setState(() {
        _recommendations = ["Error fetching recommendation"];
      });
    }

    setState(() {
      _loading = false;
    });
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