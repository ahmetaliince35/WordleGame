import 'package:flutter/material.dart';
import 'screens/game_hub_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WordleApp());
}

class WordleApp extends StatefulWidget {
  const WordleApp({super.key});

  @override
  State<WordleApp> createState() => _WordleAppState();
}

class _WordleAppState extends State<WordleApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kelime Dünyası',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _themeMode,
      // Artık doğrudan oyuna değil, mağaza/hub ekranına yönlendiriyor:
      home: GameHubScreen(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}