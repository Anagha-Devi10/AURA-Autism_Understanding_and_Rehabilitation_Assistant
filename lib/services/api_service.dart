/// AURA API Service
/// Handles communication with Flask backend

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api';
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  // HTTP Headers
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // ============================================
  // GAME ENDPOINTS
  // ============================================
  
  /// Get all available games
  Future<List<Map<String, dynamic>>> getGames() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/games'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['games'] ?? []);
      }
      throw Exception('Failed to load games: ${response.statusCode}');
    } catch (e) {
      print('Error fetching games: $e');
      return _getOfflineGames();
    }
  }
  
  /// Get a specific game by ID
  Future<Map<String, dynamic>?> getGame(String gameId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/games/$gameId'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['game'];
      }
      return null;
    } catch (e) {
      print('Error fetching game: $e');
      return null;
    }
  }
  
  // ============================================
  // SESSION ENDPOINTS
  // ============================================
  
  /// Start a new game session
  Future<Map<String, dynamic>?> startGame(String gameId, int studentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/start_game'),
        headers: _headers,
        body: json.encode({
          'game_id': gameId,
          'student_id': studentId,
        }),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to start game: ${response.statusCode}');
    } catch (e) {
      print('Error starting game: $e');
      return null;
    }
  }
  
  /// Stop a game session
  Future<Map<String, dynamic>?> stopGame(int sessionId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stop_game'),
        headers: _headers,
        body: json.encode({'session_id': sessionId}),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error stopping game: $e');
      return null;
    }
  }
  
  /// Record therapy scores
  Future<bool> recordScore({
    required int sessionId,
    int eyeContactScore = 0,
    int speechScore = 0,
    int motorScore = 0,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/record_score'),
        headers: _headers,
        body: json.encode({
          'session_id': sessionId,
          'eye_contact_score': eyeContactScore,
          'speech_score': speechScore,
          'motor_score': motorScore,
          'notes': notes,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error recording score: $e');
      return false;
    }
  }
  
  /// Get session history
  Future<List<Map<String, dynamic>>> getSessions({int? studentId}) async {
    try {
      String url = '$baseUrl/sessions';
      if (studentId != null) {
        url += '?student_id=$studentId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['sessions'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching sessions: $e');
      return [];
    }
  }
  
  // ============================================
  // CHILD ENDPOINTS
  // ============================================
  
  /// Get all children
  Future<List<Map<String, dynamic>>> getChildren() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/students'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['students'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching children: $e');
      return [];
    }
  }
  
  /// Get a single child profile by ID
  Future<Map<String, dynamic>?> getChild(int studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/students/$studentId'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // The endpoint may return the student directly or wrapped in a key
        if (data is Map<String, dynamic>) {
          if (data.containsKey('child')) return Map<String, dynamic>.from(data['child']);
          if (data.containsKey('student')) return Map<String, dynamic>.from(data['student']);
          if (data.containsKey('id')) return data;
        }
      }
      return null;
    } catch (e) {
      print('Error fetching child $studentId: $e');
      return null;
    }
  }

  /// Create a new child profile
  Future<Map<String, dynamic>?> createChild({
    required String name,
    required int age,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/students'),
        headers: _headers,
        body: json.encode({
          'name': name,
          'age': age,
          'notes': notes,
        }),
      );
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['child'];
      }
      return null;
    } catch (e) {
      print('Error creating child: $e');
      return null;
    }
  }
  
  /// Update child profile
  Future<bool> updateChild(int studentId, {String? name, int? age, String? notes}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/students/$studentId'),
        headers: _headers,
        body: json.encode({
          if (name != null) 'name': name,
          if (age != null) 'age': age,
          if (notes != null) 'notes': notes,
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating child: $e');
      return false;
    }
  }
  
  /// Delete child profile
  Future<bool> deleteChild(int studentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/students/$studentId'),
        headers: _headers,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting child: $e');
      return false;
    }
  }
  
  // ============================================
  // PROGRESS ENDPOINTS
  // ============================================
  
  /// Get progress for a child
  Future<Map<String, dynamic>?> getProgress(int studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/progress/$studentId'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching progress: $e');
      return null;
    }
  }
  
  // ============================================
  // HEALTH CHECK
  // ============================================
  
  /// Check if backend is available
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  // ============================================
  // OFFLINE FALLBACK
  // ============================================
  
  List<Map<String, dynamic>> _getOfflineGames() {
    return [
      {
        'id': 'G1',
        'name': 'Magnet Catch',
        'description': 'Track floating objects with your eyes to catch them!',
        'therapy_focus': 'Eye Contact',
        'color': '#E3F2FD',
      },
      {
        'id': 'G2',
        'name': 'Sound Match',
        'description': 'Listen to sounds and match them to the right pictures!',
        'therapy_focus': 'Speech & Hearing',
        'color': '#F3E5F5',
      },
      {
        'id': 'G3',
        'name': 'Invisible Maze',
        'description': 'Navigate through the maze by feeling the path!',
        'therapy_focus': 'Fine Motor Skills',
        'color': '#E8F5E9',
      },
      {
        'id': 'G4',
        'name': 'Jumping Numbers',
        'description': 'Count the jumping objects and tap the right number!',
        'therapy_focus': 'Counting & Movement',
        'color': '#FFF3E0',
      },
      {
        'id': 'G5',
        'name': 'Alphabet Fish',
        'description': 'Catch the fish with the right letters to spell words!',
        'therapy_focus': 'Letter Recognition',
        'color': '#E1F5FE',
      },
      {
        'id': 'G6',
        'name': 'Emotion Slider',
        'description': 'Match the faces to the right emotions!',
        'therapy_focus': 'Emotional Awareness',
        'color': '#FCE4EC',
      },
      {
        'id': 'G7',
        'name': 'Simon Says',
        'description': 'Follow the pattern of colors and sounds!',
        'therapy_focus': 'Following Instructions',
        'color': '#FFFDE7',
      },
      {
        'id': 'G8',
        'name': 'Glow Race',
        'description': 'Follow the glowing light with your eyes!',
        'therapy_focus': 'Visual Tracking',
        'color': '#E0F7FA',
      },
    ];
  }
}
