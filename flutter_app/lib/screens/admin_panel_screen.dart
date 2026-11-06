import 'package:flutter/material.dart';
import '../widgets/action_tile.dart';

class AdminPanelScreen extends StatelessWidget {
  static const route = '/admin';
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Admin actions',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            ActionTile(
              icon: Icons.group,
              label: 'Manage Members',
              onTap: () => Navigator.pushNamed(context, '/manage-members'),
            ),
            ActionTile(
              icon: Icons.receipt_long,
              label: 'Manage Payments',
              onTap: () => Navigator.pushNamed(context, '/manage-payments'),
            ),
            ActionTile(
              icon: Icons.file_upload,
              label: 'Import Data',
              onTap: () {
                // Placeholder: implement import flow (file picker / API)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Import Data not implemented yet')));
              },
            ),
          ],
        ),
      ),
    );
  }
}
