/// AURA Children Screen
/// Manage child profiles

import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';
import '../widgets/neumorphic_widgets.dart';
import '../services/api_service.dart';

class ChildrenScreen extends StatefulWidget {
  const ChildrenScreen({super.key});

  @override
  State<ChildrenScreen> createState() => _ChildrenScreenState();
}

class _ChildrenScreenState extends State<ChildrenScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    _children = await _api.getChildren();
    setState(() => _isLoading = false);
  }

  void _showAddChildDialog() {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Child Profile',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AuraTheme.textDark,
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: nameController,
                label: 'Name',
                hint: 'Enter child\'s name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: ageController,
                label: 'Age',
                hint: 'Enter age',
                icon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: notesController,
                label: 'Notes (Optional)',
                hint: 'Any special notes',
                icon: Icons.notes_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AuraTheme.textMedium,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final age = int.tryParse(ageController.text) ?? 0;
                        final notes = notesController.text.trim();

                        if (name.isEmpty || age <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter name and valid age'),
                              backgroundColor: AuraTheme.warning,
                            ),
                          );
                          return;
                        }

                        final result = await _api.createChild(
                          name: name,
                          age: age,
                          notes: notes.isNotEmpty ? notes : null,
                        );

                        if (result != null) {
                          Navigator.pop(context);
                          _loadChildren();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Profile created for $name'),
                              backgroundColor: AuraTheme.success,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to create profile. Is the server running?'),
                              backgroundColor: AuraTheme.error,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AuraTheme.accentCornflower,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AuraTheme.textMedium,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AuraTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AuraTheme.textLight.withAlpha((0.8 * 255).round()),
                fontSize: 14,
              ),
              prefixIcon: Icon(
                icon,
                color: AuraTheme.textMedium,
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _deleteChild(Map<String, dynamic> child) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete Profile?'),
        content: Text(
          'Are you sure you want to delete ${child['name']}\'s profile? This will also delete all session history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AuraTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _api.deleteChild(child['id']);
      if (success) {
        _loadChildren();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${child['name']}\'s profile deleted'),
            backgroundColor: AuraTheme.textMedium,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Child Profiles'),
        backgroundColor: AuraTheme.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddChildDialog,
        backgroundColor: AuraTheme.accentCornflower,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Child',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadChildren,
              child: _children.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _children.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final child = _children[index];
                        return _buildChildCard(child);
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
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AuraTheme.accentCornflower.withAlpha((0.15 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.child_care_rounded,
              size: 50,
              color: AuraTheme.accentCornflower.withAlpha((0.8 * 255).round()),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Profiles Yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AuraTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a child profile to get started\nwith therapy games',
            style: TextStyle(
              fontSize: 14,
              color: AuraTheme.textMedium.withAlpha((0.8 * 255).round()),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showAddChildDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add First Child',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AuraTheme.accentCornflower,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    return Dismissible(
      key: Key('child_${child['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AuraTheme.error.withAlpha((0.15 * 255).round()),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AuraTheme.error,
          size: 28,
        ),
      ),
      confirmDismiss: (_) async {
        _deleteChild(child);
        return false;
      },
      child: NeumorphicCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ChildAvatar(
              name: child['name'],
              size: 56,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child['name'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AuraTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AuraTheme.accentCornflower.withAlpha((0.15 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${child['age']} years old',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AuraTheme.accentCornflower,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (child['notes'] != null && child['notes'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        child['notes'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: AuraTheme.textMedium,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.chevron_right_rounded,
                color: AuraTheme.textLight,
              ),
              onPressed: () {
                // Could navigate to edit screen
              },
            ),
          ],
        ),
      ),
    );
  }
}
