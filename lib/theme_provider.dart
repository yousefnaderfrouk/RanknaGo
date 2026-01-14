import 'package:flutter/material.dart';

class ThemeProvider extends InheritedWidget {
  final bool isDarkMode;
  final Function(bool) toggleDarkMode;

  const ThemeProvider({
    Key? key,
    required this.isDarkMode,
    required this.toggleDarkMode,
    required Widget child,
  }) : super(key: key, child: child);

  static ThemeProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return isDarkMode != oldWidget.isDarkMode;
  }
}
