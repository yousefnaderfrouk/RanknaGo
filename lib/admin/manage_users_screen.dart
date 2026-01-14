import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'admin_dialog_helper.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = '';
  String _filterStatus = 'All';
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final List<Map<String, dynamic>> users = [];

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();

        // Count bookings for this user
        final bookingsSnapshot = await _firestore
            .collection('reservations')
            .where('userId', isEqualTo: doc.id)
            .get();

        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

        users.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'phone': data['phoneNumber'] ?? 'N/A',
          'totalBookings': bookingsSnapshot.docs.length,
          'status': data['status'] ?? 'active',
          'joinedDate': createdAt != null
              ? DateFormat('yyyy-MM-dd').format(createdAt)
              : 'N/A',
          'lastActive': updatedAt != null
              ? DateFormat('yyyy-MM-dd').format(updatedAt)
              : 'N/A',
        });
      }

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    return _users.where((user) {
      final matchesSearch =
          user['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          user['email'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      final matchesStatus =
          _filterStatus == 'All' ||
          (_filterStatus == 'Active' && user['status'] != 'blocked') ||
          (_filterStatus == 'Blocked' && user['status'] == 'blocked');

      return matchesSearch && matchesStatus;
    }).toList();
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
        title: const Text(
          'Manage Users',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Search and Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search users.. .',
                      prefixIcon: Icon(Icons.search, color: Color(0xFF1E88E5)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFilterChip('All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Active'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Blocked'),
                  ],
                ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_rounded,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      return _buildUserCard(_filteredUsers[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterStatus == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E88E5) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isActive = user['status'] == 'active';

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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isActive
                          ? [const Color(0xFF1E88E5), const Color(0xFF1976D2)]
                          : [Colors.grey[400]!, Colors.grey[500]!],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user['name'].toString()[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Blocked',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user['email'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user['phone'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[50]),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${user['totalBookings']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bookings',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        user['joinedDate'],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Joined',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        user['lastActive'],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Last Active',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _viewUserDetails(user),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _toggleUserStatus(user),
                    icon: Icon(
                      isActive
                          ? Icons.block_rounded
                          : Icons.check_circle_rounded,
                      size: 18,
                    ),
                    label: Text(isActive ? 'Block' : 'Unblock'),
                    style: TextButton.styleFrom(
                      foregroundColor: isActive ? Colors.red : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showAddBalanceDialog(user),
                    icon: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 18,
                    ),
                    label: const Text('Balance'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddBalanceDialog(Map<String, dynamic> user) async {
    final amountController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: Color(0xFF1E88E5),
              ),
              SizedBox(width: 12),
              Text('Add User Balance'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User: ${user['name'] ?? 'Unknown'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Email: ${user['email'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Amount Input
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount (EGP)',
                    hintText: 'Enter amount',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                // Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFF1E88E5),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This amount will be added to the user\'s wallet balance',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E88E5),
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
              onPressed: () {
                Navigator.pop(context);
                // Controller will be disposed automatically when dialog closes
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      try {
                        final amountText = amountController.text.trim();

                        if (amountText.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter amount'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final amount = double.tryParse(amountText);
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid amount'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setDialogState(() => isLoading = true);

                        // Add balance
                        await _addBalanceToUser(user['id'], amount, user);

                        if (context.mounted) {
                          Navigator.pop(context);
                          // Controller will be disposed automatically when dialog closes
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
                                      'Added EGP ${amount.toStringAsFixed(2)} to ${user['name']}\'s wallet',
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
                        setDialogState(() => isLoading = false);
                        if (context.mounted) {
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
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add Balance'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addBalanceToUser(
    String userId,
    double amount,
    Map<String, dynamic> userData,
  ) async {
    try {
      // Get current wallet balance
      final walletDoc = await _firestore
          .collection('wallets')
          .doc(userId)
          .get();

      double currentBalance = 0;
      if (walletDoc.exists) {
        currentBalance = (walletDoc.data()?['balance'] ?? 0).toDouble();
      }

      // Update wallet balance - use update() if exists, set() if not
      try {
        if (walletDoc.exists) {
          await _firestore.collection('wallets').doc(userId).update({
            'balance': currentBalance + amount,
            'lastUpdated': FieldValue.serverTimestamp(),
            'userName': userData['name'] ?? 'User',
            'cardNumber': '**** **** **99',
          });
        } else {
          await _firestore.collection('wallets').doc(userId).set({
            'balance': currentBalance + amount,
            'lastUpdated': FieldValue.serverTimestamp(),
            'userName': userData['name'] ?? 'User',
            'cardNumber': '**** **** **99',
          });
        }
      } catch (walletError) {
        print('Wallet update error: $walletError');
        // Try alternative approach with set and merge
        await _firestore.collection('wallets').doc(userId).set({
          'balance': currentBalance + amount,
          'lastUpdated': FieldValue.serverTimestamp(),
          'userName': userData['name'] ?? 'User',
          'cardNumber': '**** **** **99',
        }, SetOptions(merge: true));
      }

      // Get admin profile
      Map<String, dynamic>? adminProfile;
      final adminUser = _auth.currentUser;
      if (adminUser != null) {
        final adminDoc = await _firestore
            .collection('users')
            .doc(adminUser.uid)
            .get();
        if (adminDoc.exists) {
          adminProfile = adminDoc.data();
        }
      }

      // Create transaction record
      await _firestore
          .collection('transactions')
          .doc(userId)
          .collection('user_transactions')
          .add({
            'type': 'Top-up',
            'amount': amount,
            'paymentMethod': 'Admin Credit',
            'paymentMethodId': 'admin',
            'status': 'completed',
            'createdAt': FieldValue.serverTimestamp(),
            'description': 'Balance added by admin',
            'adminId': _auth.currentUser?.uid,
            'adminName': adminProfile?['name'] ?? 'Admin',
          });
    } catch (e) {
      throw Exception('Failed to add balance: $e');
    }
  }

  void _viewUserDetails(Map<String, dynamic> user) {
    try {
      // Extract and validate user data safely
      final userName = (user['name']?.toString() ?? 'Unknown').trim();
      final userEmail = (user['email']?.toString() ?? 'N/A').trim();
      final userPhone = (user['phone']?.toString() ?? 'N/A').trim();
      final totalBookings = user['totalBookings'] ?? 0;
      final joinedDate = (user['joinedDate']?.toString() ?? 'N/A').trim();
      final lastActive = (user['lastActive']?.toString() ?? 'N/A').trim();
      final status = user['status']?.toString() ?? 'active';
      final isActive = status == 'active';

      // Get first letter safely
      String firstLetter = '?';
      if (userName.isNotEmpty) {
        try {
          firstLetter = userName[0].toUpperCase();
        } catch (e) {
          firstLetter = '?';
        }
      }

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Color(0xFF1E88E5),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'User Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212121),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.grey[600],
                          size: 22,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    firstLetter,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (isActive
                                                    ? Colors.green
                                                    : Colors.red)
                                                .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isActive ? 'Active User' : 'Blocked',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isActive
                                              ? Colors.green[100]
                                              : Colors.red[100],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // User Details
                        _buildUserDetailRow(
                          'Email',
                          userEmail,
                          Icons.email_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildUserDetailRow(
                          'Phone',
                          userPhone,
                          Icons.phone_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildUserDetailRow(
                          'Total Bookings',
                          totalBookings.toString(),
                          Icons.book_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildUserDetailRow(
                          'Joined Date',
                          joinedDate,
                          Icons.calendar_today_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildUserDetailRow(
                          'Last Active',
                          lastActive,
                          Icons.access_time_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error showing user details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUserDetailRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1E88E5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF212121),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final isActive = user['status'] != 'blocked';
    AdminDialogHelper.showConfirmDialog(
      context: context,
      title: isActive ? 'Block User' : 'Unblock User',
      message: isActive
          ? 'Are you sure you want to block "${user['name']}"? They will not be able to make new bookings.'
          : 'Are you sure you want to unblock "${user['name']}"? They will be able to use the app again.',
      confirmText: isActive ? 'Block' : 'Unblock',
      cancelText: 'Cancel',
      icon: isActive ? Icons.block_rounded : Icons.check_circle_rounded,
      iconColor: isActive ? Colors.orange[600] : Colors.green[600],
      confirmColor: isActive ? Colors.orange[600] : Colors.green[600],
      isDestructive: isActive,
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await _firestore.collection('users').doc(user['id']).update({
            'status': isActive ? 'blocked' : 'active',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          setState(() {
            user['status'] = isActive ? 'blocked' : 'active';
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      isActive
                          ? Icons.block_rounded
                          : Icons.check_circle_outline,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isActive
                            ? 'User blocked successfully'
                            : 'User unblocked successfully',
                      ),
                    ),
                  ],
                ),
                backgroundColor: isActive
                    ? Colors.orange[400]
                    : Colors.green[400],
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
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    });
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    AdminDialogHelper.showConfirmDialog(
      context: context,
      title: 'Delete User',
      message:
          'Are you sure you want to delete "${user['name']}"? This will permanently delete their account and all booking history.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      icon: Icons.delete_forever_rounded,
      iconColor: Colors.red[600],
      confirmColor: Colors.red[600],
      isDestructive: true,
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          // Delete user's reservations first
          final reservationsSnapshot = await _firestore
              .collection('reservations')
              .where('userId', isEqualTo: user['id'])
              .get();

          for (var doc in reservationsSnapshot.docs) {
            await doc.reference.delete();
          }

          // Delete user document
          await _firestore.collection('users').doc(user['id']).delete();

          setState(() {
            _users.remove(user);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(child: Text('User deleted permanently')),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      }
    });
  }
}
