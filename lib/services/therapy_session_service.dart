import 'dart:convert';
import 'package:http/http.dart' as http;

class TherapySessionService {
  static const String baseUrl = 'http://localhost:5000';

  // ============================================
  // ASSESSMENT METHODS
  // ============================================

  /// Save assessment results after video + questionnaire
  static Future<Map<String, dynamic>> saveAssessment({
    required int studentId,
    double? videoScore,
    String? videoPrediction,
    double? videoConfidence,
    double? questionnaireScore,
    String? questionnaireRisk,
    double? combinedScore,
    String? combinedRiskLevel,
    String? recommendation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/assessments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'video_score': videoScore,
          'video_prediction': videoPrediction,
          'video_confidence': videoConfidence,
          'questionnaire_score': questionnaireScore,
          'questionnaire_risk': questionnaireRisk,
          'combined_score': combinedScore,
          'combined_risk_level': combinedRiskLevel,
          'recommendation': recommendation,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to save assessment: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error saving assessment: $e');
    }
  }

  /// Get assessments for a student
  static Future<List<Map<String, dynamic>>> getStudentAssessments(int studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/students/$studentId/assessments'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['assessments'] ?? []);
      } else {
        throw Exception('Failed to get assessments');
      }
    } catch (e) {
      throw Exception('Error getting assessments: $e');
    }
  }

  /// Get unreviewed assessments (for therapist)
  static Future<List<Map<String, dynamic>>> getUnreviewedAssessments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/assessments/unreviewed'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['assessments'] ?? []);
      } else {
        throw Exception('Failed to get unreviewed assessments');
      }
    } catch (e) {
      throw Exception('Error getting unreviewed assessments: $e');
    }
  }

  // ============================================
  // THERAPY SESSION METHODS
  // ============================================

  /// Create a new therapy session
  static Future<Map<String, dynamic>> createTherapySession({
    required int studentId,
    required int therapistId,
    int? assessmentId,
    required String title,
    String? description,
    String sessionType = 'initial',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/therapy_sessions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'therapist_id': therapistId,
          'assessment_id': assessmentId,
          'title': title,
          'description': description,
          'session_type': sessionType,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create therapy session: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating therapy session: $e');
    }
  }

  /// Schedule a therapy session (set date and time)
  static Future<Map<String, dynamic>> scheduleSession({
    required int sessionId,
    required String scheduledDate,
    required String scheduledTime,
    int durationMinutes = 60,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/therapy_sessions/$sessionId/schedule'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'scheduled_date': scheduledDate,
          'scheduled_time': scheduledTime,
          'duration_minutes': durationMinutes,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to schedule session: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error scheduling session: $e');
    }
  }

  /// Mark session as completed
  static Future<Map<String, dynamic>> completeSession({
    required int sessionId,
    String? sessionNotes,
    int? communicationScore,
    int? socialScore,
    int? behavioralScore,
    int? cognitiveScore,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/therapy_sessions/$sessionId/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_notes': sessionNotes,
          'communication_score': communicationScore,
          'social_score': socialScore,
          'behavioral_score': behavioralScore,
          'cognitive_score': cognitiveScore,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to complete session: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error completing session: $e');
    }
  }

  /// Cancel a therapy session
  static Future<Map<String, dynamic>> cancelSession({
    required int sessionId,
    String? cancellationReason,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/therapy_sessions/$sessionId/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cancellation_reason': cancellationReason,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to cancel session: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error cancelling session: $e');
    }
  }

  /// Get therapy sessions for a student (parent view)
  static Future<List<Map<String, dynamic>>> getStudentSessions(int studentId, {String? status}) async {
    try {
      String url = '$baseUrl/api/students/$studentId/therapy_sessions';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['sessions'] ?? []);
      } else {
        throw Exception('Failed to get student sessions');
      }
    } catch (e) {
      throw Exception('Error getting student sessions: $e');
    }
  }

  /// Get upcoming sessions for a student
  static Future<List<Map<String, dynamic>>> getUpcomingSessions(int studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/students/$studentId/upcoming_sessions'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['sessions'] ?? []);
      } else {
        throw Exception('Failed to get upcoming sessions');
      }
    } catch (e) {
      throw Exception('Error getting upcoming sessions: $e');
    }
  }

  /// Get therapist's therapy sessions
  static Future<List<Map<String, dynamic>>> getTherapistSessions(int therapistId, {String? status}) async {
    try {
      String url = '$baseUrl/api/therapists/$therapistId/therapy_sessions';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['sessions'] ?? []);
      } else {
        throw Exception('Failed to get therapist sessions');
      }
    } catch (e) {
      throw Exception('Error getting therapist sessions: $e');
    }
  }

  /// Get therapist's pending sessions
  static Future<List<Map<String, dynamic>>> getPendingSessions(int therapistId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/therapists/$therapistId/pending_sessions'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['sessions'] ?? []);
      } else {
        throw Exception('Failed to get pending sessions');
      }
    } catch (e) {
      throw Exception('Error getting pending sessions: $e');
    }
  }

  /// Get therapist's today sessions
  static Future<List<Map<String, dynamic>>> getTodaySessions(int therapistId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/therapists/$therapistId/today_sessions'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['sessions'] ?? []);
      } else {
        throw Exception('Failed to get today sessions');
      }
    } catch (e) {
      throw Exception('Error getting today sessions: $e');
    }
  }

  // ============================================
  // PROGRESS METHODS
  // ============================================

  /// Get progress entries for a student
  static Future<List<Map<String, dynamic>>> getStudentProgress(int studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/students/$studentId/progress'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['entries'] ?? []);
      } else {
        throw Exception('Failed to get progress entries');
      }
    } catch (e) {
      throw Exception('Error getting progress entries: $e');
    }
  }

  // ============================================
  // DASHBOARD STATS
  // ============================================

  /// Get therapist dashboard stats
  static Future<Map<String, dynamic>> getTherapistDashboardStats(int therapistId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/therapists/$therapistId/dashboard_stats'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['stats'] ?? {});
      } else {
        throw Exception('Failed to get dashboard stats');
      }
    } catch (e) {
      throw Exception('Error getting dashboard stats: $e');
    }
  }

  /// Get parent dashboard stats
  static Future<Map<String, dynamic>> getParentDashboardStats(int parentId, int studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/parents/$parentId/dashboard_stats?student_id=$studentId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['stats'] ?? {});
      } else {
        throw Exception('Failed to get dashboard stats');
      }
    } catch (e) {
      throw Exception('Error getting dashboard stats: $e');
    }
  }
}