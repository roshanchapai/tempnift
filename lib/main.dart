import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nift_final/screens/splash_screen.dart';
import 'package:nift_final/services/notification_service.dart';
import 'package:nift_final/utils/constants.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    debugPrint('Initializing Firebase...');
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
    
    // Initialize notification service
    debugPrint('Initializing notification service...');
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.requestPermissions();
    debugPrint('Notification service initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize services: $e');
  }

  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NIFT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}