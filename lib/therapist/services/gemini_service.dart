import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String apiKey = 'AIzaSyCboE6kC3vjs4ghUjVxMcqQdIN0ldOEsWk';
  late final GenerativeModel model;

  GeminiService() {
    model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );
  }

  Future<String> generateReport(String summary, String childName) async {
    // Try Gemini API first
    try {
      print('Trying Gemini API...');

      final prompt = '''
Based on the following daily reports summary for $childName, generate a professional child development report:

$summary

Please generate a comprehensive report that includes:
1. Overview of observations
2. Key developmental areas
3. Notable behaviors or progress
4. Recommendations for caregivers
5. Areas of focus for next week

CRITICAL FORMATTING RULES:
- Use "$childName" throughout the report
- Use only basic ASCII characters
- Keep it concise - maximum 400 words
- No markdown headers with # symbols
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      var reportText = response.text ?? '';

      if (reportText.isNotEmpty) {
        print('Gemini API success!');
        return _sanitizeText(reportText, childName);
      }
    } catch (e) {
      print('Gemini API error: $e');
      
      // If quota exceeded, use local generation
      if (e.toString().contains('quota') || 
          e.toString().contains('exceeded') ||
          e.toString().contains('rate')) {
        print('Quota exceeded - using local generation');
        return _generateLocalReport(summary, childName);
      }
      
      return 'Error generating report: $e';
    }

    return _generateLocalReport(summary, childName);
  }

  /// Local report generation when API unavailable
  String _generateLocalReport(String summary, String childName) {
    final date = DateTime.now();
    final formattedDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    // Parse session notes
    final lines = summary
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    String observations = '';
    for (var line in lines) {
      String cleanLine = line.trim();
      if (cleanLine.contains(':')) {
        cleanLine = cleanLine.split(':').skip(1).join(':').trim();
      }
      if (cleanLine.isNotEmpty) {
        observations += '  * $cleanLine\n';
      }
    }

    if (observations.isEmpty) {
      observations = '  * Session observations recorded\n';
    }

    return '''
CHILD DEVELOPMENT PROGRESS REPORT

Date: $formattedDate
Child Name: $childName

1. OVERVIEW OF OBSERVATIONS

During this reporting period, $childName participated in therapy sessions with the following observations:

$observations
2. KEY DEVELOPMENTAL AREAS

  * Communication and language development
  * Social interaction and engagement
  * Emotional regulation and behavioral responses
  * Cognitive skills and learning activities

3. NOTABLE BEHAVIORS OR PROGRESS

$childName has shown active engagement during therapy sessions. The documented observations indicate participation in therapeutic activities with noted progress.

4. RECOMMENDATIONS FOR CAREGIVERS

  * Maintain consistent daily routines
  * Practice recommended activities at home
  * Reinforce positive behaviors
  * Communicate regularly with therapy team

5. AREAS OF FOCUS FOR UPCOMING SESSIONS

  * Building on current strengths
  * Addressing identified developmental needs
  * Monitoring response to interventions
  * Adjusting goals based on progress

---
Report Generated: $formattedDate
(Generated locally - AI service will resume when quota resets)
''';
  }

  String _sanitizeText(String text, String childName) {
    var result = text;

    final replacements = {
      ''': "'", ''': "'", '´': "'", '`': "'",
      '"': '"', '"': '"', '–': '-', '—': '-',
      '…': '...', '•': '*', '\u00A0': ' ',
    };

    replacements.forEach((unicode, ascii) {
      result = result.replaceAll(unicode, ascii);
    });

    result = result.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    result = result.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
    result = result.replaceAll(RegExp(r' +'), ' ');
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return result.trim();
  }
}