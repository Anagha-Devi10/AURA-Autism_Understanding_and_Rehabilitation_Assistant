import 'package:flutter/material.dart';
import '../services/therapy_session_service.dart';

class TherapySessionsPage extends StatefulWidget {
  final int therapistId;

  const TherapySessionsPage({super.key, required this.therapistId});

  @override
  State<TherapySessionsPage> createState() => _TherapySessionsPageState();
}

class _TherapySessionsPageState extends State<TherapySessionsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _pendingSessions = [];
  List<Map<String, dynamic>> _scheduledSessions = [];
  List<Map<String, dynamic>> _completedSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final pending = await TherapySessionService.getTherapistSessions(
        widget.therapistId,
        status: 'pending',
      );
      final scheduled = await TherapySessionService.getTherapistSessions(
        widget.therapistId,
        status: 'scheduled',
      );
      final completed = await TherapySessionService.getTherapistSessions(
        widget.therapistId,
        status: 'completed',
      );

      setState(() {
        _pendingSessions = pending;
        _scheduledSessions = scheduled;
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
        title: const Text('Therapy Sessions'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Pending (${_pendingSessions.length})',
              icon: const Icon(Icons.pending_actions),
            ),
            Tab(
              text: 'Scheduled (${_scheduledSessions.length})',
              icon: const Icon(Icons.calendar_today),
            ),
            Tab(
              text: 'Completed (${_completedSessions.length})',
              icon: const Icon(Icons.check_circle),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSessionsList(_pendingSessions, 'pending'),
                _buildSessionsList(_scheduledSessions, 'scheduled'),
                _buildSessionsList(_completedSessions, 'completed'),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadSessions,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildSessionsList(List<Map<String, dynamic>> sessions, String type) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'pending'
                  ? Icons.pending_actions
                  : type == 'scheduled'
                      ? Icons.calendar_today
                      : Icons.check_circle,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No $type sessions',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final session = sessions[index];
          return _buildSessionCard(session, type);
        },
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session, String type) {
    final childName = session['child_name'] ?? 'Unknown';
    final title = session['title'] ?? 'Therapy Session';
    final scheduledDate = session['scheduled_date'];
    final scheduledTime = session['scheduled_time'];
    final sessionType = session['session_type'] ?? 'initial';

    Color statusColor;
    IconData statusIcon;
    switch (type) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions;
        break;
      case 'scheduled':
        statusColor = Colors.blue;
        statusIcon = Icons.calendar_today;
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSessionDetails(session, type),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.2),
                    child: Icon(statusIcon, color: statusColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          childName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          title,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  _buildSessionTypeBadge(sessionType),
                ],
              ),
              if (scheduledDate != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.event, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(scheduledDate),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (scheduledTime != null) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(scheduledTime),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (type == 'pending')
                    ElevatedButton.icon(
                      onPressed: () => _showScheduleDialog(session),
                      icon: const Icon(Icons.schedule, size: 18),
                      label: const Text('Schedule'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  if (type == 'scheduled') ...[
                    OutlinedButton.icon(
                      onPressed: () => _showCancelDialog(session),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showCompleteDialog(session),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionTypeBadge(String type) {
    Color color;
    switch (type) {
      case 'initial':
        color = Colors.purple;
        break;
      case 'followup':
        color = Colors.teal;
        break;
      case 'review':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showSessionDetails(Map<String, dynamic> session, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                session['title'] ?? 'Therapy Session',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Student: ${session['child_name'] ?? 'Unknown'}',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Session Type', session['session_type'] ?? 'initial'),
              _buildDetailRow('Status', session['status'] ?? 'unknown'),
              if (session['scheduled_date'] != null)
                _buildDetailRow('Date', _formatDate(session['scheduled_date'])),
              if (session['scheduled_time'] != null)
                _buildDetailRow('Time', _formatTime(session['scheduled_time'])),
              _buildDetailRow('Duration', '${session['duration_minutes'] ?? 60} minutes'),
              if (session['description'] != null)
                _buildDetailRow('Description', session['description']),
              if (session['session_notes'] != null)
                _buildDetailRow('Notes', session['session_notes']),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog(Map<String, dynamic> session) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    int duration = 60;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule Session'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text(_formatDate(selectedDate.toIso8601String().split('T')[0])),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setDialogState(() => selectedDate = date);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Time'),
                subtitle: Text(selectedTime.format(context)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (time != null) {
                    setDialogState(() => selectedTime = time);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('Duration'),
                subtitle: DropdownButton<int>(
                  value: duration,
                  isExpanded: true,
                  items: [30, 45, 60, 90, 120].map((d) {
                    return DropdownMenuItem(value: d, child: Text('$d minutes'));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => duration = value);
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _scheduleSession(
                  session['id'],
                  selectedDate,
                  selectedTime,
                  duration,
                );
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scheduleSession(int sessionId, DateTime date, TimeOfDay time, int duration) async {
    try {
      await TherapySessionService.scheduleSession(
        sessionId: sessionId,
        scheduledDate: date.toIso8601String().split('T')[0],
        scheduledTime: '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        durationMinutes: duration,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session scheduled successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _loadSessions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scheduling session: $e')),
      );
    }
  }

  void _showCompleteDialog(Map<String, dynamic> session) {
    final notesController = TextEditingController();
    int communicationScore = 5;
    int socialScore = 5;
    int behavioralScore = 5;
    int cognitiveScore = 5;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Complete Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Session Notes:'),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter session notes...',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Scores (1-10):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildScoreSlider(
                  'Communication',
                  communicationScore,
                  (value) => setDialogState(() => communicationScore = value.round()),
                ),
                _buildScoreSlider(
                  'Social',
                  socialScore,
                  (value) => setDialogState(() => socialScore = value.round()),
                ),
                _buildScoreSlider(
                  'Behavioral',
                  behavioralScore,
                  (value) => setDialogState(() => behavioralScore = value.round()),
                ),
                _buildScoreSlider(
                  'Cognitive',
                  cognitiveScore,
                  (value) => setDialogState(() => cognitiveScore = value.round()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _completeSession(
                  session['id'],
                  notesController.text,
                  communicationScore,
                  socialScore,
                  behavioralScore,
                  cognitiveScore,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Complete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreSlider(String label, int value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _completeSession(
    int sessionId,
    String notes,
    int communication,
    int social,
    int behavioral,
    int cognitive,
  ) async {
    try {
      await TherapySessionService.completeSession(
        sessionId: sessionId,
        sessionNotes: notes,
        communicationScore: communication,
        socialScore: social,
        behavioralScore: behavioral,
        cognitiveScore: cognitive,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _loadSessions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing session: $e')),
      );
    }
  }

  void _showCancelDialog(Map<String, dynamic> session) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this session?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Reason for cancellation (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelSession(session['id'], reasonController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSession(int sessionId, String reason) async {
    try {
      await TherapySessionService.cancelSession(
        sessionId: sessionId,
        cancellationReason: reason,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session cancelled'),
          backgroundColor: Colors.orange,
        ),
      );

      _loadSessions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling session: $e')),
      );
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Not set';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return 'Not set';
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