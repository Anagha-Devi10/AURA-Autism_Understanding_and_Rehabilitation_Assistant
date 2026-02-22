import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

class ParentProgressPage extends StatefulWidget {
  final int studentId;
  final String studentName;

  const ParentProgressPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<ParentProgressPage> createState() => _ParentProgressPageState();
}

class _ParentProgressPageState extends State<ParentProgressPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _progressData = {};
  List<Map<String, dynamic>> _sessionHistory = [];
  List<Map<String, dynamic>> _assessments = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadProgressData(),
        _loadSessionHistory(),
        _loadAssessments(),
      ]);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProgressData() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/progress/${widget.studentId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _progressData = data['progress'] ?? {};
        });
      }
    } catch (e) {
      print('Error loading progress: $e');
    }
  }

  Future<void> _loadSessionHistory() async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://localhost:5000/api/students/${widget.studentId}/therapy_sessions'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _sessionHistory =
              List<Map<String, dynamic>>.from(data['sessions'] ?? []);
        });
      }
    } catch (e) {
      print('Error loading sessions: $e');
    }
  }

  Future<void> _loadAssessments() async {
    try {
      final response = await http.get(
        Uri.parse(
            'http://localhost:5000/api/students/${widget.studentId}/assessments'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _assessments =
              List<Map<String, dynamic>>.from(data['assessments'] ?? []);
        });
      }
    } catch (e) {
      print('Error loading assessments: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : _error != null
                        ? _buildErrorState()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildOverviewTab(),
                              _buildSessionsTab(),
                              _buildAssessmentsTab(),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${widget.studentName}'s Progress",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Track development and milestones',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF7B42F6),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withOpacity(0.6),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Sessions'),
          Tab(text: 'Assessments'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 64, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadAllData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressSummaryCard(),
            const SizedBox(height: 20),
            _buildSkillsRadarChart(),
            const SizedBox(height: 20),
            _buildRecentActivityCard(),
            const SizedBox(height: 20),
            _buildMilestonesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSummaryCard() {
    final totalSessions = _progressData['total_sessions'] ?? 0;
    final avgOverall = _progressData['avg_overall'] ?? 0.0;
    final favoriteGame = _progressData['favorite_game'] ?? 'None yet';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7B42F6).withOpacity(0.3),
            const Color(0xFF42A5F5).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B42F6).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Text(
                'Progress Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Sessions',
                  totalSessions.toString(),
                  Icons.play_circle_outline,
                  const Color(0xFF4CAF50),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Avg Score',
                  '${avgOverall.toStringAsFixed(1)}%',
                  Icons.star_outline,
                  const Color(0xFFFF9800),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Completed',
                  _sessionHistory.where((s) => s['status'] == 'completed').length.toString(),
                  Icons.check_circle_outline,
                  const Color(0xFF2196F3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.games, color: Color(0xFFE91E63), size: 20),
                const SizedBox(width: 12),
                Text(
                  'Favorite Activity: ',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                Expanded(
                  child: Text(
                    favoriteGame,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSkillsRadarChart() {
    final avgEyeContact = (_progressData['avg_eye_contact'] ?? 0.0).toDouble();
    final avgSpeech = (_progressData['avg_speech'] ?? 0.0).toDouble();
    final avgMotor = (_progressData['avg_motor'] ?? 0.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skill Development',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _buildSkillBar('Eye Contact', avgEyeContact, const Color(0xFF4CAF50)),
          const SizedBox(height: 16),
          _buildSkillBar('Speech', avgSpeech, const Color(0xFF2196F3)),
          const SizedBox(height: 16),
          _buildSkillBar('Motor Skills', avgMotor, const Color(0xFFFF9800)),
        ],
      ),
    );
  }

  Widget _buildSkillBar(String skill, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              skill,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${value.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: value / 100,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivityCard() {
    final recentSessions = _sessionHistory.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(1),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentSessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No sessions yet',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ),
            )
          else
            ...recentSessions.map((session) => _buildActivityItem(session)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> session) {
    final status = session['status'] ?? 'pending';
    final title = session['title'] ?? 'Therapy Session';
    final date = session['scheduled_date'] ?? session['created_at'];

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'completed':
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.check_circle;
        break;
      case 'scheduled':
        statusColor = const Color(0xFF2196F3);
        statusIcon = Icons.schedule;
        break;
      case 'cancelled':
        statusColor = const Color(0xFFF44336);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFFFF9800);
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Milestones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildMilestoneItem(
            'First Assessment',
            _assessments.isNotEmpty,
            const Color(0xFF9C27B0),
          ),
          _buildMilestoneItem(
            'First Session Completed',
            _sessionHistory.any((s) => s['status'] == 'completed'),
            const Color(0xFF4CAF50),
          ),
          _buildMilestoneItem(
            '5 Sessions Completed',
            _sessionHistory.where((s) => s['status'] == 'completed').length >= 5,
            const Color(0xFF2196F3),
          ),
          _buildMilestoneItem(
            '10 Sessions Completed',
            _sessionHistory.where((s) => s['status'] == 'completed').length >= 10,
            const Color(0xFFFF9800),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneItem(String title, bool achieved, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: achieved ? color : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              achieved ? Icons.check : Icons.lock_outline,
              color: achieved ? Colors.white : Colors.white.withOpacity(0.3),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: achieved ? Colors.white : Colors.white.withOpacity(0.4),
              fontWeight: achieved ? FontWeight.w500 : FontWeight.normal,
              decoration: achieved ? null : TextDecoration.lineThrough,
            ),
          ),
          if (achieved) ...[
            const Spacer(),
            const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    if (_sessionHistory.isEmpty) {
      return _buildEmptyState(
        'No Sessions Yet',
        'Therapy sessions will appear here once scheduled',
        Icons.event_note,
      );
    }

    final completedSessions =
        _sessionHistory.where((s) => s['status'] == 'completed').toList();
    final upcomingSessions =
        _sessionHistory.where((s) => s['status'] == 'scheduled').toList();
    final pendingSessions =
        _sessionHistory.where((s) => s['status'] == 'pending').toList();

    return RefreshIndicator(
      onRefresh: _loadSessionHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (upcomingSessions.isNotEmpty) ...[
              _buildSectionTitle('Upcoming', upcomingSessions.length,
                  const Color(0xFF2196F3)),
              ...upcomingSessions.map((s) => _buildSessionCard(s)),
              const SizedBox(height: 24),
            ],
            if (pendingSessions.isNotEmpty) ...[
              _buildSectionTitle(
                  'Pending', pendingSessions.length, const Color(0xFFFF9800)),
              ...pendingSessions.map((s) => _buildSessionCard(s)),
              const SizedBox(height: 24),
            ],
            if (completedSessions.isNotEmpty) ...[
              _buildSectionTitle('Completed', completedSessions.length,
                  const Color(0xFF4CAF50)),
              ...completedSessions.map((s) => _buildSessionCard(s)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final status = session['status'] ?? 'pending';
    final title = session['title'] ?? 'Therapy Session';
    final therapistName = session['therapist_name'] ?? 'Unknown';
    final date = session['scheduled_date'];
    final time = session['scheduled_time'];
    final notes = session['session_notes'];

    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = const Color(0xFF4CAF50);
        break;
      case 'scheduled':
        statusColor = const Color(0xFF2196F3);
        break;
      case 'cancelled':
        statusColor = const Color(0xFFF44336);
        break;
      default:
        statusColor = const Color(0xFFFF9800);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person, size: 16, color: Colors.white.withOpacity(0.6)),
              const SizedBox(width: 6),
              Text(
                therapistName,
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 16, color: Colors.white.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(
                  _formatDate(date),
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
                if (time != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.access_time,
                      size: 16, color: Colors.white.withOpacity(0.6)),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(time),
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ],
            ),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes,
                      size: 16, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notes,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssessmentsTab() {
    if (_assessments.isEmpty) {
      return _buildEmptyState(
        'No Assessments Yet',
        'Assessment results will appear here',
        Icons.assessment,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAssessments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _assessments.length,
        itemBuilder: (context, index) {
          return _buildAssessmentCard(_assessments[index]);
        },
      ),
    );
  }

  Widget _buildAssessmentCard(Map<String, dynamic> assessment) {
    final riskLevel = assessment['combined_risk_level'] ?? 'Unknown';
    final score = assessment['combined_score'];
    final date = assessment['created_at'];
    final recommendation = assessment['recommendation'];

    Color riskColor;
    switch (riskLevel.toLowerCase()) {
      case 'high risk':
        riskColor = const Color(0xFFF44336);
        break;
      case 'moderate risk':
        riskColor = const Color(0xFFFF9800);
        break;
      case 'low-moderate risk':
        riskColor = const Color(0xFFFFEB3B);
        break;
      default:
        riskColor = const Color(0xFF4CAF50);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.assessment, color: riskColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assessment Result',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        riskLevel,
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Risk Level',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        score != null
                            ? '${(score * 100).toStringAsFixed(1)}%'
                            : 'N/A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Score',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (recommendation != null && recommendation.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 18, color: Colors.white.withOpacity(0.6)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'TBD';
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return 'TBD';
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$hour12:$minute $period';
    } catch (e) {
      return timeStr;
    }
  }
}