import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme_provider.dart';
import 'login_screen.dart';
import 'complete_profile_screen.dart';
import 'services/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isCheckingVerification = false;
  bool _canResend = false;
  int _resendCountdown = 60;
  Timer? _countdownTimer;
  Timer? _verificationCheckTimer;
  StreamSubscription<DocumentSnapshot>? _userStreamSubscription;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // SMTP Configuration
  static const String smtpUsername = 'keroyousf8@gmail.com';
  static const String smtpPassword =
      'vpshkbealjzhqfsm'; // Gmail App Password (without spaces)

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

    // Pulse animation for email icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _startCountdown();

    // Auto check verification every 2 seconds (more frequent for better UX)
    _verificationCheckTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) {
      _checkVerificationStatus();
    });

    // Also check immediately when screen loads
    _checkVerificationStatus();

    // Show reminder after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _showCheckEmailReminder();
      }
    });
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

  void _showCheckEmailReminder() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text('Please check your email for the verification link'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E88E5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _checkVerificationStatus() async {
    if (_isCheckingVerification) return;

    setState(() {
      _isCheckingVerification = true;
    });

    try {
      // Reload user to get latest email verification status
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;

      if (user != null) {
        // Check verification status from Firestore (not Firebase Auth)
        // Use source: Source.server to get fresh data from server
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server));

        final userData = userDoc.data();
        final isEmailVerified = userData?['isEmailVerified'] ?? false;

        print('Checking verification status for user ${user.uid}');
        print('isEmailVerified in Firestore: $isEmailVerified');

        if (isEmailVerified) {
          // Email is verified
          _verificationCheckTimer?.cancel();
          _countdownTimer?.cancel();

          if (mounted) {
            setState(() {
              _isCheckingVerification = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(child: Text('Email verified successfully!')),
                  ],
                ),
                backgroundColor: Colors.green[400],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );

            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CompleteProfileScreen(
                      email: user.email ?? widget.email,
                    ),
                  ),
                  (route) => false,
                );
              }
            });
          }
        } else {
          // Not verified yet, continue checking
          if (mounted) {
            setState(() {
              _isCheckingVerification = false;
            });
          }
        }
      } else {
        // User not authenticated
        if (mounted) {
          setState(() {
            _isCheckingVerification = false;
          });
        }
      }
    } catch (e) {
      print('Error checking verification status: $e');
      // Show error but don't stop checking
      if (mounted) {
        setState(() {
          _isCheckingVerification = false;
        });
      }
    }
  }

  void _checkVerification() {
    _checkVerificationStatus();
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResend) return;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Generate verification token
      final random = Random();
      final verificationToken = List.generate(
        32,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();

      // Save verification token to Firestore
      await _firestore.collection('email_verifications').doc(user.uid).set({
        'token': verificationToken,
        'email': widget.email,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': FieldValue.serverTimestamp(),
        'verified': false,
      });

      // Create verification link
      final verificationLink =
          'https://raknago-pro.firebaseapp.com/verify-email?token=$verificationToken&uid=${user.uid}';

      // Send verification email via SMTP
      await _sendVerificationEmailViaSMTP(widget.email, verificationLink);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Verification email sent successfully!')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      }

      _startCountdown();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    }
  }

  Future<void> _sendVerificationEmailViaSMTP(
    String email,
    String verificationLink,
  ) async {
    try {
      // Create SMTP server for Gmail
      final smtpServer = gmail(smtpUsername, smtpPassword);

      // Create email message
      final message = Message()
        ..from = Address(smtpUsername, 'RaknaGo')
        ..recipients.add(email)
        ..subject = 'Verify your email address - RaknaGo'
        ..html =
            '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Email Verification</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #1E88E5 0%, #1976D2 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
    <h1 style="color: white; margin: 0;">RaknaGo</h1>
  </div>
  <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
    <h2 style="color: #1E88E5; margin-top: 0;">Verify Your Email Address</h2>
    <p>Hello,</p>
    <p>Thank you for signing up for RaknaGo! Please verify your email address by clicking the button below:</p>
    <div style="text-align: center; margin: 30px 0;">
      <a href="$verificationLink" style="background: #1E88E5; color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; display: inline-block; font-weight: bold;">Verify Email Address</a>
    </div>
    <p style="color: #666; font-size: 14px;">Or copy and paste this link into your browser:</p>
    <p style="color: #1E88E5; font-size: 12px; word-break: break-all;">$verificationLink</p>
    <p style="color: #666; font-size: 14px;">This link will expire in 24 hours.</p>
    <p style="color: #666; font-size: 14px;">If you didn't create an account, please ignore this email.</p>
    <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
    <p style="color: #999; font-size: 12px; text-align: center;">© ${DateTime.now().year} RaknaGo. All rights reserved.</p>
  </div>
</body>
</html>
        '''
        ..text =
            'Verify your email address by clicking this link: $verificationLink\n\nThis link will expire in 24 hours.\n\nIf you didn\'t create an account, please ignore this email.';

      // Send email
      final sendReport = await send(message, smtpServer);

      print(
        'Verification email sent successfully via SMTP: ${sendReport.toString()}',
      );
    } catch (e) {
      print('Error sending verification email via SMTP: $e');
      throw Exception('Failed to send verification email: $e');
    }
  }

  void _openEmailApp() {
    // In real app, use url_launcher package:
    // launchUrl(Uri.parse('mailto:'));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.email_outlined, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('Please check your email app')),
          ],
        ),
        backgroundColor: Color(0xFF1E88E5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  void _changeEmail() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Email'),
        content: const Text(
          'Do you want to go back and change your email address?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Sign out and go to login
              _authService.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1E88E5),
            ),
            child: const Text('Change Email'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _verificationCheckTimer?.cancel();
    _animationController.dispose();
    _pulseController.dispose();
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () {
            // Sign out if user goes back
            _authService.signOut();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
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
                    Text(
                      'Verify your email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Description
                    Text(
                      'We\'ve sent a verification link to',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.grey[400] : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Email with edit button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            widget.email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E88E5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _changeEmail,
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey[900]
                            : const Color(0xFF1E88E5).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey[700]!
                              : const Color(0xFF1E88E5).withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1E88E5,
                                  ).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text(
                                    '1',
                                    style: TextStyle(
                                      color: Color(0xFF1E88E5),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Check your email inbox',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1E88E5,
                                  ).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text(
                                    '2',
                                    style: TextStyle(
                                      color: Color(0xFF1E88E5),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Click the verification link',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1E88E5,
                                  ).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text(
                                    '3',
                                    style: TextStyle(
                                      color: Color(0xFF1E88E5),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Come back and continue',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Open Email App Button
                    _buildOpenEmailButton(),
                    const SizedBox(height: 16),
                    // Check Verification Button
                    _buildCheckVerificationButton(),
                    const SizedBox(height: 40),
                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Need help?',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Resend Email Section
                    _buildResendSection(),
                    const SizedBox(height: 20),
                    // Help tips
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                size: 18,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tips',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTipItem('Check your spam or junk folder'),
                          _buildTipItem(
                            'Make sure the email address is correct',
                          ),
                          _buildTipItem(
                            'Wait a few minutes for the email to arrive',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
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
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E88E5).withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    size: 70,
                    color: Color(0xFF1E88E5),
                  ),
                ),
              ),
            ),
          ),
          // Notification badge
          Positioned(
            top: 40,
            right: 40,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: const Center(
                child: Text(
                  '1',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenEmailButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _openEmailApp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.email_rounded, size: 20),
            SizedBox(width: 12),
            Text(
              'Open Email App',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckVerificationButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E88E5), width: 1.5),
      ),
      child: TextButton(
        onPressed: _isCheckingVerification ? null : _checkVerification,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF1E88E5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isCheckingVerification
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Color(0xFF1E88E5),
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'I\'ve Verified My Email',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
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
              'Didn\'t receive the email? ',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            if (_canResend)
              GestureDetector(
                onTap: _resendVerificationEmail,
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
              Text(
                'Resend in ${_resendCountdown}s',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6, right: 8),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
