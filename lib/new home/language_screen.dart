import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme_provider.dart';
import '../language_provider.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedLanguage = 'English (US)';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('selectedLanguage');

      if (savedLanguage != null) {
        setState(() {
          _selectedLanguage = savedLanguage;
        });
      } else {
        // Try to load from Firestore
        final user = _auth.currentUser;
        if (user != null) {
          final userDoc = await _firestore
              .collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data();
            final language = data?['language'];
            if (language != null) {
              setState(() {
                _selectedLanguage = language;
              });
              await prefs.setString('selectedLanguage', language);
            }
          }
        }
      }
    } catch (e) {
      // Error loading language
    }
  }

  Future<void> _saveLanguage(String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedLanguage', language);

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'language': language,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Error saving language
    }
  }

  final List<String> _suggestedLanguages = [
    'English (US)',
    'English (UK)',
    'Arabic',
    'French',
  ];

  final List<String> _allLanguages = [
    'Mandarin',
    'Spanish',
    'German',
    'Italian',
    'Portuguese',
    'Bengali',
    'Russian',
    'Japanese',
    'Korean',
    'Indonesian',
    'Turkish',
    'Hindi',
    'Urdu',
    'Polish',
    'Dutch',
    'Greek',
    'Swedish',
    'Norwegian',
    'Danish',
    'Finnish',
    'Czech',
    'Romanian',
    'Hungarian',
    'Thai',
    'Vietnamese',
    'Hebrew',
    'Persian',
    'Malay',
    'Tagalog',
    'Swahili',
  ];

  String _getTranslatedText(String key, Locale locale) {
    return AppLanguages.translate(key, locale);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);
    final languageProvider = LanguageProvider.of(context);
    final currentLocale = languageProvider?.locale ?? const Locale('en', 'US');

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
          _getTranslatedText('Language', currentLocale),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Suggested Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              _getTranslatedText('Suggested', currentLocale),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),

          // Suggested Languages
          ..._suggestedLanguages.map((language) {
            return _buildLanguageTile(language, true, currentLocale);
          }).toList(),

          const SizedBox(height: 16),

          // All Languages Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              _getTranslatedText('All Languages', currentLocale),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ),

          // All Languages
          ..._allLanguages.map((language) {
            return _buildLanguageTile(language, false, currentLocale);
          }).toList(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLanguageTile(
    String language,
    bool isSuggested,
    Locale currentLocale,
  ) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final isSelected = _selectedLanguage == language;
    final translatedName = AppLanguages.getTranslatedLanguageName(
      language,
      currentLocale,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        translatedName,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF212121),
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: Color(0xFF1E88E5), size: 28)
          : null,
      onTap: () async {
        setState(() {
          _selectedLanguage = language;
        });

        await _saveLanguage(language);

        // Change language in the app
        final languageProvider = LanguageProvider.of(context);
        if (languageProvider != null) {
          final locale = AppLanguages.getLocaleFromLanguageName(language);
          languageProvider.changeLanguage(locale);
        }

        // Get new locale for translated message
        final newLocale = AppLanguages.getLocaleFromLanguageName(language);
        final translatedLanguageName = AppLanguages.getTranslatedLanguageName(
          language,
          newLocale,
        );
        final messageText = _getTranslatedText(
          'Language changed to',
          newLocale,
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('$messageText $translatedLanguageName')),
              ],
            ),
            backgroundColor: Colors.green[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // Go back after short delay
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.pop(context, language);
          }
        });
      },
    );
  }
}
