import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import '../models/dashboard_model.dart';
import '../utils/constants.dart';
import '../utils/app_theme.dart';
import '../widgets/stat_card.dart';
import 'emergency_contacts_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  UserModel? _user;
  DashboardModel? _dashboard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await AuthService.loadUser();

    if (user == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppConstants.loginRoute,
        );
      }
      return;
    }

    final dashboard = await ApiService.getDashboard();

    if (mounted) {
      setState(() {
        _user = user;
        _dashboard = dashboard;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();

    if (mounted) {
      Navigator.pushReplacementNamed(
        context,
        AppConstants.loginRoute,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Witness Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.accent,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.accent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome section
                    Text(
                      'Welcome, ${_user?.fullname ?? ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Manage emergency recordings and encrypted evidence from one place.',
                      style: TextStyle(
                        color: AppTheme.textLight,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Statistics
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Total Files',
                            value: '${_dashboard?.total ?? 0}',
                            icon: Icons.folder_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: 'Uploaded',
                            value: '${_dashboard?.verified ?? 0}',
                            icon: Icons.check_circle_outline,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Storage',
                            value: '${_dashboard?.storage ?? 0} MB',
                            icon: Icons.storage_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: StatCard(
                            title: 'Encryption',
                            value: '100%',
                            icon: Icons.enhanced_encryption_outlined,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Quick Actions
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Emergency Recorder
                    _DashboardActionCard(
                      icon: Icons.videocam_outlined,
                      title: 'Emergency Recorder',
                      subtitle:
                          'Start secure audio and video recording.',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppConstants.recorderRoute,
                      ),
                    ),

                    // Upload Evidence
                    _DashboardActionCard(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Upload Evidence',
                      subtitle:
                          'Start secure evidence upload.',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppConstants.uploadRoute,
                      ),
                    ),

                    // Evidence Vault
                    _DashboardActionCard(
                      icon: Icons.history_outlined,
                      title: 'Evidence Vault',
                      subtitle:
                          'View your encrypted recordings.',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppConstants.historyRoute,
                      ),
                    ),

                    // Verify Evidence
                    _DashboardActionCard(
                      icon: Icons.verified_outlined,
                      title: 'Verify Evidence',
                      subtitle:
                          'Check SHA-256 integrity of a file.',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppConstants.verifyRoute,
                      ),
                    ),

                    // Emergency Contacts
                    _DashboardActionCard(
                      icon: Icons.people_outline,
                      title: 'Emergency Contacts',
                      subtitle:
                          'Manage people who receive emergency alerts.',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const EmergencyContactsScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.accent,
                ),
              ),

              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}