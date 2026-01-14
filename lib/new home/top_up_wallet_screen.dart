import 'package:flutter/material.dart';
import '../theme_provider.dart';
import '../language_provider.dart';
import 'payment_method_screen.dart';

class TopUpWalletScreen extends StatefulWidget {
  const TopUpWalletScreen({super.key});

  @override
  State<TopUpWalletScreen> createState() => _TopUpWalletScreenState();
}

class _TopUpWalletScreenState extends State<TopUpWalletScreen> {
  String _amount = '125';

  final List<String> _quickAmounts = [
    '10',
    '20',
    '50',
    '100',
    '200',
    '250',
    '500',
    '750',
    '1,000',
  ];

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
          context.translate('Top Up Wallet'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section with ScrollView
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Instruction Text
                    Text(
                      context.translate('Enter the amount of top up'),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Amount Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF1E88E5),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'EGP $_amount',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF212121),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Quick Amount Buttons (3x3 Grid)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2.6,
                          ),
                      itemCount: _quickAmounts.length,
                      itemBuilder: (context, index) {
                        return _buildQuickAmountButton(_quickAmounts[index]);
                      },
                    ),
                    const SizedBox(height: 18),
                    // Continue Button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E88E5).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _continueTopUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Continue',
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
            // Numpad Section (Fixed at bottom)
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: 20,
              ),
              child: _buildNumpad(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(String amount) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _amount = amount;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF1E88E5), width: 1.5),
        ),
        child: Center(
          child: Text(
            'EGP$amount',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E88E5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNumpadRow(['1', '2', '3']),
        const SizedBox(height: 12),
        _buildNumpadRow(['4', '5', '6']),
        const SizedBox(height: 12),
        _buildNumpadRow(['7', '8', '9']),
        const SizedBox(height: 12),
        _buildNumpadRow(['.', '0', 'backspace']),
      ],
    );
  }

  Widget _buildNumpadRow(List<String> buttons) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: buttons.map((button) {
        return Expanded(
          child: GestureDetector(
            onTap: () => _handleNumpadPress(button),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              height: 48,
              child: Center(
                child: button == 'backspace'
                    ? const Icon(
                        Icons.backspace_outlined,
                        color: Color(0xFF212121),
                        size: 22,
                      )
                    : Text(
                        button,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF212121),
                        ),
                      ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _handleNumpadPress(String value) {
    setState(() {
      if (value == 'backspace') {
        if (_amount.isNotEmpty) {
          String cleanAmount = _amount.replaceAll(',', '');
          if (cleanAmount.length > 1) {
            cleanAmount = cleanAmount.substring(0, cleanAmount.length - 1);
            _amount = _formatWithCommas(cleanAmount);
          } else {
            _amount = '0';
          }
        }
        if (_amount.isEmpty) {
          _amount = '0';
        }
      } else {
        // Remove leading zeros and commas for calculation
        String cleanAmount = _amount.replaceAll(',', '');
        if (cleanAmount == '0' || cleanAmount.isEmpty) {
          _amount = value;
        } else {
          _amount = cleanAmount + value;
        }
        // Format with commas if number is large enough
        if (_amount.length > 3) {
          _amount = _formatWithCommas(_amount);
        }
      }
    });
  }

  String _formatWithCommas(String amount) {
    // Remove existing commas
    String clean = amount.replaceAll(',', '');

    // Add commas for thousands
    if (clean.length > 3) {
      String result = '';
      int count = 0;
      for (int i = clean.length - 1; i >= 0; i--) {
        if (count == 3) {
          result = ',$result';
          count = 0;
        }
        result = clean[i] + result;
        count++;
      }
      return result;
    }
    return clean;
  }

  Future<void> _continueTopUp() async {
    if (_amount.isEmpty || _amount == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('من فضلك أدخل المبلغ')),
            ],
          ),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Remove commas for calculation
    final cleanAmount = double.parse(_amount.replaceAll(',', ''));

    // Navigate to payment method selection
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentMethodScreen(amount: cleanAmount),
      ),
    );

    // If payment was successful, go back to wallet
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }
}
