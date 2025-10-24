import 'package:flutter/material.dart';
import 'package:animations/animations.dart'; // ✨ Material motion
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart'; // ✅ Realtime Database
import 'package:flutter_application_4/firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_4/page/login.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // --- RTDB ---
  final rtdb = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://delivery-test-61f4a-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // smoke test: เขียนค่าเล็ก ๆ ดูว่าขึ้น RTDB จริง
  try {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await rtdb.ref('debug/lastBoot/$uid').set(ServerValue.timestamp);
  } catch (e) {
    debugPrint('RTDB smoke test failed: $e');
  }

  // ⚡️ Init Supabase
  const supabaseUrl = 'https://emunourlkzxdzudisogq.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVtdW5vdXJsa3p4ZHp1ZGlzb2dxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NzAyNTYsImV4cCI6MjA3NjM0NjI1Nn0.omhJbXdhAoiw0zQX2EOTCUzA2QjneKroTmPqibanXmc';
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Delivery App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 252, 108, 108),
        ),
        useMaterial3: true,

        // พื้นหลังทึบ ตัดแฟลชตอนเปลี่ยนหน้า
        scaffoldBackgroundColor: const Color(0xFFF6F6F6),

        // 🎭 FadeThrough transition ทุกแพลตฟอร์ม
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(),
            TargetPlatform.windows: FadeThroughPageTransitionsBuilder(),
            TargetPlatform.linux: FadeThroughPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeThroughPageTransitionsBuilder(),
          },
        ),
      ),
      home: const Login(),
    );
  }
}
