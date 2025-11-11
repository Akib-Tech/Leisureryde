
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:leisureryde/viewmodel/account/account_view_model.dart';
import 'package:leisureryde/viewmodel/home/home_view_model.dart';
import 'package:leisureryde/viewmodel/payment/payment.dart';
import 'package:provider/provider.dart';

import 'app/app_theme.dart';
import 'app/service_locator.dart';
import 'firebase_options.dart';
import 'screens/shared/splash_screen/splash_screen.dart';
import 'viewmodel/theme_view_model.dart';

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  RemoteNotification? notif = message.notification;
  if (notif != null) {
    _local.show(
      notif.hashCode,
      notif.title,
      notif.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          'General',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await setupLocator();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  //
  // const AndroidInitializationSettings androidInit =
  // AndroidInitializationSettings('@mipmap/ic_launcher');
  // const InitializationSettings initSettings =
  // InitializationSettings(android: androidInit);
  // await _local.initialize(initSettings);
  // await locator<ThemeViewModel>().init();


  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => locator<AuthService>()),
        ChangeNotifierProvider(create: (context) => locator<PaymentViewModel>()),
        ChangeNotifierProvider(create: (context) => locator<HomeViewModel>()),

        ChangeNotifierProvider(create: (context) => locator<ThemeViewModel>()),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeViewModel, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'LeisureRyde',
            theme: AppTheme.darkTheme,       // Provide light theme
            darkTheme: AppTheme.darkTheme,     // Provide dark theme
            themeMode: themeViewModel.themeMode, // Set the current mode
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}