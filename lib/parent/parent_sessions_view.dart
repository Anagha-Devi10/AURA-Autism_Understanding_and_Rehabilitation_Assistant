import 'package:flutter/material.dart';
import '../services/therapy_session_service.dart';

class ParentSessionsPage extends StatefulWidget {
  final int studentId;
  final String studentName;

  const ParentSessionsPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<ParentSessionsPage> createState() => _ParentSessionsPageState();
}

class _ParentSessionsPageState extends State<ParentSessionsPage> {
  List<Map<String, dynamic>> _pendingSessions = [];
  List<Map<String, dynamic>> _upcomingSessions = [];
  List<Map<String, dynamic>> _completedSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final pending = await TherapySessionService.getStudentSessions(
        widget.studentId,
        status: 'pending',
      );
      final upcoming = await TherapySessionService.getStudentSessions(
        widget.studentId,
        status: 'scheduled',
      );
      final completed = await TherapySessionService.getStudentSessions(
        widget.studentId,
        status: 'completed',
      );

      setState(() {
        _pendingSessions = pending;
        _upcomingSessions = upcoming;
        _completedSessions = completed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sessions: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.studentName}\'s Sessions'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSessions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pending Sessions (assigned but not yet scheduled)
                    if (_pendingSessions.isNotEmpty) ...[
                      _buildSectionHeader(
                        'Pending Sessions',
                        Icons.pending_actions,
                        Colors.orange,
                        _pendingSessions.length,
                      ),
                      const SizedBox(height: 12),
                      ..._pendingSessions.map((s) => _buildSessionCard(s, true, isPending: true)),
                      const SizedBox(height: 32),
                    ],

                    // Upcoming Sessions
                    _buildSectionHeader(
                      'Upcoming Sessions',
                      Icons.calendar_today,
                      Colors.blue,
                      _upcomingSessions.length,
                    ),
                    const SizedBox(height: 12),
                    if (_upcomingSessions.isEmpty)
                      _buildEmptyState('No upcoming sessions scheduled')
                    else
                      ..._upcomingSessions.map((s) => _buildSessionCard(s, true)),

                    const SizedBox(height: 32),

                    // Completed Sessions
                    _buildSectionHeader(
                      'Completed Sessions',
                      Icons.check_circle,
                      Colors.green,
                      _completedSessions.length,
                    ),
                    const SizedBox(height: 12),
                    if (_completedSessions.isEmpty)
                      _buildEmptyState('No completed sessions yet')
                    else
                      ..._completedSessions.map((s) => _buildSessionCard(s, false)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, int count) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session, bool isUpcoming, {bool isPending = false}) {
    final therapistName = session['therapist_name'] ?? 'Unknown Therapist';
    final title = session['title'] ?? 'Therapy Session';
    final scheduledDate = session['scheduled_date'];
    final scheduledTime = session['scheduled_time'];
    final duration = session['duration_minutes'] ?? 60;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isPending
                      ? Colors.orange.withOpacity(0.2)
                      : isUpcoming
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                  child: Icon(
                    isPending
                        ? Icons.pending_actions
                        : isUpcoming
                            ? Icons.calendar_today
                            : Icons.check_circle,
                    color: isPending
                        ? Colors.orange
                        : isUpcoming
                            ? Colors.blue
                            : Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'with $therapistName',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isPending)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Awaiting scheduling by therapist',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoItem(
                      Icons.event,
                      'Date',
                      _formatDate(scheduledDate),
                    ),
                    _buildInfoItem(
                      Icons.access_time,
                      'Time',
                      _formatTime(scheduledTime),
                    ),
                    _buildInfoItem(
                      Icons.timer,
                      'Duration',
                      '$duration min',
                    ),
                  ],
                ),
              ),
            if (!isUpcoming && session['session_notes'] != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Session Notes:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session['session_notes'],
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'TBD';
    try {
      final date = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]}';
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