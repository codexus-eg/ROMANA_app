import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(() async {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };

    try {
      // تجهيز إعدادات الفايربيز حسب نوع النظام (أندرويد أو ايفون)
      FirebaseOptions? firebaseOptions;

      if (Platform.isAndroid) {
        firebaseOptions = const FirebaseOptions(
          apiKey: "AIzaSyDcRj1bnqhkdsEtKMdtMOc2FI8DSq_Ee0A",
          authDomain: "romana-project.firebaseapp.com",
          projectId: "romana-project",
          storageBucket: "romana-project.firebasestorage.app",
          messagingSenderId: "771775359247",
          appId: "1:771775359247:android:17966e383e2b1e0442367a",
        );
      } else if (Platform.isIOS) {
        firebaseOptions = const FirebaseOptions(
          apiKey: "AIzaSyB8BcE3QBYJZ09zeAwJT88bXDYN7AZyzro", // من ملف الـ plist
          authDomain: "romana-project.firebaseapp.com",
          projectId: "romana-project",
          storageBucket: "romana-project.firebasestorage.app",
          messagingSenderId: "771775359247",
          appId:
              "1:771775359247:ios:84b0a7d820f40ad542367a", // من ملف الـ plist
          iosBundleId: "com.romana.codexus.app", // من ملف الـ plist
        );
      }

      await Firebase.initializeApp(options: firebaseOptions);
    } catch (e) {
      debugPrint('Firebase error: $e');
    }

    runApp(const MyApp());
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROMANA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.red,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('settings')
            .doc('app_status')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.red,
              body:
                  Center(child: CircularProgressIndicator(color: Colors.white)),
            );
          }

          bool isOpen = true;
          String currentMessage = 'التطبيق غير متاح الآن';
          String timeMessage = 'متاح قريباً';

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;

            // قراءة البيانات من الفايربيز مع تحويل النصوص لأرقام
            bool isManuallyOpen =
                data['is_open'].toString().toLowerCase() == 'true';
            int startHour = int.tryParse(data['start_hour'].toString()) ?? 8;
            int endHour = int.tryParse(data['end_hour'].toString()) ?? 24;
            String manualCloseMessage = data['close_message']?.toString() ??
                'التطبيق مغلق حالياً للصيانة أو التحديث';

            final now = DateTime.now();
            final hour = now.hour;

            bool isTimeValid = hour >= startHour && hour < endHour;

            isOpen = isManuallyOpen && isTimeValid;

            if (!isManuallyOpen) {
              currentMessage = manualCloseMessage;
              timeMessage = 'يرجى المحاولة في وقت لاحق';
            } else if (!isTimeValid) {
              currentMessage = 'التطبيق مغلق الآن';
              timeMessage =
                  'متاح من ${startHour > 12 ? startHour - 12 : startHour}:00 ${startHour >= 12 ? "م" : "ص"}\nحتى ${endHour > 12 ? endHour - 12 : endHour}:00 ${endHour >= 12 && endHour < 24 ? "م" : "ص"}';
            }
          }

          return isOpen
              ? const SplashScreen()
              : ClosedPage(
                  mainMessage: currentMessage,
                  subMessage: timeMessage,
                );
        },
      ),
    );
  }
}

class ClosedPage extends StatelessWidget {
  final String mainMessage;
  final String subMessage;

  const ClosedPage({
    super.key,
    required this.mainMessage,
    required this.subMessage,
  });

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
                child: Column(
                  children: [
                    Text(mainMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(subMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16, height: 1.5)),
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
