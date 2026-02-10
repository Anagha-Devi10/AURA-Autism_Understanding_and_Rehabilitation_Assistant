import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/gemini_service.dart';
import '../services/pdf_service.dart';

class ChildDetailPage extends StatefulWidget {
  final String childName;
  final int id;
  final int? therapistId;
  final Map<String, String>? childInfo;

  const ChildDetailPage({
    super.key,
    required this.childName,
    required this.id,
    this.therapistId,
    this.childInfo,
  });

  @override
  State<ChildDetailPage> createState() => _ChildDetailPageState();
}

class _ChildDetailPageState extends State<ChildDetailPage>
    with TickerProviderStateMixin {
  List<Map<String, String>> dailyReports = [];
  TextEditingController reportController = TextEditingController();
  TextEditingController dateController = TextEditingController();
  late GeminiService geminiService;
  bool isGenerating = false;
  bool isLoadingTherapist = true;
  String therapistName = 'Therapist';
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    geminiService = GeminiService();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fetchTherapistName();

    if (widget.childInfo != null) {
      print('Child Info Loaded: ${widget.childInfo}');
    }
  }

  Future<void> _fetchTherapistName() async {
    if (widget.therapistId == null) {
      print('No therapist ID provided, using default name');
      setState(() {
        isLoadingTherapist = false;
      });
      return;
    }

    try {
      print('Fetching therapist with ID: ${widget.therapistId}');

      final response = await http
          .get(
            Uri.parse('http://localhost:5000/api/therapists/${widget.therapistId}'),
          )
          .timeout(const Duration(seconds: 10));

      print('Therapist API response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          therapistName = data['name'] ?? data['full_name'] ?? 'Therapist';
          isLoadingTherapist = false;
        });
        print('Therapist name fetched: $therapistName');
      } else {
        print('Failed to fetch therapist: ${response.statusCode}');
        // Try alternate endpoint
        await _tryAlternateTherapistFetch();
      }
    } catch (e) {
      print('Error fetching therapist: $e');
      await _tryAlternateTherapistFetch();
    }
  }

  Future<void> _tryAlternateTherapistFetch() async {
    try {
      // Try getting from therapists list
      final response = await http
          .get(
            Uri.parse('http://localhost:5000/api/therapists'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> therapists = jsonDecode(response.body);
        final therapist = therapists.firstWhere(
          (t) => t['id'] == widget.therapistId,
          orElse: () => null,
        );
        if (therapist != null) {
          setState(() {
            therapistName = therapist['name'] ?? therapist['full_name'] ?? 'Therapist';
            isLoadingTherapist = false;
          });
          print('Therapist name from list: $therapistName');
          return;
        }
      }
    } catch (e) {
      print('Alternate fetch also failed: $e');
    }

    setState(() {
      isLoadingTherapist = false;
    });
  }

  void addReport() {
    if (reportController.text.isEmpty || dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in both date and report"),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    setState(() {
      dailyReports.add({
        "date": dateController.text,
        "report": reportController.text,
      });
      reportController.clear();
      dateController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Report added successfully"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.purple,
              onPrimary: Colors.white,
              surface: Color(0xFF1a1a2e),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        dateController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  void generateSummary() async {
    print('Generate button clicked');

    if (dailyReports.isEmpty && reportController.text.isEmpty) {
      print('No daily reports to generate summary');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add at least one report"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => isGenerating = true);

    try {
      final summaryParts = [
        ...dailyReports.map((e) => "${e['date']}: ${e['report']}"),
        if (reportController.text.isNotEmpty)
          "${dateController.text.isNotEmpty ? dateController.text : 'Today'}: ${reportController.text}",
      ];

      final summary = summaryParts.join("\n");

      print('Summary created:\n$summary');
      print('Calling Gemini API...');

      final aiReport = await geminiService.generateReport(summary, widget.childName);
      print('Gemini report generated');

      if (aiReport.startsWith('Error')) {
        throw Exception(aiReport);
      }

      print('Generating PDF with therapist: $therapistName');
      final pdfPath = await PdfService.generateAndSavePdf(
        childName: widget.childName,
        report: aiReport,
        date: DateTime.now().toIso8601String(),
        therapistName: therapistName,
      );
      print('PDF generated at: $pdfPath');

      setState(() => isGenerating = false);

      if (mounted) {
        _fadeController.forward();
        _showReportDialog(aiReport, pdfPath);
      }
    } catch (e) {
      print('Error in generateSummary: $e');
      setState(() => isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showReportDialog(String aiReport, String pdfPath) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Report Generated!",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.purple, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "Therapist: $therapistName",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "AI-Generated Summary:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      aiReport,
                      style: const TextStyle(
                        height: 1.5,
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.greenAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pdfPath.split('/').last.split('\\').last,
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text("Open Location"),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("PDF saved at: $pdfPath"),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.childName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Row(
              children: [
                if (isLoadingTherapist)
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1,
                      color: Colors.white54,
                    ),
                  )
                else
                  Text(
                    'Therapist: $therapistName',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16213e),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Input Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  // Date Field
                  GestureDetector(
                    onTap: _selectDate,
                    child: AbsorbPointer(
                      child: TextField(
                        controller: dateController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Date",
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: "Tap to select date",
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.calendar_today, color: Colors.purple),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Report Field
                  TextField(
                    controller: reportController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Session Notes",
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: "Enter observations, progress, and main points...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 60),
                        child: Icon(Icons.edit_note, color: Colors.purple),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: addReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text("Add"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isGenerating ? null : generateSummary,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.purple.withOpacity(0.5),
                          ),
                          icon: isGenerating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome, size: 20),
                          label: Text(isGenerating ? "Generating..." : "Generate AI Report"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Reports List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Session Reports",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${dailyReports.length} reports",
                    style: const TextStyle(color: Colors.purple, fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Reports List
            Expanded(
              child: dailyReports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.note_alt_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          const Text(
                            "No reports yet",
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Add session notes above to get started",
                            style: TextStyle(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: dailyReports.length,
                      itemBuilder: (context, index) {
                        final report = dailyReports[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              report["report"]!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                report['date']!,
                                style: const TextStyle(color: Colors.purple, fontSize: 12),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                              onPressed: () {
                                setState(() => dailyReports.removeAt(index));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Report deleted"),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    reportController.dispose();
    dateController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}
