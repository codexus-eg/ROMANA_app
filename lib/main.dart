import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(() async {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };

    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDcRj1bnqhkdsEtKMdtMOc2FI8DSq_Ee0A",
          authDomain: "romana-project.firebaseapp.com",
          projectId: "romana-project",
          storageBucket: "romana-project.firebasestorage.app",
          messagingSenderId: "771775359247",
          appId: "1:771775359247:android:17966e383e2b1e0442367a",
        ),
      );
    } catch (e) {
      debugPrint('Firebase error: $e');
    }

    final now = DateTime.now();
    final hour = now.hour;
    final isOpen = hour >= 8 && hour < 24;

    runApp(MyApp(isOpen: isOpen));
  }, (error, stack) {
    runApp(ErrorApp(error: error.toString()));
  });
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Error: $error',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final bool isOpen;
  const MyApp({super.key, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROMANA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.red,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: isOpen ? SplashScreen() : ClosedPage(),
    );
  }
}

class ClosedPage extends StatelessWidget {
  const ClosedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.red,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              const Text('ROMANA',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('خضروات وفواكه طازجة',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Text('التطبيق غير متاح الآن',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    Text('متاح من الساعة 8:00 صباحاً',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    Text('حتى الساعة 12:00 منتصف الليل',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
