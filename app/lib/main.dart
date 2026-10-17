import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const PushItApp());
}

class PushItApp extends StatelessWidget {
  const PushItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Push-Up Battle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: const HomeScreen(),
    );
  }
}
