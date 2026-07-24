// ignore_for_file: use_build_context_synchronously, duplicate_ignore

import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/screens/shared/main_screen/main_screen.dart';
import 'package:leisureryde/screens/shared/splash_screen/welcome_screen.dart';
import 'package:leisureryde/services/push_notifications_service.dart';
import 'package:provider/provider.dart';
import 'package:leisureryde/services/auth_service.dart';

import '../../../app/enums.dart';
import '../../admin/admin_home_page.dart';
import 'entry_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    _animationController.forward();
    final minSplashTime = Future.delayed(const Duration(seconds: 3));
    final appInit = Provider.of<AuthService>(context, listen: false).tryAutoLogin();
    await Future.wait([minSplashTime, appInit]);

    if (mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);

      if (authService.isLoggedIn) {
        final uid = authService.currentUser!.uid;
        locator<NotificationService>().initialize(uid);

        final role = await authService.getCurrentUserRole();

        if (role == UserRole.admin) {
          // Navigate to Admin Dashboard
          // ignore: use_build_context_synchronously
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminHomePage()),
          );
        } else {
          // Navigate to Main App (for users and drivers)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      } else {
        // Not logged in, go to welcome
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WelcomePage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EntryPage(),
    );
  }
}