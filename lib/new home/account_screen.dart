import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login_screen.dart';
import '../theme_provider.dart';
import '../language_provider.dart';
import 'security_screen.dart';
import 'personal_info_screen.dart';
import 'language_screen.dart';
import 'help_center_screen.dart';
import 'privacy_policy_screen.dart';
import 'about_screen.dart';
import 'payment_method_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _darkMode = false;
  String? _userName;
  String? _userPhone;
  String? _userPhotoURL;
  String _selectedLanguage = 'English (US)';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload data when returning to this screen
    _loadUserData();
    _loadSettings();
  }

  @override
  void dispose() {
    // If you add controllers/listeners in future, cancel them here.
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (!mounted) return;
        if (userDoc.exists) {
          final data = userDoc.data();
          if (!mounted) return;
          setState(() {
            _userName = data?['name'] ?? user.displayName ?? 'User';
            _userPhone = data?['phoneNumber'] ?? user.phoneNumber ?? '';
            _userPhotoURL = data?['photoURL'] ?? user.photoURL;
            _isLoading = false;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _userName = user.displayName ?? 'User';
            _userPhone = user.phoneNumber ?? '';
            _userPhotoURL = user.photoURL;
            _isLoading = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeProvider = ThemeProvider.of(context);
      if (!mounted) return;
      setState(() {
        _darkMode =
            themeProvider?.isDarkMode ?? prefs.getBool('darkMode') ?? false;
        _selectedLanguage =
            prefs.getString('selectedLanguage') ?? 'English (US)';
      });
    } catch (e) {
      // Error loading settings
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? Colors.transparent,
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
                Icons.local_parking_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              context.translate('Account'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color:
                    theme.appBarTheme.titleTextStyle?.color ??
                    (isDark ? Colors.white : const Color(0xFF212121)),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Profile Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1E88E5),
                        width: 2,
                      ),
                      image: _userPhotoURL != null && _userPhotoURL!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(_userPhotoURL!),
                              fit: BoxFit.cover,
                              onError: (exception, stackTrace) {
                                // Handle error
                              },
                            )
                          : null,
                      color: _userPhotoURL == null || _userPhotoURL!.isEmpty
                          ? const Color(0xFF1E88E5)
                          : null,
                    ),
                    child: _userPhotoURL == null || _userPhotoURL!.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoading
                              ? context.translate('Loading')
                              : (_userName ?? context.translate('User')),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isLoading
                              ? ''
                              : (_userPhone?.isNotEmpty ?? false
                                    ? _userPhone!
                                    : context.translate('No phone number')),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Menu Items
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.credit_card_outlined,
                    title: context.translate('Payment Methods'),
                    onTap: () => _showPaymentMethodsDialog(),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.person_outline,
                    title: context.translate('Personal Info'),
                    onTap: () => _showEditProfileDialog(),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.security_outlined,
                    title: context.translate('Security'),
                    onTap: () => _showSecurityDialog(),
                  ),
                  _buildDivider(),
                  _buildMenuItemWithTrailing(
                    icon: Icons.language_outlined,
                    title: context.translate('Language'),
                    trailing: _selectedLanguage,
                    onTap: () => _showLanguageDialog(),
                  ),
                  _buildDivider(),
                  _buildMenuItemWithSwitch(
                    icon: Icons.dark_mode_outlined,
                    title: context.translate('Dark Mode'),
                    value: _darkMode,
                    onChanged: (value) async {
                      // Capture provider before any await so we don't use context after await
                      final themeProvider = ThemeProvider.of(context);

                      // Update local state immediately (synchronous) if still mounted
                      if (mounted) setState(() => _darkMode = value);

                      // Save preference and notify provider (provider was captured above)
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('darkMode', value);
                        if (themeProvider != null) {
                          themeProvider.toggleDarkMode(value);
                        }
                      } catch (e) {
                        // Error saving dark mode
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Support Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.help_outline,
                    title: context.translate('Help Center'),
                    onTap: () => _showHelpCenter(),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.privacy_tip_outlined,
                    title: context.translate('Privacy Policy'),
                    onTap: () => _showPrivacyPolicy(),
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                    icon: Icons.info_outline,
                    title: context.translate('About ParkSpot'),
                    onTap: () => _showAboutDialog(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                onTap: _showLogoutDialog,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 24,
                ),
                title: Text(
                  context.translate('Logout'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(
        icon,
        color: isDark ? Colors.white : const Color(0xFF212121),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF212121),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: isDark ? Colors.grey[500] : Colors.grey[400],
      ),
    );
  }

  Widget _buildMenuItemWithTrailing({
    required IconData icon,
    required String title,
    required String trailing,
    required VoidCallback onTap,
  }) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(
        icon,
        color: isDark ? Colors.white : const Color(0xFF212121),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF212121),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trailing,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: isDark ? Colors.grey[500] : Colors.grey[400],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemWithSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(
        icon,
        color: isDark ? Colors.white : const Color(0xFF212121),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF212121),
        ),
      ),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF1E88E5),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      color: Colors.grey[200],
    );
  }

  // ==================== DIALOGS ====================

  void _showPaymentMethodsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaymentMethodScreen()),
    );
  }

  void _showEditProfileDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PersonalInfoScreen()),
    );
  }

  void _showSecurityDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SecurityScreen()),
    );
  }

  void _showLanguageDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LanguageScreen()),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _selectedLanguage = result;
      });
    }
  }

  void _showAboutDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutScreen()),
    );
  }

  void _showLogoutDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) {
        final themeProvider = ThemeProvider.of(context);
        final isDark = themeProvider?.isDarkMode ?? false;
        final theme = Theme.of(context);

        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Draggable indicator
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 24),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title - Red color, centered
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  context.translate('Logout'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),

              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  context.translate('Are you sure you want to logout?'),
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 28),

              // Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    // Cancel Button - Light blue with gradient
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1E88E5).withOpacity(0.12),
                              const Color(0xFF1E88E5).withOpacity(0.18),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Center(
                              child: Text(
                                context.translate('Cancel'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E88E5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Yes, Logout Button - Solid blue
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _auth.signOut();
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Center(
                              child: Text(
                                context.translate('Yes, Logout'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHelpCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HelpCenterScreen()),
    );
  }

  void _showPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
    );
  }
}
