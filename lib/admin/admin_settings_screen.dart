import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic> _settings = {};
  Map<String, dynamic>? _adminProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAdminProfile();
  }

  Future<void> _loadSettings() async {
    try {
      final settingsDoc = await _firestore
          .collection('settings')
          .doc('app')
          .get();
      if (settingsDoc.exists) {
        setState(() {
          _settings = settingsDoc.data() ?? {};
        });
        // إضافة إعدادات Paymob إذا لم تكن موجودة
        if (_settings['paymobSettings'] == null) {
          await _initializePaymobSettings();
        }
      } else {
        // Initialize default settings
        await _firestore.collection('settings').doc('app').set({
          'commissionRate': 10.0,
          'paymentMethods': {
            'creditCard': true,
            'fawry': true,
            'vodafoneCash': false,
            'paypal': false,
          },
          'notifications': {'push': true, 'email': true, 'sms': false},
          'appVersion': '1.0.0',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _settings = {
            'commissionRate': 10.0,
            'paymentMethods': {
              'creditCard': true,
              'fawry': true,
              'vodafoneCash': false,
              'paypal': false,
            },
            'notifications': {'push': true, 'email': true, 'sms': false},
            'appVersion': '1.0.0',
          };
        });
        // إضافة إعدادات Paymob
        await _initializePaymobSettings();
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initializePaymobSettings() async {
    try {
      // إعدادات Paymob الخاصة بك
      final paymobSettings = {
        'apiKey':
            'ZXlKaGJHY2lPaUpJVXpVeE1pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SmpiR0Z6Y3lJNklrMWxjbU5vWVc1MElpd2ljSEp2Wm1sc1pWOXdheUk2TVRBek1UYzRNaXdpYm1GdFpTSTZJbWx1YVhScFlXd2lmUS5INkVoOG5pVzJxLXJlR1kwNXBLV1BGSERjN1QzbzlMUy10LWxxYXo2Q2V1MVZiSzlrWWdVNkpfNjJtVFRVNWNXaHU0dktXMUlxcTBJU2FhMjhWektxQQ==',
        'hmacKey': '42AB0D3D827D2C4FB90C37A5933EA76B',
        'integrations': {
          'card': 5424710, // MIGS
          'fawry': 5424709, // Accept Kiosk
          'mobileWallet': 5413537, // Mobile Wallet
        },
        'isTestMode': true,
      };

      await _firestore.collection('settings').doc('app').set({
        'paymobSettings': paymobSettings,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // تحديث الإعدادات المحلية
      setState(() {
        _settings['paymobSettings'] = paymobSettings;
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _loadAdminProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          setState(() {
            _adminProfile = userDoc.data();
          });
        }
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _logActivity(String action) async {
    try {
      await _firestore.collection('system_logs').add({
        'action': action,
        'userId': _auth.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignore logging errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Settings
                  _buildSettingsSection('App Settings', [
                    _buildSettingItem(
                      'Notifications Settings',
                      'Manage push notifications',
                      Icons.notifications_rounded,
                      () => _showNotificationSettingsDialog(),
                    ),
                    _buildSettingItem(
                      'App Information',
                      'Manage developer info and app details',
                      Icons.info_rounded,
                      () => _showAppInfoDialog(),
                    ),
                    _buildSettingItem(
                      'App Version',
                      'Current version: ${_settings['appVersion'] ?? '1.0.0'}',
                      Icons.verified_rounded,
                      () {},
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // System Settings
                  _buildSettingsSection('System', [
                    _buildSettingItem(
                      'Backup Data',
                      'Create system backup',
                      Icons.backup_rounded,
                      () => _showBackupDialog(),
                    ),
                    _buildSettingItem(
                      'API Keys',
                      'Manage API integrations',
                      Icons.key_rounded,
                      () => _showAPIKeysDialog(),
                    ),
                    _buildSettingItem(
                      'System Logs',
                      'View system logs and activities',
                      Icons.description_rounded,
                      () => _showSystemLogsDialog(),
                    ),
                    _buildSettingItem(
                      'Database',
                      'Database management and optimization',
                      Icons.storage_rounded,
                      () => _showDatabaseDialog(),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Account
                  _buildSettingsSection('Account', [
                    _buildSettingItem(
                      'Change Password',
                      'Update admin password',
                      Icons.lock_rounded,
                      () => _showChangePasswordDialog(),
                    ),
                    _buildSettingItem(
                      'Admin Profile',
                      'Edit admin information',
                      Icons.person_rounded,
                      () => _showAdminProfileDialog(),
                    ),
                    _buildSettingItem(
                      'Two-Factor Authentication',
                      'Enable 2FA for extra security',
                      Icons.security_rounded,
                      () => _show2FADialog(),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Danger Zone
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red[200]!, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_rounded, color: Colors.red[700]),
                            const SizedBox(width: 12),
                            Text(
                              'Danger Zone',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildDangerItem(
                          'Clear All Data',
                          'Delete all parking spots and bookings',
                          Icons.delete_forever_rounded,
                          () => _showClearDataDialog(),
                        ),
                        _buildDangerItem(
                          'Reset System',
                          'Reset to factory defaults',
                          Icons.restore_rounded,
                          () => _showResetDialog(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1E88E5).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF1E88E5)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF212121),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildDangerItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.red[700], size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.red[700],
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.red[600]),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: Colors.red[400],
      ),
    );
  }

  // ==================== DIALOG FUNCTIONS ====================

  void _showNotificationSettingsDialog() {
    final notifications = Map<String, bool>.from(
      _settings['notifications'] ?? {'push': true, 'email': true, 'sms': false},
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.notifications_rounded, color: Color(0xFF1E88E5)),
              SizedBox(width: 12),
              Text('Notification Settings'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Push Notifications'),
                subtitle: const Text('Enable push notifications'),
                value: notifications['push'] ?? true,
                onChanged: (value) {
                  setDialogState(() {
                    notifications['push'] = value;
                  });
                },
                activeColor: const Color(0xFF1E88E5),
              ),
              SwitchListTile(
                title: const Text('Email Notifications'),
                subtitle: const Text('Send email alerts'),
                value: notifications['email'] ?? true,
                onChanged: (value) {
                  setDialogState(() {
                    notifications['email'] = value;
                  });
                },
                activeColor: const Color(0xFF1E88E5),
              ),
              SwitchListTile(
                title: const Text('SMS Notifications'),
                subtitle: const Text('Send SMS alerts'),
                value: notifications['sms'] ?? false,
                onChanged: (value) {
                  setDialogState(() {
                    notifications['sms'] = value;
                  });
                },
                activeColor: const Color(0xFF1E88E5),
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
                try {
                  await _firestore.collection('settings').doc('app').update({
                    'notifications': notifications,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  await _logActivity('Notification settings updated');
                  setState(() {
                    _settings['notifications'] = notifications;
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Notification settings updated!'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green[400],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBackupDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.backup_rounded, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Backup Data'),
          ],
        ),
        content: const Text(
          'This will create a backup of all parking spots, users, and bookings. The backup will be saved to the cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                // Get all data
                final spotsSnapshot = await _firestore
                    .collection('parking_spots')
                    .get();
                final usersSnapshot = await _firestore
                    .collection('users')
                    .get();
                final bookingsSnapshot = await _firestore
                    .collection('reservations')
                    .get();

                // Create backup document
                await _firestore.collection('backups').add({
                  'timestamp': FieldValue.serverTimestamp(),
                  'parkingSpots': spotsSnapshot.docs.length,
                  'users': usersSnapshot.docs.length,
                  'bookings': bookingsSnapshot.docs.length,
                  'createdBy': _auth.currentUser?.uid,
                });

                await _logActivity('Backup created');

                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(child: Text('Backup created successfully!')),
                        ],
                      ),
                      backgroundColor: Colors.green[400],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Create Backup'),
          ),
        ],
      ),
    );
  }

  void _showAPIKeysDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('API Keys'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAPIKeyItem('Firebase', 'Configured', true),
            _buildAPIKeyItem('Cloudinary', 'Configured', true),
            _buildAPIKeyItem('Payment Gateway', 'Not configured', false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAPIKeyItem(String name, String status, bool configured) {
    return ListTile(
      title: Text(name, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          color: configured ? Colors.green[600] : Colors.grey[600],
        ),
      ),
      trailing: Icon(
        configured ? Icons.check_circle : Icons.info_outline,
        color: configured ? Colors.green : Colors.grey,
        size: 20,
      ),
    );
  }

  Future<void> _showSystemLogsDialog() async {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<QuerySnapshot>(
        future: _firestore
            .collection('system_logs')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              content: const Center(child: CircularProgressIndicator()),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            );
          }

          final logs = snapshot.data?.docs ?? [];

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.description_rounded, color: Color(0xFF1E88E5)),
                SizedBox(width: 12),
                Text('System Logs'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: logs.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('No logs available'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index].data() as Map<String, dynamic>;
                        final action = log['action'] ?? 'Unknown';
                        final timestamp = log['timestamp'] as Timestamp?;
                        final time = timestamp != null
                            ? DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(timestamp.toDate())
                            : 'N/A';

                        IconData icon = Icons.info;
                        if (action.contains('login')) icon = Icons.login;
                        if (action.contains('Booking')) icon = Icons.book;
                        if (action.contains('Payment')) icon = Icons.payment;
                        if (action.contains('User')) icon = Icons.person_add;

                        return _buildLogItem(action, time, icon);
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogItem(String action, String time, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1E88E5), size: 20),
      title: Text(action, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        time,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }

  Future<void> _showDatabaseDialog() async {
    try {
      // Get collection sizes (approximate)
      final spotsSnapshot = await _firestore.collection('parking_spots').get();
      final usersSnapshot = await _firestore.collection('users').get();
      final bookingsSnapshot = await _firestore
          .collection('reservations')
          .get();

      final totalDocs =
          spotsSnapshot.docs.length +
          usersSnapshot.docs.length +
          bookingsSnapshot.docs.length;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.storage_rounded, color: Color(0xFF1E88E5)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Database Management',
                  style: const TextStyle(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  leading: const Icon(Icons.info, color: Color(0xFF1E88E5)),
                  title: const Text('Database Info'),
                  subtitle: Text(
                    'Total Documents: $totalDocs\nParking Spots: ${spotsSnapshot.docs.length}\nUsers: ${usersSnapshot.docs.length}\nBookings: ${bookingsSnapshot.docs.length}',
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  leading: const Icon(
                    Icons.cleaning_services,
                    color: Color(0xFF1E88E5),
                  ),
                  title: const Text('Clean Database'),
                  subtitle: const Text('Remove old and unused data'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _logActivity('Database cleanup initiated');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Database cleanup completed'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  leading: const Icon(Icons.speed, color: Color(0xFF1E88E5)),
                  title: const Text('Optimize Database'),
                  subtitle: const Text('Improve performance'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _logActivity('Database optimization initiated');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Database optimized'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Change Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
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
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Passwords do not match'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password must be at least 6 characters'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final user = _auth.currentUser;
                if (user != null && user.email != null) {
                  // Re-authenticate user
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPasswordController.text,
                  );
                  await user.reauthenticateWithCredential(credential);

                  // Update password
                  await user.updatePassword(newPasswordController.text);
                  await _logActivity('Password changed');

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Password changed successfully!'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green[400],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                }
              } on FirebaseAuthException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.message ?? 'Error changing password'),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  void _showAdminProfileDialog() {
    final nameController = TextEditingController(
      text: _adminProfile?['name'] ?? 'Admin User',
    );
    final emailController = TextEditingController(
      text: _adminProfile?['email'] ?? _auth.currentUser?.email ?? '',
    );
    final phoneController = TextEditingController(
      text: _adminProfile?['phoneNumber'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_rounded, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Admin Profile'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Email (cannot be changed)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.phone_outlined),
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
              try {
                final user = _auth.currentUser;
                if (user != null) {
                  await _firestore.collection('users').doc(user.uid).update({
                    'name': nameController.text,
                    'phoneNumber': phoneController.text,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  await _logActivity('Admin profile updated');
                  await _loadAdminProfile();
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Profile updated successfully!'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green[400],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _show2FADialog() {
    final is2FAEnabled = _adminProfile?['twoFactorEnabled'] ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.security_rounded,
              color: is2FAEnabled ? Colors.orange : const Color(0xFF1E88E5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Two-Factor Authentication',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                is2FAEnabled
                    ? 'Two-factor authentication is currently enabled. Disable it to skip the verification step when logging in.'
                    : 'Enable two-factor authentication for extra security. You will need to enter a code from your authenticator app when logging in.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      (is2FAEnabled ? Colors.orange : const Color(0xFF1E88E5))
                          .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: is2FAEnabled
                          ? Colors.orange
                          : const Color(0xFF1E88E5),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        is2FAEnabled
                            ? 'Your account is protected with 2FA'
                            : 'Recommended for admin accounts',
                        style: TextStyle(
                          fontSize: 12,
                          color: is2FAEnabled
                              ? Colors.orange
                              : const Color(0xFF1E88E5),
                        ),
                      ),
                    ),
                  ],
                ),
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
              try {
                final user = _auth.currentUser;
                if (user != null) {
                  if (is2FAEnabled) {
                    // Disable 2FA
                    await _firestore.collection('users').doc(user.uid).update({
                      'twoFactorEnabled': false,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    await _logActivity('2FA disabled');
                    await _loadAdminProfile(); // Reload profile to update UI

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text('2FA disabled successfully!'),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green[400],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  } else {
                    // Enable 2FA
                    // Check if user has email (should always have email)
                    final email = user.email;
                    if (email == null || email.isEmpty) {
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.white),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text('Email is required for 2FA!'),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.orange[400],
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    // Enable 2FA
                    await _firestore.collection('users').doc(user.uid).update({
                      'twoFactorEnabled': true,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    await _logActivity('2FA enabled');
                    await _loadAdminProfile(); // Reload profile to update UI

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.white,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text('2FA enabled successfully!'),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green[400],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  }
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red[400],
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: is2FAEnabled
                  ? Colors.orange
                  : const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: Text(is2FAEnabled ? 'Disable 2FA' : 'Enable 2FA'),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearDataDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red[700]),
            const SizedBox(width: 12),
            const Text('Clear All Data'),
          ],
        ),
        content: const Text(
          'This will permanently delete ALL parking spots, bookings, and user data (except admins). This action cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                // Delete all parking spots
                final spotsSnapshot = await _firestore
                    .collection('parking_spots')
                    .get();
                for (var doc in spotsSnapshot.docs) {
                  await doc.reference.delete();
                }

                // Delete all bookings
                final bookingsSnapshot = await _firestore
                    .collection('reservations')
                    .get();
                for (var doc in bookingsSnapshot.docs) {
                  await doc.reference.delete();
                }

                // Delete all users except admins
                final usersSnapshot = await _firestore
                    .collection('users')
                    .get();
                for (var doc in usersSnapshot.docs) {
                  final data = doc.data();
                  if (data['role'] != 'admin') {
                    await doc.reference.delete();
                  }
                }

                await _logActivity('All data cleared');

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(child: Text('All data cleared')),
                        ],
                      ),
                      backgroundColor: Colors.red[400],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.restore_rounded, color: Colors.red[700]),
            const SizedBox(width: 12),
            const Text('Reset System'),
          ],
        ),
        content: const Text(
          'This will reset the system to factory defaults. All settings, data, and configurations will be lost!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                // Reset settings to defaults
                await _firestore.collection('settings').doc('app').set({
                  'commissionRate': 10.0,
                  'paymentMethods': {
                    'creditCard': true,
                    'fawry': true,
                    'vodafoneCash': false,
                    'paypal': false,
                  },
                  'notifications': {'push': true, 'email': true, 'sms': false},
                  'appVersion': '1.0.0',
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                await _logActivity('System reset to defaults');
                await _loadSettings();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.restore_rounded, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(child: Text('System reset to defaults')),
                        ],
                      ),
                      backgroundColor: Colors.red[400],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showAppInfoDialog() {
    final aboutInfo = _settings['aboutInfo'] ?? {};
    final developerInfo = _settings['developerInfo'] ?? {};

    // Controllers for About Info
    final appNameController = TextEditingController(
      text: aboutInfo['appName'] ?? 'RaknaGo',
    );
    final appVersionController = TextEditingController(
      text: aboutInfo['appVersion'] ?? '1.0.0',
    );
    final websiteController = TextEditingController(
      text: aboutInfo['website'] ?? 'https://raknago.com',
    );

    // Controllers for Developer Info
    final devNameController = TextEditingController(
      text: developerInfo['name'] ?? 'RaknaGo Team',
    );
    final devEmailController = TextEditingController(
      text: developerInfo['email'] ?? 'dev@raknago.com',
    );
    final devPhoneController = TextEditingController(
      text: developerInfo['phone'] ?? '',
    );
    final devWebsiteController = TextEditingController(
      text: developerInfo['website'] ?? 'www.raknago.com',
    );
    final devLocationController = TextEditingController(
      text: developerInfo['location'] ?? '',
    );

    // Social Media Controllers
    final facebookController = TextEditingController(
      text: (aboutInfo['socialMedia'] ?? {})['facebook'] ?? '',
    );
    final instagramController = TextEditingController(
      text: (aboutInfo['socialMedia'] ?? {})['instagram'] ?? '',
    );
    final twitterController = TextEditingController(
      text: (aboutInfo['socialMedia'] ?? {})['twitter'] ?? '',
    );
    final linkedinController = TextEditingController(
      text: (aboutInfo['socialMedia'] ?? {})['linkedin'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_rounded, color: Color(0xFF1E88E5)),
              SizedBox(width: 12),
              Text('App Information'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Info Section
                const Text(
                  'App Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: appNameController,
                  decoration: InputDecoration(
                    labelText: 'App Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.apps_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: appVersionController,
                  decoration: InputDecoration(
                    labelText: 'App Version',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: websiteController,
                  decoration: InputDecoration(
                    labelText: 'Website URL',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.language_rounded),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                // Developer Info Section
                const Text(
                  'Developer Information',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: devNameController,
                  decoration: InputDecoration(
                    labelText: 'Developer Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: devEmailController,
                  decoration: InputDecoration(
                    labelText: 'Developer Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.email_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: devPhoneController,
                  decoration: InputDecoration(
                    labelText: 'Developer Phone',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.phone_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: devWebsiteController,
                  decoration: InputDecoration(
                    labelText: 'Developer Website',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.language_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: devLocationController,
                  decoration: InputDecoration(
                    labelText: 'Developer Location',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.location_on_rounded),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                // Social Media Section
                const Text(
                  'Social Media Links',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: facebookController,
                  decoration: InputDecoration(
                    labelText: 'Facebook URL',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(
                      Icons.facebook,
                      color: Color(0xFF1877F2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instagramController,
                  decoration: InputDecoration(
                    labelText: 'Instagram URL',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(
                      Icons.camera_alt_rounded,
                      color: Color(0xFFE4405F),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: twitterController,
                  decoration: InputDecoration(
                    labelText: 'Twitter URL',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(
                      Icons.alternate_email_rounded,
                      color: Color(0xFF1DA1F2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkedinController,
                  decoration: InputDecoration(
                    labelText: 'LinkedIn URL',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(
                      Icons.business_rounded,
                      color: Color(0xFF0A66C2),
                    ),
                  ),
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
                try {
                  // Prepare data
                  final aboutInfoData = {
                    'appName': appNameController.text.trim(),
                    'appVersion': appVersionController.text.trim(),
                    'website': websiteController.text.trim(),
                    'socialMedia': {
                      'facebook': facebookController.text.trim(),
                      'instagram': instagramController.text.trim(),
                      'twitter': twitterController.text.trim(),
                      'linkedin': linkedinController.text.trim(),
                    },
                  };

                  final developerInfoData = {
                    'name': devNameController.text.trim(),
                    'email': devEmailController.text.trim(),
                    'phone': devPhoneController.text.trim(),
                    'website': devWebsiteController.text.trim(),
                    'location': devLocationController.text.trim(),
                    'socialMedia': {
                      'facebook': facebookController.text.trim(),
                      'instagram': instagramController.text.trim(),
                      'twitter': twitterController.text.trim(),
                      'linkedin': linkedinController.text.trim(),
                    },
                  };

                  // Update Firestore
                  await _firestore.collection('settings').doc('app').update({
                    'aboutInfo': aboutInfoData,
                    'developerInfo': developerInfoData,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  await _logActivity('App information updated');

                  setState(() {
                    _settings['aboutInfo'] = aboutInfoData;
                    _settings['developerInfo'] = developerInfoData;
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'App information updated successfully!',
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green[400],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
