import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // API key is passed at build time via: flutter run --dart-define=GEMINI_API_KEY=your_key
  // NEVER hardcode the key here — it will be revoked by Google if committed to GitHub.
  static const String apiKey = String.fromEnvironment('GEMINI_API_KEY');
  late final GenerativeModel model;

  GeminiService() {
    model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );
  }

  Future<String> generateReport(String summary, String childName) async {
    // Check if API key is configured
    if (apiKey.isEmpty) {
      print('⚠️ Gemini API key not configured! Using local report generation.');
      print('Run with: flutter run -d chrome --dart-define=GEMINI_API_KEY=your_key');
      return _generateLocalReport(summary, childName);
    }

    // Try Gemini API first
    try {
      print('Trying Gemini API with model: gemini-2.5-flash...');

      final now = DateTime.now();
      final currentDate = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      final prompt = '''
Based on the following daily reports summary for $childName, generate a professional child development report:

$summary

Today's date is $currentDate.

Please generate a comprehensive report that includes:
1. Overview of observations
2. Key developmental areas
3. Notable behaviors or progress
4. Recommendations for caregivers
5. Areas of focus for next week

CRITICAL FORMATTING RULES:
- Use "$childName" throughout the report
- Use "$currentDate" as the report date (do NOT write "[Current Date]" or any placeholder)
- Use only basic ASCII characters
- Keep it concise - maximum 400 words
- No markdown headers with # symbols
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      var reportText = response.text ?? '';

      if (reportText.isNotEmpty) {
        print('✅ Gemini API success!');
        return _sanitizeText(reportText, childName);
      }
    } catch (e) {
      print('❌ Gemini API error: $e');
      
      // Provide clear error messages for common issues
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('leaked') || errorStr.contains('permission_denied')) {
        print('🔑 API key was flagged as leaked by Google. Generate a NEW key at:');
        print('   https://aistudio.google.com/app/apikey');
        return 'Error: API key has been revoked by Google (leaked key). Please generate a new API key at https://aistudio.google.com/app/apikey and update gemini_service.dart';
      }
      
      if (errorStr.contains('quota') || 
          errorStr.contains('exceeded') ||
          errorStr.contains('rate') ||
          errorStr.contains('resource_exhausted')) {
        print('⏳ Quota exceeded - using local generation');
        return _generateLocalReport(summary, childName);
      }

      if (errorStr.contains('forbidden') || errorStr.contains('403')) {
        print('🚫 API key invalid or disabled');
        return 'Error: Gemini API key is invalid or disabled. Please check your API key.';
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

    // Replace smart quotes and special chars with ASCII equivalents
    result = result.replaceAll(RegExp(r'[\u2018\u2019\u00B4\u0060]'), "'");
    result = result.replaceAll(RegExp(r'[\u201C\u201D]'), '"');
    result = result.replaceAll(RegExp(r'[\u2013\u2014]'), '-');
    result = result.replaceAll('\u2026', '...');
    result = result.replaceAll('\u2022', '*');
    result = result.replaceAll('\u00A0', ' ');

    result = result.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    result = result.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
    result = result.replaceAll(RegExp(r' +'), ' ');
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return result.trim();
  }
}