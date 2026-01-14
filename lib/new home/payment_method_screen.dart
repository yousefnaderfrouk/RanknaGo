import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme_provider.dart';
import 'add_payment_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final double? amount;

  const PaymentMethodScreen({super.key, this.amount});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedMethod = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _savedCards = [];
  StreamSubscription<QuerySnapshot>? _cardsSubscription;

  final List<Map<String, dynamic>> _defaultPaymentMethods = [
    {
      'id': 'mobile_wallet',
      'name': 'Mobile Wallet',
      'subtitle': 'Vodafone Cash, Orange Cash',
      'iconPath': 'assets/icons/mobile_wallet.png',
      'useAsset': true,
      'icon': Icons.phone_android_rounded,
      'color': const Color(0xFF1E88E5),
    },
    {
      'id': 'fawry',
      'name': 'Fawry',
      'subtitle': 'Pay via Fawry',
      'iconPath': 'assets/icons/transfer.png',
      'useAsset': true,
      'icon': Icons.swap_horiz_rounded,
      'color': const Color(0xFFFDB913),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  void _loadPaymentMethods() {
    final user = _auth.currentUser;
    if (user == null) return;

    _cardsSubscription = _firestore
        .collection('payment_methods')
        .doc(user.uid)
        .collection('cards')
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() {
                _savedCards = snapshot.docs.map((doc) {
                  final data = doc.data();
                  return {
                    'id': 'card_${doc.id}',
                    'name': '${data['cardType'] ?? 'Card'} Card',
                    'subtitle':
                        '**** **** **** ${data['lastFourDigits'] ?? '****'}',
                    'iconPath': '',
                    'useAsset': false,
                    'icon': Icons.credit_card,
                    'color': const Color(0xFF1E88E5),
                    'cardData': data,
                    'isCard': true,
                  };
                }).toList();
              });
            }
          },
          onError: (error) {
            if (mounted) {
              _showErrorSnackBar(
                'Failed to load payment methods: ${error.toString()}',
              );
            }
          },
        );
  }

  @override
  void dispose() {
    _cardsSubscription?.cancel();
    super.dispose();
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.amount != null ? 'Top Up Wallet' : 'Payment Methods',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? Colors.white : const Color(0xFF212121),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instruction Text
                  Text(
                    widget.amount != null
                        ? 'Select the top up method you want to use'
                        : 'Select a payment method',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Saved Cards List
                  if (_savedCards.isNotEmpty) ...[
                    ..._savedCards.map((method) {
                      return _buildPaymentMethodItem(
                        id: method['id'],
                        name: method['name'],
                        subtitle: method['subtitle'],
                        iconPath: method['iconPath'],
                        useAsset: method['useAsset'],
                        icon: method['icon'],
                        color: method['color'],
                      );
                    }).toList(),
                    const SizedBox(height: 12),
                  ],
                  // Default Payment Methods List
                  ..._defaultPaymentMethods.map((method) {
                    return _buildPaymentMethodItem(
                      id: method['id'],
                      name: method['name'],
                      subtitle: method['subtitle'],
                      iconPath: method['iconPath'],
                      useAsset: method['useAsset'],
                      icon: method['icon'],
                      color: method['color'],
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                  // Add New Payment Button
                  GestureDetector(
                    onTap: _showAddPaymentDialog,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_circle_outline_rounded,
                            color: Color(0xFF1E88E5),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Add New Payment',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E88E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Continue Button (only show if amount is provided)
          if (widget.amount != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Container(
                  width: double.infinity,
                  height: 56,
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
                  child: ElevatedButton(
                    onPressed: _selectedMethod.isEmpty || _isLoading
                        ? null
                        : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodItem({
    required String id,
    required String name,
    required String subtitle,
    required String iconPath,
    required bool useAsset,
    required IconData icon,
    required Color color,
  }) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);
    final isSelected = _selectedMethod == id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = id;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1E88E5)
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon with custom image or default icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: useAsset
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: _getIconWidget(id, color),
                    )
                  : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Radio Button
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1E88E5)
                      : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
                  width: 2,
                ),
                color: isSelected
                    ? const Color(0xFF1E88E5)
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // Get icon widget based on payment method
  Widget _getIconWidget(String id, Color color) {
    switch (id) {
      case 'mobile_wallet':
        // Mobile Wallet Icon (Phone with arrow)
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.phone_android_rounded, color: color, size: 28),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(Icons.arrow_back, color: color, size: 8),
              ),
            ),
          ],
        );

      case 'fawry':
        // Transfer Icon (Circular arrows)
        return Transform.rotate(
          angle: 0.5,
          child: Icon(Icons.autorenew_rounded, color: color, size: 28),
        );

      default:
        return Icon(Icons.credit_card, color: color, size: 24);
    }
  }

  Future<void> _processPayment() async {
    if (_selectedMethod.isEmpty) {
      _showErrorSnackBar('Please select a payment method');
      return;
    }

    if (widget.amount == null) {
      _showErrorSnackBar('Amount is required');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user found');

      // Simulate payment processing delay (2 seconds)
      await Future.delayed(const Duration(seconds: 2));

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Get current wallet balance
      final walletDoc = await _firestore
          .collection('wallets')
          .doc(user.uid)
          .get();

      double currentBalance = 0;
      if (walletDoc.exists) {
        currentBalance = (walletDoc.data()?['balance'] ?? 0).toDouble();
      }

      // Update wallet balance - use update() if exists, set() if not
      try {
        if (walletDoc.exists) {
          await _firestore.collection('wallets').doc(user.uid).update({
            'balance': currentBalance + widget.amount!,
            'lastUpdated': FieldValue.serverTimestamp(),
            'userName': userData['name'] ?? user.displayName ?? 'User',
            'cardNumber': '**** **** **99',
          });
        } else {
          await _firestore.collection('wallets').doc(user.uid).set({
            'balance': currentBalance + widget.amount!,
            'lastUpdated': FieldValue.serverTimestamp(),
            'userName': userData['name'] ?? user.displayName ?? 'User',
            'cardNumber': '**** **** **99',
          });
        }
      } catch (walletError) {
        print('Wallet update error: $walletError');
        // Try alternative approach with set and merge
        await _firestore.collection('wallets').doc(user.uid).set({
          'balance': currentBalance + widget.amount!,
          'lastUpdated': FieldValue.serverTimestamp(),
          'userName': userData['name'] ?? user.displayName ?? 'User',
          'cardNumber': '**** **** **99',
        }, SetOptions(merge: true));
      }

      // Get payment method name
      String paymentMethodName = '';
      String cardLastFour = '';

      if (_selectedMethod.startsWith('card_')) {
        try {
          final card = _savedCards.firstWhere(
            (card) => card['id'] == _selectedMethod,
          );
          final cardData = card['cardData'] as Map<String, dynamic>?;
          final cardType = cardData?['cardType'] ?? 'Card';
          cardLastFour = cardData?['lastFourDigits'] ?? '****';
          paymentMethodName = '$cardType Card (****$cardLastFour)';
        } catch (e) {
          // Card not found, use default
          paymentMethodName = 'Card';
        }
      } else if (_selectedMethod == 'fawry') {
        paymentMethodName = 'Fawry';
      } else if (_selectedMethod == 'mobile_wallet') {
        paymentMethodName = 'Mobile Wallet';
      } else {
        paymentMethodName = 'Payment Method';
      }

      // Create transaction record
      await _firestore
          .collection('transactions')
          .doc(user.uid)
          .collection('user_transactions')
          .add({
            'type': 'Top-up',
            'amount': widget.amount!,
            'paymentMethod': paymentMethodName,
            'paymentMethodId': _selectedMethod,
            'status': 'completed',
            'createdAt': FieldValue.serverTimestamp(),
            'description': 'Wallet Top Up',
          });

      setState(() => _isLoading = false);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Payment failed: ${e.toString()}');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E88E5).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              const Text(
                'Top Up Successful!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Message
              if (widget.amount != null)
                Text(
                  'A total of EGP ${widget.amount!.toStringAsFixed(2)} has been added to your wallet',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 28),
              // OK Button
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E88E5).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    // Close dialog first
                    Navigator.pop(dialogContext);
                    // Close payment screen and return true to top up screen
                    // The top up screen will then close and return to wallet
                    if (mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ok',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPaymentDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPaymentScreen()),
    ).then((result) {
      if (result == true) {
        // Refresh payment methods if needed
        // You can add logic here to reload payment methods
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
