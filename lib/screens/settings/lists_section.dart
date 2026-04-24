import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../lists_screen.dart';

class ListsSection extends StatelessWidget {
  const ListsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Browse and manage your Trakt and MDBlist custom lists',
            style: TextStyle(fontSize: 13, color: AppTheme.textDisabled),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ListsScreen()),
              ),
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Manage Lists'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.textPrimary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
