import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_screen.dart';
import 'theme_provider.dart';
import 'language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  bool _isLoading = true;
  Locale _locale = const Locale('en', 'US');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = prefs.getBool('darkMode') ?? false;

        // Load saved language
        final savedLanguage = prefs.getString('selectedLanguage');
        if (savedLanguage != null) {
          _locale = AppLanguages.getLocaleFromLanguageName(savedLanguage);
        } else {
          _locale = const Locale('en', 'US');
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isDarkMode = false;
        _locale = const Locale('en', 'US');
        _isLoading = false;
      });
    }
  }

  void toggleDarkMode(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', value);
    } catch (e) {
      // Error saving dark mode
    }
  }

  void changeLanguage(Locale locale) async {
    if (_locale != locale) {
      setState(() {
        _locale = locale;
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        final languageName = AppLanguages.getLanguageNameFromLocale(locale);
        await prefs.setString('selectedLanguage', languageName);
      } catch (e) {
        // Error saving language
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return ThemeProvider(
      isDarkMode: _isDarkMode,
      toggleDarkMode: toggleDarkMode,
      child: LanguageProvider(
        locale: _locale,
        changeLanguage: changeLanguage,
        child: MaterialApp(
          key: ValueKey(
            'app_${_locale.toString()}',
          ), // Force rebuild when locale changes
          title: 'RaknaGo',
          locale: _locale,
          supportedLocales: const [
            Locale('en', 'US'),
            Locale('en', 'GB'),
            Locale('ar'),
            Locale('fr'),
            Locale('es'),
            Locale('de'),
            Locale('it'),
            Locale('pt'),
            Locale('bn'),
            Locale('ru'),
            Locale('ja'),
            Locale('ko'),
            Locale('id'),
            Locale('tr'),
            Locale('hi'),
            Locale('ur'),
            Locale('pl'),
            Locale('nl'),
            Locale('el'),
            Locale('sv'),
            Locale('no'),
            Locale('da'),
            Locale('fi'),
            Locale('cs'),
            Locale('ro'),
            Locale('hu'),
            Locale('th'),
            Locale('vi'),
            Locale('he'),
            Locale('fa'),
            Locale('ms'),
            Locale('tl'),
            Locale('sw'),
            Locale('zh', 'CN'),
          ],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.grey[50],
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF212121)),
              titleTextStyle: TextStyle(
                color: Color(0xFF212121),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            cardColor: Colors.white,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            cardColor: const Color(0xFF1E1E1E),
          ),
          themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
          debugShowCheckedModeBanner: false,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
