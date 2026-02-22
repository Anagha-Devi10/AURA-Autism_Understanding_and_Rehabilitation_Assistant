import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'analysis_result.dart';
import 'video_upload_io.dart'
    if (dart.library.html) 'video_upload_web.dart' as platform;

class VideoUploadPage extends StatefulWidget {
  final int? studentId;
  final String? studentName;
  
  const VideoUploadPage({super.key, this.studentId, this.studentName});

  @override
  State<VideoUploadPage> createState() => _VideoUploadPageState();
}

class _VideoUploadPageState extends State<VideoUploadPage> {
  // Page controller for step navigation
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Video related
  VideoPlayerController? _controller;
  PlatformFile? _selectedFile;
  bool _videoReady = false;

  // Q-CHAT 10 Questions
  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Does your child look at you when you call their name?',
      'icon': Icons.record_voice_over,
    },
    {
      'question': 'Is it easy for you to get eye contact with your child?',
      'icon': Icons.visibility,
    },
    {
      'question': 'Does your child point to indicate that they want something?',
      'icon': Icons.touch_app,
    },
    {
      'question': 'Does your child point to share interest with you (e.g., pointing at an interesting sight)?',
      'icon': Icons.share,
    },
    {
      'question': 'Does your child pretend play (e.g., care for dolls, talk on a toy phone)?',
      'icon': Icons.toys,
    },
    {
      'question': 'Does your child follow where you\'re looking?',
      'icon': Icons.remove_red_eye,
    },
    {
      'question': 'If you or someone else in the family is visibly upset, does your child show signs of wanting to comfort them?',
      'icon': Icons.favorite,
    },
    {
      'question': 'Would you describe your child\'s first words as:',
      'icon': Icons.chat_bubble,
      'options': ['Typical', 'Unusual', 'No words yet'],
    },
    {
      'question': 'Does your child use simple gestures (e.g., wave goodbye)?',
      'icon': Icons.waving_hand,
    },
    {
      'question': 'Does your child stare at nothing with no apparent purpose?',
      'icon': Icons.blur_on,
      'reversed': true, // "Yes" indicates risk
    },
  ];

  final Map<int, int> _answers = {}; // index -> 0 (No/Risk) or 1 (Yes/Typical)

  // Demographics
  final TextEditingController _ageController = TextEditingController();
  String _sex = 'M';
  String _jaundice = 'no';
  String _familyASD = 'no';

  // Results
  bool _isAnalyzing = false;
  AnalysisResult? _realResult;
  Map<String, dynamic>? _combinedResult;
  String? _errorMessage;

  @override
  void dispose() {
    _controller?.dispose();
    _pageController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null) {
      _selectedFile = result.files.first;

      if (kIsWeb) {
        Uint8List bytes = result.files.first.bytes!;
        platform.createVideoControllerFromBytes(bytes).then((controller) {
          setState(() {
            _controller = controller;
            _controller!.play();
            _videoReady = true;
          });
        });
      } else {
        setState(() {
          _videoReady = true;
        });
      }
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      if (_validateCurrentStep()) {
        setState(() => _currentStep++);
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (!_videoReady) {
          _showSnackBar('Please upload a video first');
          return false;
        }
        return true;
      case 1:
        if (_answers.length < _questions.length) {
          _showSnackBar('Please answer all ${_questions.length} questions');
          return false;
        }
        return true;
      case 2:
        if (_ageController.text.isEmpty) {
          _showSnackBar('Please enter your child\'s age in months');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Replace the _calculateQchatScore method and _submitCombinedAssessment method:

  int _calculateQchatScore() {
    int score = 0;
    for (int index = 0; index < _questions.length; index++) {
      if (!_answers.containsKey(index)) continue;
      
      int answer = _answers[index]!;
      bool isReversed = _questions[index]['reversed'] == true;
      bool hasOptions = _questions[index]['options'] != null;
      
      if (hasOptions) {
        // Question 8 (index 7): "Typical" = 0 risk, "Unusual"/"No words" = 1 risk
        // answer: 0 = Typical (no risk), 1 = Unusual (risk), 2 = No words (risk)
        if (answer > 0) score++;
      } else if (isReversed) {
        // For reversed questions (Q10), "Yes" (1) indicates risk
        if (answer == 1) score++;
      } else {
        // For normal questions, "No" (0) indicates risk
        if (answer == 0) score++;
      }
    }
    return score;
  }

  Future<void> _submitCombinedAssessment() async {
    if (!_validateCurrentStep()) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _combinedResult = null;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:5000/api/combined_assessment'),
      );

      // Add video file
      if (_selectedFile != null) {
        if (kIsWeb) {
          request.files.add(http.MultipartFile.fromBytes(
            'video',
            _selectedFile!.bytes!,
            filename: _selectedFile!.name,
          ));
        } else {
          request.files.add(await http.MultipartFile.fromPath(
            'video',
            _selectedFile!.path!,
          ));
        }
      }

      // Prepare questionnaire data with correct format for MLP model
      Map<String, dynamic> questionnaire = {};
      
      // Map answers to A1-A10 format
      // The MLP expects: 0 = indicates ASD trait, 1 = typical behavior
      for (int i = 0; i < _questions.length; i++) {
        int answer = _answers[i] ?? 1; // Default to typical if not answered
        bool isReversed = _questions[i]['reversed'] == true;
        bool hasOptions = _questions[i]['options'] != null;
        
        if (hasOptions) {
          // Q8 (index 7): Typical=1, Unusual/No words=0
          questionnaire['A${i + 1}'] = answer == 0 ? 1 : 0;
        } else if (isReversed) {
          // Q10 (index 9): Yes=0 (risk), No=1 (typical)
          questionnaire['A${i + 1}'] = answer == 1 ? 0 : 1;
        } else {
          // Normal questions: Yes=1 (typical), No=0 (risk)
          questionnaire['A${i + 1}'] = answer;
        }
      }
      
      // Calculate Q-CHAT score (0-10, higher = more risk indicators)
      int qchatScore = _calculateQchatScore();
      
      questionnaire['Age_Mons'] = int.tryParse(_ageController.text) ?? 24;
      questionnaire['Qchat-10-Score'] = qchatScore;
      questionnaire['Sex'] = _sex == 'M' ? 'm' : 'f'; // lowercase for consistency
      questionnaire['Ethnicity'] = 'Others';
      questionnaire['Jaundice'] = _jaundice;
      questionnaire['Family_mem_with_ASD'] = _familyASD;
      questionnaire['Who completed the test'] = 'family member';

      print(' Questionnaire data: $questionnaire');
      print(' Q-CHAT Score: $qchatScore / 10');

      request.fields['questionnaire'] = jsonEncode(questionnaire);

      // Send request
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw Exception('Request timed out. Please try again.');
        },
      );
      var response = await http.Response.fromStream(streamedResponse);

      print(' Response status: ${response.statusCode}');
      print(' Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _combinedResult = data;
          _realResult = _parseResult(data);
          _isAnalyzing = false;
          _currentStep = 3;
        });
        _pageController.animateToPage(
          3,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print(' Error: $e');
      setState(() {
        _errorMessage = 'Analysis failed: $e';
        _isAnalyzing = false;
      });
      _showSnackBar('Analysis failed. Please try again.');
    }
  }

  AnalysisResult _parseResult(Map<String, dynamic> data) {
    final assessment = data['assessment'] ?? {};
    final ensemble = data['results']?['ensemble_result'] ?? {};

    return AnalysisResult(
      riskLevel: assessment['risk_level'] ?? 'Unknown',
      confidenceScore: (ensemble['confidence'] ?? 0.5).toDouble(),
      summary: assessment['summary'] ?? 'Analysis complete.',
      details: List<String>.from(assessment['details'] ?? []),
      recommendation: assessment['recommendation'] ?? 'Consult a specialist.',
      asdRelated: assessment['asd_related'] == true,
    );
  }

  Future<void> _saveResultsToBackend() async {
    if (_combinedResult == null) {
      _showSnackBar('No results to save');
      return;
    }

    if (widget.studentId == null) {
      _showSnackBar('No student linked. Please add your child from the dashboard first.');
      return;
    }

    try {
      final ensemble = _combinedResult!['results']?['ensemble_result'] ?? {};
      final videoResult = _combinedResult!['results']?['video_result'] ?? {};
      final questionnaireResult = _combinedResult!['results']?['questionnaire_result'] ?? {};
      final assessment = _combinedResult!['assessment'] ?? {};

      final double? combinedScore = (ensemble['asd_probability'] as num?)?.toDouble();
      final double? videoScore = (videoResult['asd_probability'] as num?)?.toDouble();
      final double? videoConfidence = (videoResult['confidence'] as num?)?.toDouble();
      final String? videoPrediction = videoResult['prediction'];
      final double? questionnaireScore = (questionnaireResult['asd_probability'] as num?)?.toDouble();

      // Determine risk level
      String combinedRisk = 'Low';
      if (combinedScore != null) {
        if (combinedScore >= 0.7) {
          combinedRisk = 'High';
        } else if (combinedScore >= 0.4) {
          combinedRisk = 'Medium';
        }
      }

      String questionnaireRisk = 'Low';
      if (questionnaireScore != null) {
        if (questionnaireScore >= 0.7) {
          questionnaireRisk = 'High';
        } else if (questionnaireScore >= 0.4) {
          questionnaireRisk = 'Medium';
        }
      }

      final response = await http.post(
        Uri.parse('http://localhost:5000/api/assessments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': widget.studentId,
          'video_score': videoScore,
          'video_prediction': videoPrediction,
          'video_confidence': videoConfidence,
          'questionnaire_score': questionnaireScore,
          'questionnaire_risk': questionnaireRisk,
          'combined_score': combinedScore,
          'combined_risk_level': combinedRisk,
          'recommendation': assessment['recommendation'] ?? '',
        }),
      );

      if (response.statusCode == 201) {
        _showSnackBar('Assessment saved successfully! ✓');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Results saved! Your therapist will review them soon.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        _showSnackBar('Failed to save: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showSnackBar('Error saving results: $e');
    }
  }

  void _resetAssessment() {
    setState(() {
      _currentStep = 0;
      _controller?.dispose();
      _controller = null;
      _selectedFile = null;
      _videoReady = false;
      _answers.clear();
      _ageController.clear();
      _sex = 'M';
      _jaundice = 'no';
      _familyASD = 'no';
      _combinedResult = null;
      _realResult = null;
      _errorMessage = null;
    });
    _pageController.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f23),
      appBar: AppBar(
        title: const Text("Child Assessment"),
        backgroundColor: const Color(0xFF1e1e2f),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress Indicator
          _buildProgressIndicator(),

          // Page Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildVideoStep(),
                _buildQuestionsStep(),
                _buildDemographicsStep(),
                _buildResultsStep(),
              ],
            ),
          ),

          // Navigation Buttons
          if (_currentStep < 3) _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = ['Video', 'Questions', 'Details', 'Results'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1e1e2f),
      child: Row(
        children: List.generate(steps.length, (index) {
          bool isCompleted = index < _currentStep;
          bool isCurrent = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? Colors.greenAccent
                              : isCurrent
                                  ? Colors.blueAccent
                                  : Colors.grey.shade700,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, color: Colors.black, size: 16)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isCurrent ? Colors.white : Colors.white54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[index],
                        style: TextStyle(
                          color: isCurrent ? Colors.white : Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 20,
                    height: 2,
                    color: isCompleted ? Colors.greenAccent : Colors.grey.shade700,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVideoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.videocam_rounded,
            size: 60,
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 16),
          const Text(
            'Upload a Video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Record a 1-2 minute video of your child during play or interaction. Our AI will analyze behavioral patterns.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Video upload area
          GestureDetector(
            onTap: _pickVideo,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1e1e2f),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _videoReady ? Colors.greenAccent : Colors.blueAccent,
                  width: 2,
                ),
              ),
              child: _videoReady
                  ? Stack(
                      children: [
                        Center(
                          child: _controller != null && _controller!.value.isInitialized
                              ? AspectRatio(
                                  aspectRatio: _controller!.value.aspectRatio,
                                  child: VideoPlayer(_controller!),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 48),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedFile?.name ?? 'Video selected',
                                      style: const TextStyle(color: Colors.white70),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _controller?.dispose();
                                _controller = null;
                                _selectedFile = null;
                                _videoReady = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload, size: 48, color: Colors.blueAccent),
                        SizedBox(height: 12),
                        Text(
                          'Tap to select video',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'MP4, AVI, MOV supported',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Text('Tips for a good video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 8),
                Text('• Record during natural play time', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text('• Ensure good lighting', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text('• Include face and body in frame', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text('• 1-2 minutes is ideal', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Q-CHAT 10 Screening',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_answers.length}/${_questions.length}',
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final q = _questions[index];
              final bool hasOptions = q['options'] != null;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1e1e2f),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _answers.containsKey(index)
                        ? Colors.greenAccent.withOpacity(0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(q['icon'] as IconData, color: Colors.blueAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Question ${index + 1}',
                                style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                q['question'] as String,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (hasOptions)
                      // Special question with custom options (Q8)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate((q['options'] as List).length, (optIndex) {
                          final option = q['options'][optIndex];
                          final isSelected = _answers[index] == optIndex;
                          return GestureDetector(
                            onTap: () => setState(() => _answers[index] = optIndex),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (optIndex == 0 
                                        ? Colors.greenAccent.withOpacity(0.3)
                                        : Colors.orangeAccent.withOpacity(0.3))
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected 
                                      ? (optIndex == 0 ? Colors.greenAccent : Colors.orangeAccent)
                                      : Colors.white24,
                                ),
                              ),
                              child: Text(
                                option,
                                style: TextStyle(
                                  color: isSelected 
                                      ? (optIndex == 0 ? Colors.greenAccent : Colors.orangeAccent)
                                      : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }),
                      )
                    else
                      // Yes/No buttons
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _answers[index] = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _answers[index] == 1
                                      ? Colors.greenAccent.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _answers[index] == 1 ? Colors.greenAccent : Colors.white24,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: _answers[index] == 1 ? Colors.greenAccent : Colors.white54,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Yes',
                                      style: TextStyle(
                                        color: _answers[index] == 1 ? Colors.greenAccent : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _answers[index] = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _answers[index] == 0
                                      ? Colors.redAccent.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _answers[index] == 0 ? Colors.redAccent : Colors.white24,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cancel,
                                      color: _answers[index] == 0 ? Colors.redAccent : Colors.white54,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'No',
                                      style: TextStyle(
                                        color: _answers[index] == 0 ? Colors.redAccent : Colors.white70,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDemographicsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Icon(Icons.child_care, size: 60, color: Colors.blueAccent),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Child Information',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'This helps us provide more accurate analysis',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),

          // Age
          const Text('Age (in months)', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g., 24 for 2 years old',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.cake, color: Colors.blueAccent),
              filled: true,
              fillColor: const Color(0xFF1e1e2f),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Sex
          const Text('Sex', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _sex = 'M'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _sex == 'M' ? Colors.blueAccent.withOpacity(0.2) : const Color(0xFF1e1e2f),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _sex == 'M' ? Colors.blueAccent : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.male, color: _sex == 'M' ? Colors.blueAccent : Colors.white54),
                        const SizedBox(width: 8),
                        Text('Male', style: TextStyle(color: _sex == 'M' ? Colors.blueAccent : Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _sex = 'F'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _sex == 'F' ? Colors.pinkAccent.withOpacity(0.2) : const Color(0xFF1e1e2f),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _sex == 'F' ? Colors.pinkAccent : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.female, color: _sex == 'F' ? Colors.pinkAccent : Colors.white54),
                        const SizedBox(width: 8),
                        Text('Female', style: TextStyle(color: _sex == 'F' ? Colors.pinkAccent : Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Jaundice
          const Text('Did your child have jaundice at birth?', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          _buildYesNoSelector('jaundice', _jaundice, (v) => setState(() => _jaundice = v)),
          const SizedBox(height: 20),

          // Family ASD
          const Text('Does anyone in the family have ASD?', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          _buildYesNoSelector('familyASD', _familyASD, (v) => setState(() => _familyASD = v)),

          const SizedBox(height: 32),

          // Q-CHAT Score Preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.assessment, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Q-CHAT Score', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      '${_calculateQchatScore()} / 10',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildYesNoSelector(String key, String value, Function(String) onChanged) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged('yes'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: value == 'yes' ? Colors.greenAccent.withOpacity(0.2) : const Color(0xFF1e1e2f),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: value == 'yes' ? Colors.greenAccent : Colors.transparent),
              ),
              child: Center(
                child: Text('Yes', style: TextStyle(color: value == 'yes' ? Colors.greenAccent : Colors.white70)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged('no'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: value == 'no' ? Colors.blueAccent.withOpacity(0.2) : const Color(0xFF1e1e2f),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: value == 'no' ? Colors.blueAccent : Colors.transparent),
              ),
              child: Center(
                child: Text('No', style: TextStyle(color: value == 'no' ? Colors.blueAccent : Colors.white70)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsStep() {
    if (_isAnalyzing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blueAccent),
            SizedBox(height: 20),
            Text('Analyzing video and responses...', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('This may take a moment', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    if (_realResult == null) {
      return const Center(
        child: Text('No results available', style: TextStyle(color: Colors.white54)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Main Result Card
          ResultDisplayWidget(result: _realResult!),

          const SizedBox(height: 24),

          // Individual Scores
          if (_combinedResult != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1e1e2f),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Analysis Breakdown',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Q-CHAT Score Display
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.quiz, color: Colors.blueAccent, size: 24),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Q-CHAT 10 Score',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              '${_calculateQchatScore()} / 10',
                              style: TextStyle(
                                color: _calculateQchatScore() >= 4 
                                    ? Colors.orangeAccent 
                                    : Colors.greenAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _calculateQchatScore() >= 4 
                                ? Colors.orangeAccent.withOpacity(0.2)
                                : Colors.greenAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _calculateQchatScore() >= 4 ? 'Above Threshold' : 'Below Threshold',
                            style: TextStyle(
                              color: _calculateQchatScore() >= 4 
                                  ? Colors.orangeAccent 
                                  : Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  _buildScoreRow(
                    'Video Analysis',
                    _combinedResult!['results']?['video_result']?['asd_probability'],
                    Icons.videocam,
                  ),
                  const SizedBox(height: 12),
                  _buildScoreRow(
                    'Questionnaire',
                    _combinedResult!['results']?['questionnaire_result']?['asd_probability'],
                    Icons.assignment,
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  _buildScoreRow(
                    'Combined Score',
                    _combinedResult!['results']?['ensemble_result']?['asd_probability'],
                    Icons.assessment,
                    highlight: true,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetAssessment,
                  icon: const Icon(Icons.refresh),
                  label: const Text('New Assessment'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveResultsToBackend,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Results'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, double? probability, IconData icon, {bool highlight = false}) {
    final prob = probability ?? 0.0;
    final percentage = (prob * 100).toStringAsFixed(1);

    return Row(
      children: [
        Icon(icon, color: highlight ? Colors.blueAccent : Colors.white54, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: highlight ? Colors.white : Colors.white70,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getColorForProbability(prob).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$percentage%',
            style: TextStyle(
              color: _getColorForProbability(prob),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Color _getColorForProbability(double prob) {
    if (prob >= 0.7) return Colors.redAccent;
    if (prob >= 0.4) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1e1e2f),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isAnalyzing
                  ? null
                  : () {
                      if (_currentStep == 2) {
                        _submitCombinedAssessment();
                      } else {
                        _nextStep();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isAnalyzing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(_currentStep == 2 ? 'Analyze Now' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

// Keep the ResultDisplayWidget class
class ResultDisplayWidget extends StatelessWidget {
  final AnalysisResult result;

  const ResultDisplayWidget({super.key, required this.result});

  Color _getRiskColor() {
    switch (result.riskLevel) {
      case 'High Risk':
        return Colors.redAccent;
      case 'Moderate Risk':
        return Colors.orangeAccent;
      case 'Low-Moderate Risk':
        return Colors.amber;
      case 'Low Risk':
        return Colors.greenAccent;
      default:
        return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _getRiskColor();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1e1e2f),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Risk Level Header
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: riskColor, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    result.riskLevel.contains('High')
                        ? Icons.warning_amber
                        : result.riskLevel.contains('Low')
                            ? Icons.check_circle
                            : Icons.info,
                    color: riskColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    result.riskLevel.toUpperCase(),
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Confidence Score
          Center(
            child: Text(
              "Confidence: ${(result.confidenceScore * 100).toStringAsFixed(1)}%",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),

          // Summary
          Text(
            result.summary,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),

          // Details
          if (result.details.isNotEmpty) ...[
            const Text(
              "Observations:",
              style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...result.details.map((detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, color: riskColor, size: 8),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(detail, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ),
                    ],
                  ),
                )),
          ],

          const Divider(color: Colors.white12, height: 30),

          // Recommendation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.recommend, color: Colors.blueAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.recommendation,
                    style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
