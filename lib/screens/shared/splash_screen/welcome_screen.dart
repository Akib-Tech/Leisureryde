import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../auth/login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Access the theme

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SVG Illustration
              Expanded(
                flex: 10,
                child: Image.asset(
                  'assets/images/welcomride.png',
                  height: 800,
                  width: 400,
                  fit: BoxFit.cover,
                  // Your SVG asset path
                  // placeholderBuilder: (context) => const Icon(Icons.car_rental, size: 200),
                ),
              ),
              const Spacer(flex: 1),

              // Title Text
              Text(
                'Welcome to LeisureRyde',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith( // <-- Theme-aware font
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Subtitle Text
              Text(
                'Your journey to comfort and convenience begins here. Let\'s get you to your destination.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith( // <-- Theme-aware font
                  color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8),
                ),
              ),
              const Spacer(flex: 1),

              // Action Buttons
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('GET STARTED'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}