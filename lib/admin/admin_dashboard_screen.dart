import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manage_parking_spots_screen.dart';
import 'manage_users_screen.dart';
import 'manage_notifications_screen.dart';
import 'manage_bookings_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_dialog_helper.dart';
import '../login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Statistics data
  Map<String, dynamic> _stats = {
    'totalSpots': 0,
    'activeSpots': 0,
    'occupiedSpots': 0,
    'totalUsers': 0,
    'activeUsers': 0,
    'activeBookings': 0,
    'todayRevenue': 0.0,
    'monthRevenue': 0.0,
    'totalRevenue': 0.0,
  };

  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load parking spots
      final spotsSnapshot = await _firestore.collection('parking_spots').get();
      final totalSpots = spotsSnapshot.docs.length;
      int activeSpots = 0;
      int occupiedSpots = 0;

      for (var doc in spotsSnapshot.docs) {
        final data = doc.data();
        if (data['isActive'] == true) {
          activeSpots++;
        }
        final total = (data['totalSpots'] ?? 0) as int;
        final available = (data['availableSpots'] ?? 0) as int;
        if (total > 0 && (total - available) > 0) {
          occupiedSpots++;
        }
      }

      // Load users
      final usersSnapshot = await _firestore.collection('users').get();
      final totalUsers = usersSnapshot.docs.length;
      int activeUsers = 0;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        // Check if user is active (logged in within last 30 days or has recent activity)
        final lastLogin = (data['lastLogin'] as Timestamp?)?.toDate();
        final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

        bool isActive = false;
        if (lastLogin != null) {
          final daysSinceLogin = DateTime.now().difference(lastLogin).inDays;
          if (daysSinceLogin <= 30) {
            isActive = true;
          }
        } else if (updatedAt != null) {
          final daysSinceUpdate = DateTime.now().difference(updatedAt).inDays;
          if (daysSinceUpdate <= 30) {
            isActive = true;
          }
        } else {
          // If no login or update time, consider active if created recently
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          if (createdAt != null) {
            final daysSinceCreation = DateTime.now()
                .difference(createdAt)
                .inDays;
            if (daysSinceCreation <= 30) {
              isActive = true;
            }
          } else {
            // Default to active if we can't determine
            isActive = true;
          }
        }

        if (isActive) {
          activeUsers++;
        }
      }

      // Load bookings - get all bookings
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final monthStart = DateTime(now.year, now.month, 1);

      final bookingsSnapshot = await _firestore
          .collection('reservations')
          .get();

      int activeBookings = 0;
      double todayRevenue = 0.0;
      double monthRevenue = 0.0;
      double totalRevenue = 0.0;

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        // Try both totalPrice and price fields
        final price = (data['totalPrice'] ?? data['price'] ?? 0.0).toDouble();
        final status = data['status'] as String? ?? '';

        if (status == 'active' || status == 'confirmed') {
          activeBookings++;
        }

        if (createdAt != null) {
          if (createdAt.isAfter(todayStart) ||
              createdAt.isAtSameMomentAs(todayStart)) {
            todayRevenue += price;
          }
          if (createdAt.isAfter(monthStart) ||
              createdAt.isAtSameMomentAs(monthStart)) {
            monthRevenue += price;
          }
        }

        totalRevenue += price;
      }

      // Load top-up transactions from all users
      // Note: We iterate through users and check their transactions
      try {
        for (var userDoc in usersSnapshot.docs) {
          try {
            final userTransactionsSnapshot = await _firestore
                .collection('transactions')
                .doc(userDoc.id)
                .collection('user_transactions')
                .where('type', isEqualTo: 'Top-up')
                .where('status', isEqualTo: 'completed')
                .get();

            for (var transactionDoc in userTransactionsSnapshot.docs) {
              final data = transactionDoc.data();
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final amount = (data['amount'] ?? 0.0).toDouble();

              if (createdAt != null) {
                if (createdAt.isAfter(todayStart) ||
                    createdAt.isAtSameMomentAs(todayStart)) {
                  todayRevenue += amount;
                }
                if (createdAt.isAfter(monthStart) ||
                    createdAt.isAtSameMomentAs(monthStart)) {
                  monthRevenue += amount;
                }
              }

              totalRevenue += amount;
            }
          } catch (e) {
            // Skip if user has no transactions collection
            continue;
          }
        }
      } catch (e) {
        // If transactions collection doesn't exist or has errors, continue
        print('Error loading transactions: $e');
      }

      // Load recent activities
      final activities = <Map<String, dynamic>>[];

      // Try to load from system_logs first
      try {
        final logsSnapshot = await _firestore
            .collection('system_logs')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get();

        for (var doc in logsSnapshot.docs) {
          final data = doc.data();
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
          final action = data['action'] as String? ?? '';
          final description = data['description'] as String? ?? '';
          final timeAgo = _getTimeAgo(timestamp);

          IconData icon;
          Color color;
          String title;

          if (action.contains('booking') || action.contains('reservation')) {
            icon = Icons.book_rounded;
            color = const Color(0xFF1E88E5);
            title = description.isNotEmpty
                ? description
                : 'New booking created';
          } else if (action.contains('user') || action.contains('register')) {
            icon = Icons.person_add_rounded;
            color = Colors.green;
            title = description.isNotEmpty
                ? description
                : 'New user registered';
          } else if (action.contains('spot') || action.contains('parking')) {
            icon = Icons.local_parking_rounded;
            color = Colors.orange;
            title = description.isNotEmpty
                ? description
                : 'Parking spot updated';
          } else {
            icon = Icons.notifications_rounded;
            color = Colors.grey;
            title = description.isNotEmpty ? description : action;
          }

          activities.add({
            'title': title,
            'time': timeAgo,
            'icon': icon,
            'color': color,
            'timestamp': timestamp,
          });
        }
      } catch (e) {
        // If system_logs doesn't exist or has errors, fall back to bookings and users
      }

      // If no system logs, use recent bookings and users
      if (activities.isEmpty) {
        // Recent bookings
        final recentBookings = await _firestore
            .collection('reservations')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();

        for (var doc in recentBookings.docs) {
          final data = doc.data();
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          final spotName = data['spotName'] ?? 'Unknown Spot';
          final timeAgo = _getTimeAgo(createdAt);

          activities.add({
            'title': 'New booking at $spotName',
            'time': timeAgo,
            'icon': Icons.book_rounded,
            'color': const Color(0xFF1E88E5),
            'timestamp': createdAt,
          });
        }

        // Recent users
        final recentUsers = await _firestore
            .collection('users')
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get();

        for (var doc in recentUsers.docs) {
          final data = doc.data();
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          final name = data['name'] ?? data['displayName'] ?? 'Unknown User';
          final timeAgo = _getTimeAgo(createdAt);

          activities.add({
            'title': 'User $name registered',
            'time': timeAgo,
            'icon': Icons.person_add_rounded,
            'color': Colors.green,
            'timestamp': createdAt,
          });
        }
      }

      // Sort activities by timestamp (most recent first)
      activities.sort((a, b) {
        final aTime = a['timestamp'] as DateTime?;
        final bTime = b['timestamp'] as DateTime?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _stats = {
          'totalSpots': totalSpots,
          'activeSpots': activeSpots,
          'occupiedSpots': occupiedSpots,
          'totalUsers': totalUsers,
          'activeUsers': activeUsers,
          'activeBookings': activeBookings,
          'todayRevenue': todayRevenue,
          'monthRevenue': monthRevenue,
          'totalRevenue': totalRevenue,
        };
        _recentActivities = activities.take(3).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTimeAgo(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildWelcomeCard(),
                          const SizedBox(height: 24),
                          _buildStatisticsGrid(),
                          const SizedBox(height: 24),
                          _buildRevenueCard(),
                          const SizedBox(height: 24),
                          _buildQuickActions(),
                          const SizedBox(height: 24),
                          _buildRecentActivity(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Color(0xFF1E88E5),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'ParkSpot Management',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageNotificationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () => _showLogoutDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back!  👋',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your parking spots and users efficiently',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildQuickStat(
                      _stats['totalSpots']?.toString() ?? '0',
                      'Spots',
                    ),
                    const SizedBox(width: 20),
                    _buildQuickStat(
                      _stats['totalUsers']?.toString() ?? '0',
                      'Users',
                    ),
                    const SizedBox(width: 20),
                    _buildQuickStat(
                      _stats['activeBookings']?.toString() ?? '0',
                      'Active',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildStatisticsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.25,
      children: [
        _buildStatCard(
          'Total Spots',
          (_stats['totalSpots'] ?? 0).toString(),
          Icons.local_parking_rounded,
          const Color(0xFF1E88E5),
          '${_stats['activeSpots'] ?? 0} active',
        ),
        _buildStatCard(
          'Occupied',
          (_stats['occupiedSpots'] ?? 0).toString(),
          Icons.check_circle_rounded,
          Colors.green,
          (_stats['totalSpots'] ?? 0) > 0
              ? '${(((_stats['occupiedSpots'] ?? 0) / (_stats['totalSpots'] ?? 1)) * 100).toStringAsFixed(0)}% full'
              : '0% full',
        ),
        _buildStatCard(
          'Total Users',
          (_stats['totalUsers'] ?? 0).toString(),
          Icons.people_rounded,
          Colors.purple,
          '${_stats['activeUsers'] ?? 0} active',
        ),
        _buildStatCard(
          'Today Revenue',
          'EGP ${((_stats['todayRevenue'] ?? 0.0) as double).toStringAsFixed(0)}',
          Icons.attach_money_rounded,
          Colors.orange,
          'From ${_stats['activeBookings'] ?? 0} bookings',
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Revenue Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'This Month',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E88E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildRevenueItem(
                  'Today',
                  'EGP ${((_stats['todayRevenue'] ?? 0.0) as double).toStringAsFixed(0)}',
                ),
              ),
              Container(width: 1, height: 60, color: Colors.grey[200]),
              Expanded(
                child: _buildRevenueItem(
                  'This Month',
                  'EGP ${((_stats['monthRevenue'] ?? 0.0) as double).toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Revenue',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                'EGP ${((_stats['totalRevenue'] ?? 0.0) as double).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E88E5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueItem(String label, String amount) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildActionCard(
              'Parking Spots',
              Icons.local_parking_rounded,
              const Color(0xFF1E88E5),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageParkingSpotsScreen(),
                  ),
                );
              },
            ),
            _buildActionCard('Users', Icons.people_rounded, Colors.purple, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageUsersScreen(),
                ),
              );
            }),
            _buildActionCard('Bookings', Icons.book_rounded, Colors.green, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageBookingsScreen(),
                ),
              );
            }),
            _buildActionCard(
              'Settings',
              Icons.settings_rounded,
              Colors.grey,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminSettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 16),
          if (_recentActivities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No recent activity',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            ..._recentActivities.map(
              (activity) => _buildActivityItem(
                activity['title'] as String,
                activity['time'] as String,
                activity['icon'] as IconData,
                activity['color'] as Color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    AdminDialogHelper.showConfirmDialog(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      cancelText: 'Cancel',
      icon: Icons.logout_rounded,
      iconColor: Colors.red[600],
      confirmColor: Colors.red[600],
      isDestructive: true,
    ).then((confirmed) {
      if (confirmed == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }
}
