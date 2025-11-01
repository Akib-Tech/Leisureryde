import 'dart:async';
import 'package:flutter/material.dart';
import 'package:leisureryde/userspage/entry_screen.dart';
import 'package:leisureryde/userspage/welcome.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Change the duration to however long you want
    Timer(const Duration(seconds: 10), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EntryPage(),
    );
  }
}
