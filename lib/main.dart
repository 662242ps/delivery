import 'package:flutter/material.dart';
import 'package:animations/animations.dart'; // ✨ ใช้อนิเมชัน Material motion

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_4/firebase_options.dart';

// Supabase
import 'package:supabase_flutter/supabase_flutter.dart';

// หน้าต้นทาง
import 'package:flutter_application_4/page/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Init Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔧 Firestore persistence (มือถือ/เดสก์ท็อป)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,

        // 🧱 ทำพื้นหลังทึบทั้งแอป เพื่อตัดแฟลชเวลาคร่อมหน้า
        scaffoldBackgroundColor: const Color(0xFFF6F6F6),

        // 🎭 ใช้ FadeThrough กับทุกแพลตฟอร์ม (ตั้งครั้งเดียว มีผลทุกหน้า)
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
