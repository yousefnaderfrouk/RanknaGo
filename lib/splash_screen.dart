import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'language_provider.dart';
import 'theme_provider.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'complete_profile_screen.dart';
import '../admin/admin_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    // Navigate after splash screen duration
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    try {
      // Wait for splash screen to show (3 seconds)
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      // Check if user has seen onboarding and is logged in
      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      if (!mounted) return;

      if (!hasSeenOnboarding) {
        // Navigate to onboarding screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      } else if (!isLoggedIn) {
        // Navigate to login screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } else {
        // Check if user is authenticated and profile is completed
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final firestore = FirebaseFirestore.instance;
          final userDoc = await firestore
              .collection('users')
              .doc(user.uid)
              .get();
          final userData = userDoc.data();
          final role = userData?['role'] ?? 'user';
          final profileCompleted = userData?['profileCompleted'] ?? false;

          if (mounted) {
            // Check if user is admin
            if (role == 'admin') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const AdminDashboardScreen(),
                ),
              );
            } else if (profileCompleted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) =>
                      CompleteProfileScreen(email: user.email ?? ''),
                ),
              );
            }
          }
        } else {
          // Navigate to login if not authenticated
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        }
      }
    } catch (e) {
      // If there's an error, default to onboarding screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);
    // If the app is using an RTL language (like Arabic), apply a small
    // left offset so the loader appears visually centered.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final loaderHorizontalOffset = isRtl ? -12.0 : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  _buildLogo(),
                  const SizedBox(height: 32),
                  // App Name
                  Text(
                    'RaknaGo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Loading Indicator
            // Use Positioned.fill + Align to avoid any text-direction mirroring issues
            // and ensure the loader is always centered horizontally (works in RTL).
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: Offset(loaderHorizontalOffset, 0),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 160.0),
                    child: _buildLoadingIndicator(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow effect
        Container(
          width: 144,
          height: 144,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
        ),
        // Main circle
        Container(
          width: 144,
          height: 144,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1D4ED8)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Car icon
              const Icon(Icons.directions_car, size: 80, color: Colors.white),
              // P badge
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    // Sizes: biggest to smallest
    final dotSizes = [16.0, 14.0, 12.0, 10.0, 8.0, 6.0, 5.0, 4.0];

    return SizedBox(
      width: 60,
      height: 60,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: List.generate(8, (index) {
                // Each dot follows the previous one with delay
                final progress = _controller.value;
                final dotDelay = index * 0.08;
                final dotPosition = (progress - dotDelay) % 1.0;
                final angle = dotPosition * 2 * math.pi;

                final size = dotSizes[index];
                // Opacity fades based on index (tail effect)
                final opacity = (1.0 - (index * 0.12)).clamp(0.2, 1.0);

                return Transform(
                  transform: Matrix4.identity()
                    ..translate(30.0, 30.0)
                    ..rotateZ(angle)
                    ..translate(0.0, -22.0)
                    ..translate(-size / 2, -size / 2),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(opacity),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}