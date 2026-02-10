import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/pdf_service.dart';

class ChildInfoPage extends StatefulWidget {
  final String childName;
  final String therapistName;
  final Map<String, String>? childInfo;

  const ChildInfoPage({
    super.key,
    required this.childName,
    required this.therapistName,
    this.childInfo,
  });

  @override
  State<ChildInfoPage> createState() => _ChildInfoPageState();
}

class _ChildInfoPageState extends State<ChildInfoPage>
    with TickerProviderStateMixin {
  List<Map<String, String>> dailyReports = [];
  TextEditingController reportController = TextEditingController();
  TextEditingController dateController = TextEditingController();
  late GeminiService geminiService;
  bool isGenerating = false;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    geminiService = GeminiService();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    if (widget.childInfo != null) {
      print('🟢 Child Info Loaded: ${widget.childInfo}');
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        dateController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
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

  void generateSummary() async {
    print('🟡 Generate button clicked');

    if (dailyReports.isEmpty && reportController.text.isEmpty) {
      print('⚠️ No daily reports to generate summary');
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

      print('🟡 Summary created:\n$summary');

      print('🟡 Calling Gemini API...');
      // Fixed: Pass both summary and childName as separate arguments
      final aiReport = await geminiService.generateReport(summary, widget.childName);
      print('✅ Gemini report generated:\n$aiReport');

      if (aiReport.startsWith('Error')) {
        throw Exception(aiReport);
      }

      print('🟡 Generating PDF...');
      final pdfPath = await PdfService.generateAndSavePdf(
        childName: widget.childName,
        report: aiReport,
        date: DateTime.now().toString().split('.')[0],
        therapistName: widget.therapistName,
      );
      print('✅ PDF generated at: $pdfPath');

      setState(() => isGenerating = false);

      if (mounted) {
        _fadeController.forward();
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.blue.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.description, color: Colors.blue.shade700),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Report Generated!",
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Report Summary:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          aiReport,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "PDF saved: ${pdfPath.split('/').last.split('\\').last}",
                            style: TextStyle(color: Colors.green.shade700, fontSize: 12),
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
                child: const Text("Close"),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.download),
                label: const Text("Open PDF"),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("PDF saved at: $pdfPath"),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ Error in generateSummary: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.childName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Therapist: ${widget.therapistName}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade400,
        elevation: 5,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Date Field with Date Picker
                      GestureDetector(
                        onTap: _selectDate,
                        child: AbsorbPointer(
                          child: TextField(
                            controller: dateController,
                            decoration: InputDecoration(
                              labelText: "Date",
                              labelStyle: const TextStyle(color: Colors.blue),
                              hintText: "Tap to select date",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Colors.blue, width: 2),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Colors.blue, width: 2),
                              ),
                              prefixIcon: const Icon(Icons.calendar_today,
                                  color: Colors.blue),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: reportController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: "Session Notes",
                          hintText: "Enter observations & main points",
                          hintStyle: TextStyle(color: Colors.blue.shade300),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Colors.blue, width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Colors.blue, width: 2),
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 60),
                            child: Icon(Icons.edit, color: Colors.blue),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: addReport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade400,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 5,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text(
                                "Add Report",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isGenerating ? null : generateSummary,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade400,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 5,
                                disabledBackgroundColor: Colors.blue.shade200,
                              ),
                              icon: isGenerating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.auto_awesome),
                              label: Text(
                                isGenerating
                                    ? "Generating..."
                                    : "AI Report",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Reports Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Session Reports",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${dailyReports.length} reports",
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Expanded(
                child: dailyReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_outlined,
                              size: 80,
                              color: Colors.blue.shade200,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "No reports yet",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.blue.shade300,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "Add your first report above",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue.shade200,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: dailyReports.length,
                        itemBuilder: (context, index) {
                          final report = dailyReports[index];
                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                report["report"]!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  report['date']!,
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent),
                                onPressed: () {
                                  setState(() {
                                    dailyReports.removeAt(index);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Report deleted"),
                                      backgroundColor: Colors.orangeAccent,
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
