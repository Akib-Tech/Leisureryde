
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:provider/provider.dart';

import 'app/app_theme.dart';
import 'app/service_locator.dart';
import 'firebase_options.dart';
import 'screens/shared/splash_screen/splash_screen.dart';
import 'viewmodel/theme_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await setupLocator();
  await locator<ThemeViewModel>().init();


  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => locator<AuthService>()),
        ChangeNotifierProvider(create: (context) => locator<ThemeViewModel>()),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeViewModel, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'LeisureRyde',
            theme: AppTheme.lightTheme,       // Provide light theme
            darkTheme: AppTheme.darkTheme,     // Provide dark theme
            themeMode: themeViewModel.themeMode, // Set the current mode
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}