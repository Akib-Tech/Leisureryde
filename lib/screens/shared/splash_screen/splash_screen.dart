import 'package:flutter/material.dart';
import 'package:leisureryde/admin/home.dart';
import 'package:leisureryde/screens/shared/main_screen/main_screen.dart';
import 'package:leisureryde/screens/shared/splash_screen/welcome_screen.dart';
import 'package:leisureryde/userspage/home.dart';
import 'package:provider/provider.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:leisureryde/screens/shared/splash_screen/splash_screen.dart';

import '../../../app/enums.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../admin/admin_home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

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
        // Get the user's role
        final role = await authService.getCurrentUserRole();

        if (role == UserRole.admin) {
          // Navigate to Admin Dashboard
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
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Icon(
                Icons.local_taxi, // Replace with your app logo widget
                size: 180,
                color: Color(0xFFD4AF37), // Primary color can be hardcoded here
              ),
            ),
            const SizedBox(height: 40),
            const CustomLoadingIndicator(),
          ],
        ),
      ),
    );
  }
}