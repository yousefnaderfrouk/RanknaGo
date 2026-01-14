import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ManageNotificationsScreen extends StatefulWidget {
  const ManageNotificationsScreen({super.key});

  @override
  State<ManageNotificationsScreen> createState() =>
      _ManageNotificationsScreenState();
}

class _ManageNotificationsScreenState extends State<ManageNotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _notificationsHistory = [];
  List<Map<String, dynamic>> _availableUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load notifications
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .orderBy('sentAt', descending: true)
          .get();

      final List<Map<String, dynamic>> notifications = [];
      for (var doc in notificationsSnapshot.docs) {
        final data = doc.data();
        final sentAt = (data['sentAt'] as Timestamp?)?.toDate();
        final recipientType = data['recipientType'] ?? 'all';
        final recipientId = data['recipientId'] as String?;

        String sentTo = 'All Users';
        int recipientCount = 0;

        if (recipientType == 'user' && recipientId != null) {
          // Get user name
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(recipientId)
                .get();
            final userData = userDoc.data();
            sentTo = userData?['name']?.toString() ?? 'Unknown User';
            recipientCount = 1;
          } catch (e) {
            sentTo = 'Unknown User';
            recipientCount = 1;
          }
        } else {
          // Count total users for "all" notifications
          try {
            final usersSnapshot = await _firestore.collection('users').get();
            recipientCount = usersSnapshot.docs.length;
          } catch (e) {
            recipientCount = 0;
          }
        }

        notifications.add({
          'id': doc.id,
          'title': data['title'] ?? '',
          'message': data['message'] ?? '',
          'sentTo': sentTo,
          'sentAt': sentAt != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(sentAt)
              : 'N/A',
          'sentAtDate': sentAt,
          'recipientCount': recipientCount,
          'type': data['type'] ?? 'general',
          'recipientType': recipientType,
          'recipientId': recipientId,
        });
      }

      // Load available users
      try {
        // Try to get all users first, then filter in memory
        final usersSnapshot = await _firestore.collection('users').get();

        _availableUsers = usersSnapshot.docs
            .where((doc) {
              final data = doc.data();
              // Only include users that are not blocked
              final status = data['status'] as String?;
              return status != 'blocked';
            })
            .map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['name'] ?? 'Unknown',
                'email': data['email'] ?? '',
              };
            })
            .toList();
      } catch (e) {
        // If loading fails, set empty list
        _availableUsers = [];
        print('Error loading users: $e');
      }

      setState(() {
        _notificationsHistory = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E88E5),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Manage Notifications',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manage Notifications',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadData();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Send Notification Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E88E5).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send Notification',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Send custom notifications to users',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
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
                        child: ElevatedButton.icon(
                          onPressed: _showSendToAllDialog,
                          icon: const Icon(Icons.group_rounded),
                          label: const Text('Send to All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1E88E5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showSendToUserDialog,
                          icon: const Icon(Icons.person_rounded),
                          label: const Text('Send to User'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Statistics
            Row(
              children: [
                Expanded(
                  child: _buildNotificationStatCard(
                    'Total Sent',
                    '${_notificationsHistory.length}',
                    Icons.send_rounded,
                    const Color(0xFF1E88E5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNotificationStatCard(
                    'Recipients',
                    '${_notificationsHistory.fold(0, (sum, item) => sum + (item['recipientCount'] as int))}',
                    Icons.people_rounded,
                    Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // History Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showClearHistoryDialog(),
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Notifications List
            if (_notificationsHistory.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
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
                child: Column(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 60,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications sent yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              ..._notificationsHistory.map((notification) {
                return _buildNotificationHistoryCard(notification);
              }),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildNotificationHistoryCard(Map<String, dynamic> notification) {
    final isToAll = notification['sentTo'] == 'All Users';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isToAll
                        ? const Color(0xFF1E88E5).withOpacity(0.1)
                        : Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isToAll ? Icons.group_rounded : Icons.person_rounded,
                    color: isToAll ? const Color(0xFF1E88E5) : Colors.purple,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            notification['sentAt'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isToAll
                        ? const Color(0xFF1E88E5).withOpacity(0.1)
                        : Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${notification['recipientCount']} ${isToAll ? 'Users' : 'User'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isToAll ? const Color(0xFF1E88E5) : Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              notification['message'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isToAll ? Icons.public_rounded : Icons.person_rounded,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sent to: ${notification['sentTo']}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSendToAllDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.group_rounded, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Send to All Users'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF1E88E5),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FutureBuilder<int>(
                        future: _getTotalUsersCount(),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return Text(
                            'This will send notification to all $count users',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E88E5),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Notification Title',
                  hintText: 'e.g., Special Offer!',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                decoration: InputDecoration(
                  labelText: 'Message',
                  hintText: 'Write your message here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.message_rounded),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                maxLength: 200,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (titleController.text.isEmpty ||
                  messageController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                final totalUsers = await _getTotalUsersCount();
                final currentUser = _auth.currentUser;

                final notificationData = {
                  'title': titleController.text,
                  'message': messageController.text,
                  'type': 'general',
                  'recipientType': 'all',
                  'recipientId': null,
                  'sentBy': currentUser?.uid ?? 'admin',
                  'sentAt': FieldValue.serverTimestamp(),
                  'readBy': [],
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                await _firestore
                    .collection('notifications')
                    .add(notificationData);

                Navigator.pop(context);

                // Reload data
                await _loadData();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Notification sent to $totalUsers users!',
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green[400],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error sending notification: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send to All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showSendToUserDialog() {
    // Check if users are still loading
    if (_isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for users to load...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_availableUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No users available. Please wait for users to load.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final ValueNotifier<String?> selectedUserIdNotifier =
        ValueNotifier<String?>(null);
    final ValueNotifier<String?> selectedUserNameNotifier =
        ValueNotifier<String?>('User');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return ValueListenableBuilder<String?>(
            valueListenable: selectedUserIdNotifier,
            builder: (context, selectedUserId, _) {
              return ValueListenableBuilder<String?>(
                valueListenable: selectedUserNameNotifier,
                builder: (context, selectedUserName, __) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Row(
                      children: [
                        Icon(Icons.person_rounded, color: Color(0xFF1E88E5)),
                        SizedBox(width: 12),
                        Expanded(child: Text('Send to Specific User')),
                      ],
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select User',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: selectedUserId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                hintText: 'Choose a user',
                                prefixIcon: Icon(Icons.person_search_rounded),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                isDense: true,
                              ),
                              selectedItemBuilder: (BuildContext context) {
                                return _availableUsers.map((user) {
                                  final userId = user['id'] as String? ?? '';
                                  final userName =
                                      user['name'] as String? ?? 'Unknown';
                                  return DropdownMenuItem<String>(
                                    value: userId,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF1E88E5),
                                                Color(0xFF1976D2),
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              userName.isNotEmpty
                                                  ? userName[0].toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            userName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList();
                              },
                              items: _availableUsers.map((user) {
                                final userId = user['id'] as String? ?? '';
                                final userName =
                                    user['name'] as String? ?? 'Unknown';
                                final userEmail =
                                    user['email'] as String? ?? '';
                                return DropdownMenuItem<String>(
                                  value: userId,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 35,
                                        height: 35,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF1E88E5),
                                              Color(0xFF1976D2),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            userName.isNotEmpty
                                                ? userName[0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              userName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              userEmail,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  selectedUserIdNotifier.value = value;
                                  try {
                                    final selectedUser = _availableUsers
                                        .firstWhere(
                                          (user) => user['id'] == value,
                                        );
                                    selectedUserNameNotifier.value =
                                        selectedUser['name']?.toString() ??
                                        'User';
                                  } catch (e) {
                                    selectedUserNameNotifier.value = 'User';
                                  }
                                  setDialogState(() {});
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: titleController,
                            decoration: InputDecoration(
                              labelText: 'Notification Title',
                              hintText: 'e.g., Important Update',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.title_rounded),
                            ),
                            maxLength: 50,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: messageController,
                            decoration: InputDecoration(
                              labelText: 'Message',
                              hintText: 'Write your message here...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.message_rounded),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 4,
                            maxLength: 200,
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          selectedUserIdNotifier.dispose();
                          selectedUserNameNotifier.dispose();
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton.icon(
                        onPressed:
                            selectedUserId == null ||
                                selectedUserId.isEmpty ||
                                titleController.text.trim().isEmpty ||
                                messageController.text.trim().isEmpty
                            ? null
                            : () async {
                                try {
                                  final currentUser = _auth.currentUser;
                                  if (currentUser == null) {
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'User not authenticated',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  final currentSelectedUserId = selectedUserId;
                                  final currentSelectedUserName =
                                      selectedUserName;
                                  if (currentSelectedUserId.isEmpty) {
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please select a user'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  // Close dialog first
                                  if (mounted) {
                                    Navigator.pop(context);
                                  }

                                  // Show loading
                                  if (mounted) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }

                                  final notificationData = {
                                    'title': titleController.text.trim(),
                                    'message': messageController.text.trim(),
                                    'type': 'general',
                                    'recipientType': 'user',
                                    'recipientId': currentSelectedUserId,
                                    'sentBy': currentUser.uid,
                                    'sentAt': FieldValue.serverTimestamp(),
                                    'readBy': [],
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  };

                                  await _firestore
                                      .collection('notifications')
                                      .add(notificationData);

                                  // Close loading
                                  if (mounted) {
                                    Navigator.pop(context);
                                  }

                                  // Reload data
                                  await _loadData();

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_outline,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Notification sent to ${currentSelectedUserName ?? 'user'}!',
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor: Colors.green[400],
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  // Close loading if still open
                                  if (mounted) {
                                    try {
                                      Navigator.pop(context);
                                    } catch (_) {}
                                  }

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                } finally {
                                  // Dispose controllers and notifiers
                                  titleController.dispose();
                                  messageController.dispose();
                                  selectedUserIdNotifier.dispose();
                                  selectedUserNameNotifier.dispose();
                                }
                              },
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Send'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<int> _getTotalUsersCount() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      return usersSnapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Delete all notifications
                final notificationsSnapshot = await _firestore
                    .collection('notifications')
                    .get();

                final batch = _firestore.batch();
                for (var doc in notificationsSnapshot.docs) {
                  batch.delete(doc.reference);
                }
                await batch.commit();

                // Reload data
                await _loadData();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(child: Text('All notifications deleted')),
                        ],
                      ),
                      backgroundColor: Colors.orange,
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
                      content: Text('Error deleting notifications: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
}
