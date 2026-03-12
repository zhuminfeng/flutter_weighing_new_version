import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'providers/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WeighingApp());
}

class WeighingApp extends StatefulWidget {
  const WeighingApp({super.key});

  @override
  State<WeighingApp> createState() => _WeighingAppState();
}

class _WeighingAppState extends State<WeighingApp> {
  Locale _locale = const Locale('zh');

  void _changeLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return AppStateProvider(
      onLocaleChange: _changeLocale,
      child: MaterialApp(
        title: 'Weighing System',
        debugShowCheckedModeBanner: false,
        locale: _locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
