class AnalysisResult {
  final bool asdRelated;
  final double confidenceScore;
  final String riskLevel;
  final String summary;
  final List<String> details;
  final String recommendation;

  AnalysisResult({
    required this.asdRelated,
    required this.confidenceScore,
    required this.riskLevel,
    required this.summary,
    required this.details,
    required this.recommendation,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final assessment = json['assessment'];
    return AnalysisResult(
      asdRelated: json['asd_related'],
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      riskLevel: assessment['risk_level'],
      summary: assessment['summary'],
      details: List<String>.from(assessment['details']),
      recommendation: assessment['recommendation'],
    );
  }
}