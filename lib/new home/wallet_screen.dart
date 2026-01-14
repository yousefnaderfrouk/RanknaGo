import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme_provider.dart';
import '../language_provider.dart';
import 'all_transactions_screen.dart';
import 'top_up_wallet_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  double _balance = 0.0;
  String _userName = 'User';
  List<Map<String, dynamic>> _recentTransactions = [];
  StreamSubscription<DocumentSnapshot>? _walletSubscription;
  StreamSubscription<QuerySnapshot>? _transactionsSubscription;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
    _loadRecentTransactions();
    _setupListeners();
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    _transactionsSubscription?.cancel();
    super.dispose();
  }

  void _setupListeners() {
    final user = _auth.currentUser;
    if (user != null) {
      // Listen to wallet changes
      _walletSubscription = _firestore
          .collection('wallets')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists && mounted) {
              final data = snapshot.data();
              setState(() {
                _balance = (data?['balance'] ?? 0.0).toDouble();
                _userName = data?['userName'] ?? user.displayName ?? 'User';
              });
            }
          });

      // Listen to transactions changes
      _transactionsSubscription = _firestore
          .collection('transactions')
          .doc(user.uid)
          .collection('user_transactions')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              setState(() {
                _recentTransactions = snapshot.docs.map((doc) {
                  final data = doc.data();
                  final timestamp = data['createdAt'] as Timestamp?;
                  final date = timestamp?.toDate() ?? DateTime.now();

                  // Get payment method or use description
                  final paymentMethod = data['paymentMethod'] ?? '';
                  final description = data['description'] ?? 'Transaction';
                  // Use payment method if available, otherwise use description
                  final title = paymentMethod.isNotEmpty
                      ? paymentMethod
                      : description;

                  return {
                    'id': doc.id,
                    'type': data['type'] ?? 'Top-up',
                    'title': title,
                    'date': _formatDate(date),
                    'time': _formatTime(date),
                    'amount': (data['amount'] ?? 0.0).toDouble(),
                    'paymentMethod': paymentMethod,
                  };
                }).toList();
              });
            }
          });
    }
  }

  Future<void> _loadWalletData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final walletDoc = await _firestore
            .collection('wallets')
            .doc(user.uid)
            .get();

        if (walletDoc.exists) {
          final data = walletDoc.data();
          setState(() {
            _balance = (data?['balance'] ?? 0.0).toDouble();
            _userName = data?['userName'] ?? user.displayName ?? 'User';
          });
        } else {
          // Initialize wallet if it doesn't exist
          await _firestore.collection('wallets').doc(user.uid).set({
            'balance': 0.0,
            'userName': user.displayName ?? 'User',
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      // Error loading wallet data
    }
  }

  Future<void> _loadRecentTransactions() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final transactionsSnapshot = await _firestore
            .collection('transactions')
            .doc(user.uid)
            .collection('user_transactions')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();

        setState(() {
          _recentTransactions = transactionsSnapshot.docs.map((doc) {
            final data = doc.data();
            final timestamp = data['createdAt'] as Timestamp?;
            final date = timestamp?.toDate() ?? DateTime.now();

            // Get payment method or use description
            final paymentMethod = data['paymentMethod'] ?? '';
            final description = data['description'] ?? 'Transaction';
            // Use payment method if available, otherwise use description
            final title = paymentMethod.isNotEmpty
                ? paymentMethod
                : description;

            return {
              'id': doc.id,
              'type': data['type'] ?? 'Top-up',
              'title': title,
              'date': _formatDate(date),
              'time': _formatTime(date),
              'amount': (data['amount'] ?? 0.0).toDouble(),
              'paymentMethod': paymentMethod,
            };
          }).toList();
        });
      }
    } catch (e) {
      // Error loading transactions
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF1E88E5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                context.translate('My Wallet'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF212121),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadWalletData();
          await _loadRecentTransactions();
        },
        color: const Color(0xFF1E88E5),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Wallet Card
            _buildWalletCard(),
            const SizedBox(height: 28),
            // Recent Transactions Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.translate('Recent Transactions'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF212121),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AllTransactionsScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        context.translate('View All'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E88E5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Color(0xFF1E88E5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Transactions List
            if (_recentTransactions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    context.translate('No transactions yet'),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ..._recentTransactions.map((transaction) {
                final isPositive = transaction['amount'] > 0;
                return _buildTransactionItem(
                  type: transaction['type'] ?? 'Top-up',
                  title: transaction['title'] ?? 'Transaction',
                  date: transaction['date'] ?? '',
                  time: transaction['time'] ?? '',
                  amount:
                      '${isPositive ? '+' : ''}EGP ${transaction['amount'].abs().toStringAsFixed(2)}',
                  isPositive: isPositive,
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  _userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'P',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Card Brand
          Text(
            context.translate('RaknaGo Card'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.95),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.translate('Your balance'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'EGP ${_balance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_circle_rounded,
                      color: Color(0xFF1E88E5),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showTopUpDialog(),
                      child: Text(
                        context.translate('Top Up'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem({
    required String type,
    required String title,
    required String date,
    required String time,
    required String amount,
    required bool isPositive,
  }) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          // Type Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isPositive
                  ? const Color(0xFF1E88E5).withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              type,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isPositive ? const Color(0xFF1E88E5) : Colors.red,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Transaction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF212121),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$date · $time',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Amount
          Row(
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey[400],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTopUpDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TopUpWalletScreen()),
    ).then((result) {
      if (result == true) {
        // Reload wallet data after successful top up
        _loadWalletData();
      }
    });
  }
}
