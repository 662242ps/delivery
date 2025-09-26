import 'package:flutter/material.dart';
import 'package:flutter_application_4/page/jobs.dart';

import 'package:flutter_application_4/page/login.dart';

import 'package:flutter_application_4/page/send_product.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const JobsPage(),
    );
  }
}
