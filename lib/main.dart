import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'features/auth/auth_wrapper.dart';
import 'services/messaging_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/cache_service.dart';
import 'theme/app_theme.dart';
import 'features/auth/onboarding_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable persistent offline caching for Firestore
  MessagingService.instance.setupOfflineCaching();

  // Initialize Hive Smart Caching System
  await CacheService.instance.initialize();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await NotificationService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_handleThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_handleThemeChanged);
    super.dispose();
  }

  void _handleThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zelp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      navigatorKey: navigatorKey,
      home: const StartupRouter(),
    );
  }
}

class StartupRouter extends StatelessWidget {
  const StartupRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: OnboardingScreen.hasSeenOnboarding(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final hasSeenOnboarding = snapshot.data ?? false;
        return hasSeenOnboarding
            ? const AuthWrapper()
            : const OnboardingScreen();
      },
    );
  }
}
