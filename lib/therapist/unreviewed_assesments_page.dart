import 'package:flutter/material.dart';
import '../../services/therapy_session_service.dart';

class UnreviewedAssessmentsPage extends StatefulWidget {
  final int therapistId;

  const UnreviewedAssessmentsPage({super.key, required this.therapistId});

  @override
  State<UnreviewedAssessmentsPage> createState() => _UnreviewedAssessmentsPageState();
}

class _UnreviewedAssessmentsPageState extends State<UnreviewedAssessmentsPage> {
  List<Map<String, dynamic>> _assessments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssessments();
  }

  Future<void> _loadAssessments() async {
    setState(() => _isLoading = true);
    try {
      final assessments = await TherapySessionService.getUnreviewedAssessments();
      setState(() {
        _assessments = assessments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading assessments: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unreviewed Assessments'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assessments.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAssessments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _assessments.length,
                    itemBuilder: (context, index) {
                      return _buildAssessmentCard(_assessments[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in, size: 80, color: Colors.green[300]),
          const SizedBox(height: 16),
          const Text(
            'All assessments reviewed!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No pending assessments to review',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentCard(Map<String, dynamic> assessment) {
    final childName = assessment['child_name'] ?? 'Unknown';
    final riskLevel = assessment['combined_risk_level'] ?? 'Unknown';
    final score = assessment['combined_score'];
    final createdAt = assessment['created_at'];

    Color riskColor;
    switch (riskLevel.toString().toLowerCase()) {
      case 'high':
        riskColor = Colors.red;
        break;
      case 'medium':
        riskColor = Colors.orange;
        break;
      case 'low':
        riskColor = Colors.green;
        break;
      default:
        riskColor = Colors.grey;
    }

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
                  backgroundColor: riskColor.withOpacity(0.2),
                  child: Text(
                    childName[0].toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: riskColor,
                    ),
                  ),
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
                        'Assessment: ${_formatDate(createdAt)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$riskLevel Risk',
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildScoreItem('Video', assessment['video_score']),
                  _buildScoreItem('Q-CHAT', assessment['questionnaire_score']),
                  _buildScoreItem('Combined', score),
                ],
              ),
            ),
            if (assessment['recommendation'] != null) ...[
              const SizedBox(height: 12),
              Text(
                'Recommendation: ${assessment['recommendation']}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAssessmentDetails(assessment),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAssignSessionDialog(assessment),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Assign Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreItem(String label, dynamic score) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          score != null ? score.toStringAsFixed(1) : 'N/A',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  void _showAssessmentDetails(Map<String, dynamic> assessment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
                'Assessment Details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Student: ${assessment['child_name'] ?? 'Unknown'}',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              _buildDetailSection('Video Analysis', [
                _buildDetailRow('Prediction', assessment['video_prediction'] ?? 'N/A'),
                _buildDetailRow('Score', '${assessment['video_score'] ?? 'N/A'}'),
                _buildDetailRow('Confidence', '${assessment['video_confidence'] ?? 'N/A'}%'),
              ]),
              const SizedBox(height: 16),
              _buildDetailSection('Questionnaire', [
                _buildDetailRow('Score', '${assessment['questionnaire_score'] ?? 'N/A'}'),
                _buildDetailRow('Risk Level', assessment['questionnaire_risk'] ?? 'N/A'),
              ]),
              const SizedBox(height: 16),
              _buildDetailSection('Combined Result', [
                _buildDetailRow('Score', '${assessment['combined_score'] ?? 'N/A'}'),
                _buildDetailRow('Risk Level', assessment['combined_risk_level'] ?? 'N/A'),
              ]),
              if (assessment['recommendation'] != null) ...[
                const SizedBox(height: 16),
                _buildDetailSection('Recommendation', [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(assessment['recommendation']),
                  ),
                ]),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAssignSessionDialog(assessment);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Assign Therapy Session'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
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
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showAssignSessionDialog(Map<String, dynamic> assessment) {
    final titleController = TextEditingController(text: 'Initial Therapy Session');
    final descriptionController = TextEditingController();
    String sessionType = 'initial';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign Therapy Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student: ${assessment['child_name'] ?? 'Unknown'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Session Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Session Type:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: sessionType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'initial', child: Text('Initial Assessment')),
                    DropdownMenuItem(value: 'followup', child: Text('Follow-up')),
                    DropdownMenuItem(value: 'review', child: Text('Review')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => sessionType = value);
                    }
                  },
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
                await _createTherapySession(
                  assessment,
                  titleController.text,
                  descriptionController.text,
                  sessionType,
                );
              },
              child: const Text('Create Session'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTherapySession(
    Map<String, dynamic> assessment,
    String title,
    String description,
    String sessionType,
  ) async {
    try {
      await TherapySessionService.createTherapySession(
        studentId: assessment['child_id'],
        therapistId: widget.therapistId,
        assessmentId: assessment['id'],
        title: title,
        description: description.isEmpty ? null : description,
        sessionType: sessionType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Therapy session created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadAssessments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating session: $e')),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}