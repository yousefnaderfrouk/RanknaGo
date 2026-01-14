import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';
import 'home_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TwoFactorAuthScreen extends StatefulWidget {
  final String email; // Email to send OTP
  final UserCredential?
  userCredential; // User credential after email/password login

  const TwoFactorAuthScreen({
    super.key,
    required this.email,
    this.userCredential,
  });

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isVerifying = false;
  bool _canResend = false;
  int _resendCountdown = 60;
  Timer? _countdownTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _otpCode;

  @override
  void initState() {
    super.initState();
    // Fade and slide animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    // Pulse animation for security icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _sendOTPEmail();
    _startCountdown();
  }

  String _generateOTP() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  Future<void> _sendOTPViaEmail(String email, String otp) async {
    // SMTP Configuration - Update these with your Gmail credentials
    // IMPORTANT: Make sure you have:
    // 1. Enabled 2-Step Verification on your Gmail account
    // 2. Generated an App Password from: https://myaccount.google.com/apppasswords
    // 3. Use the App Password (16 characters) instead of your regular password
    const String smtpUsername = 'keroyousf8@gmail.com';
    const String smtpPassword =
        'vpshkbealjzhqfsm'; // Gmail App Password (without spaces)

    try {
      print('Attempting to send OTP email to $email via SMTP...');

      // Create SMTP server for Gmail
      final smtpServer = gmail(smtpUsername, smtpPassword);

      // Create email message
      final message = Message()
        ..from = Address(smtpUsername, 'RaknaGo')
        ..recipients.add(email)
        ..subject = 'Your 2FA Verification Code - RaknaGo'
        ..headers = {
          'X-Priority': '1',
          'X-MSMail-Priority': 'High',
          'Importance': 'high',
        }
        ..html =
            '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>2FA Verification Code</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #1E88E5 0%, #1976D2 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
    <h1 style="color: white; margin: 0;">RaknaGo</h1>
  </div>
  <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
    <h2 style="color: #1E88E5; margin-top: 0;">Two-Factor Authentication</h2>
    <p>Hello,</p>
    <p>You have requested a verification code for your RaknaGo account. Use the code below to complete your login:</p>
    <div style="background: white; border: 2px solid #1E88E5; border-radius: 8px; padding: 20px; text-align: center; margin: 30px 0;">
      <h1 style="color: #1E88E5; font-size: 36px; letter-spacing: 8px; margin: 0; font-family: 'Courier New', monospace;">$otp</h1>
    </div>
    <p style="color: #666; font-size: 14px;">This code will expire in 5 minutes.</p>
    <p style="color: #666; font-size: 14px;">If you didn't request this code, please ignore this email.</p>
    <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
    <p style="color: #999; font-size: 12px; text-align: center;">© ${DateTime.now().year} RaknaGo. All rights reserved.</p>
  </div>
</body>
</html>
        '''
        ..text =
            'Your RaknaGo 2FA Verification Code is: $otp\n\nThis code will expire in 5 minutes.\n\nIf you didn\'t request this code, please ignore this email.';

      // Send email with retry logic
      int retryCount = 0;
      const maxRetries = 3;
      bool sent = false;

      while (retryCount < maxRetries && !sent) {
        try {
          print('Sending OTP email (attempt ${retryCount + 1}/$maxRetries)...');
          final sendReport = await send(message, smtpServer).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('SMTP connection timeout');
            },
          );

          print('OTP email sent successfully: ${sendReport.toString()}');
          sent = true;
        } catch (e) {
          retryCount++;
          print(
            'Error sending OTP email (attempt $retryCount/$maxRetries): $e',
          );

          if (retryCount < maxRetries) {
            // Wait before retry (exponential backoff)
            await Future.delayed(Duration(seconds: retryCount * 2));
          } else {
            // All retries failed
            throw Exception(
              'Failed to send OTP email after $maxRetries attempts: $e',
            );
          }
        }
      }
    } catch (e) {
      print('Error sending OTP email via SMTP: $e');

      // Provide helpful error messages
      String errorMessage = 'Failed to send OTP email. ';
      if (e.toString().contains('authentication') ||
          e.toString().contains('535')) {
        errorMessage += 'Please check your Gmail App Password settings.';
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('connection')) {
        errorMessage +=
            'Network connection issue. Please check your internet connection.';
      } else if (e.toString().contains('550') ||
          e.toString().contains('rejected')) {
        errorMessage +=
            'Email address may be invalid or rejected by the server.';
      } else {
        errorMessage += 'Error: $e';
      }

      throw Exception(errorMessage);
    }
  }

  Future<void> _sendOTPEmail() async {
    try {
      // Generate 6-digit OTP
      _otpCode = _generateOTP();

      // Send OTP via SMTP first
      try {
        await _sendOTPViaEmail(widget.email, _otpCode!);
        print('OTP sent successfully via SMTP to ${widget.email}');
      } catch (e) {
        print('Error sending OTP via SMTP: $e');
        if (mounted) {
          _showErrorSnackBar('Failed to send OTP via email: $e');
        }
        return; // Don't save to Firestore if email sending failed
      }

      // Save OTP to Firestore with expiration (5 minutes) only after successful email send
      final user = widget.userCredential?.user;
      if (user != null) {
        // Ensure user is authenticated
        await user.reload();
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null || currentUser.uid != user.uid) {
          if (mounted) {
            _showErrorSnackBar(
              'Authentication error. Please try logging in again.',
            );
          }
          return;
        }

        final now = DateTime.now();
        final expiresAt = now.add(const Duration(minutes: 5));

        // Retry logic for Firestore save
        int retryCount = 0;
        const maxRetries = 3;
        bool saved = false;

        while (retryCount < maxRetries && !saved) {
          try {
            await _firestore.collection('email_otps').doc(user.uid).set({
              'otp': _otpCode,
              'email': widget.email,
              'createdAt': Timestamp.now(),
              'expiresAt': Timestamp.fromDate(expiresAt),
              'used': false,
            });
            saved = true;

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.email_outlined, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Verification code has been sent to ${widget.email}. Please check your inbox.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green[400],
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          } catch (firestoreError) {
            retryCount++;
            print(
              'Error saving OTP to Firestore (attempt $retryCount/$maxRetries): $firestoreError',
            );

            if (retryCount < maxRetries) {
              // Wait before retry
              await Future.delayed(Duration(milliseconds: 500 * retryCount));
            } else {
              // All retries failed
              print(
                'Failed to save OTP after $maxRetries attempts: $firestoreError',
              );
              // OTP was sent via email, but failed to save to Firestore
              // Store OTP locally as fallback
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('otp_code', _otpCode!);
              await prefs.setString('otp_email', widget.email);
              await prefs.setString(
                'otp_expires_at',
                expiresAt.toIso8601String(),
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Code sent! If verification fails, please check your email and try again.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.orange[400],
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            }
          }
        }
      } else {
        if (mounted) {
          _showErrorSnackBar('User not found. Please try logging in again.');
        }
      }
    } catch (e) {
      print('Error in _sendOTPEmail: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to send OTP: $e');
      }
    }
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _canResend = false;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOTP() async {
    // Get OTP from controllers
    String otp = _otpControllers.map((controller) => controller.text).join();

    if (otp.length != 6) {
      _showErrorSnackBar('Please enter complete OTP code');
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final user = widget.userCredential?.user;
      if (user != null) {
        bool otpValid = false;

        // Try to get OTP from Firestore first
        try {
          final otpDoc = await _firestore
              .collection('email_otps')
              .doc(user.uid)
              .get();

          if (otpDoc.exists) {
            final otpData = otpDoc.data();
            final storedOTP = otpData?['otp'] as String?;
            final used = otpData?['used'] as bool? ?? false;
            final createdAt = otpData?['createdAt'] as Timestamp?;

            // Check if OTP is expired (5 minutes)
            if (createdAt != null) {
              final now = DateTime.now();
              final created = createdAt.toDate();
              final difference = now.difference(created);

              if (difference.inMinutes > 5) {
                throw Exception('OTP expired. Please request a new one.');
              }
            }

            if (used) {
              throw Exception('OTP already used. Please request a new one.');
            }

            if (storedOTP == otp) {
              otpValid = true;
              // Mark OTP as used
              await _firestore.collection('email_otps').doc(user.uid).update({
                'used': true,
              });
            }
          }
        } catch (e) {
          print('Error reading OTP from Firestore: $e');
        }

        // Fallback: Check local storage if Firestore failed
        if (!otpValid) {
          try {
            final prefs = await SharedPreferences.getInstance();
            final localOTP = prefs.getString('otp_code');
            final localEmail = prefs.getString('otp_email');
            final localExpiresAt = prefs.getString('otp_expires_at');

            if (localOTP != null &&
                localEmail == widget.email &&
                localExpiresAt != null) {
              final expiresAt = DateTime.parse(localExpiresAt);
              final now = DateTime.now();

              if (now.isBefore(expiresAt) && localOTP == otp) {
                otpValid = true;
                // Clear local OTP after successful verification
                await prefs.remove('otp_code');
                await prefs.remove('otp_email');
                await prefs.remove('otp_expires_at');
              } else if (now.isAfter(expiresAt)) {
                throw Exception('OTP expired. Please request a new one.');
              }
            }
          } catch (e) {
            print('Error reading OTP from local storage: $e');
          }
        }

        if (!otpValid) {
          throw Exception('Invalid OTP code');
        }

        // Get user data to check role
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data();
        final role = userData?['role'] ?? 'user';
        final profileCompleted = userData?['profileCompleted'] ?? false;

        setState(() {
          _isVerifying = false;
        });

        _showSuccessSnackBar('Verification successful!');

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          // Navigate based on user role
          if (role == 'admin') {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminDashboardScreen(),
              ),
              (route) => false,
            );
          } else if (profileCompleted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          } else {
            // Navigate to complete profile
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const HomeScreen(), // Will redirect to complete profile
              ),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
      });
      _showErrorSnackBar('Invalid OTP code: $e');
      _clearOTP();
    }
  }

  void _clearOTP() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;

    try {
      await _sendOTPEmail();
      _startCountdown();
      _clearOTP();
    } catch (e) {
      _showErrorSnackBar('Failed to resend OTP: $e');
    }
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animationController.dispose();
    _pulseController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Illustration
                  _buildIllustration(),
                  const SizedBox(height: 40),
                  // Title
                  const Text(
                    'Two-Factor Authentication',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Description
                  Text(
                    'We\'ve sent a 6-digit verification code to',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  // Email
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // OTP Input Fields
                  _buildOTPFields(),
                  const SizedBox(height: 32),
                  // Verify Button
                  _buildVerifyButton(),
                  const Spacer(),
                  // Resend Section
                  _buildResendSection(),
                  const SizedBox(height: 16),
                  // Help Text
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Didn\'t receive the code? Check your email inbox or spam folder.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circles
          Positioned(
            top: 0,
            left: 60,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 50,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF64B5F6).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Main illustration with pulse
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.email_rounded,
                    size: 70,
                    color: Color(0xFF1E88E5),
                  ),
                ),
              ),
            ),
          ),
          // Email badge
          Positioned(
            bottom: 30,
            right: 50,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPFields() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 50,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[900]
                  : const Color(0xFF1E88E5).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _otpControllers[index].text.isNotEmpty
                    ? const Color(0xFF1E88E5)
                    : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                width: 2,
              ),
            ),
            child: TextFormField(
              controller: _otpControllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF212121),
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                if (value.isNotEmpty && index < 5) {
                  _focusNodes[index + 1].requestFocus();
                } else if (value.isEmpty && index > 0) {
                  _focusNodes[index - 1].requestFocus();
                }
                // Auto verify when all fields filled
                if (index == 5 && value.isNotEmpty) {
                  bool allFilled = _otpControllers.every(
                    (c) => c.text.isNotEmpty,
                  );
                  if (allFilled) {
                    FocusScope.of(context).unfocus();
                    _verifyOTP();
                  }
                }
                setState(() {});
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildVerifyButton() {
    bool allFilled = _otpControllers.every((c) => c.text.isNotEmpty);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: allFilled
            ? const LinearGradient(
                colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
              )
            : null,
        color: allFilled ? null : Colors.grey[300],
        boxShadow: allFilled
            ? [
                BoxShadow(
                  color: const Color(0xFF1E88E5).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: (allFilled && !_isVerifying) ? _verifyOTP : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.grey[600],
        ),
        child: _isVerifying
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Verify & Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Didn\'t receive the code? ',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            if (_canResend)
              GestureDetector(
                onTap: _resendOTP,
                child: const Text(
                  'Resend',
                  style: TextStyle(
                    color: Color(0xFF1E88E5),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Row(
                children: [
                  Text(
                    'Resend in ',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  Text(
                    '$_resendCountdown',
                    style: const TextStyle(
                      color: Color(0xFF1E88E5),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    's',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
