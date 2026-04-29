
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:leisureryde/viewmodel/home/home_view_model.dart';
import 'package:leisureryde/viewmodel/payment/payment.dart';
import 'package:provider/provider.dart';

import 'app/app_theme.dart';
import 'app/service_locator.dart';
import 'firebase_options.dart';
import 'screens/shared/splash_screen/splash_screen.dart';
import 'viewmodel/theme_view_model.dart';

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

// Android group key — all ride-request notifications share this key so the OS
// collapses them into a single stack instead of showing each one separately.
const String _rideGroupKey = 'com.leisureryde.rides';

// ID 0 is reserved for the group-summary notification; individual ones start at 1.
const int _rideSummaryId = 0;
int _nextNotifId = 1;

AndroidNotificationDetails _androidDetails({bool isSummary = false}) =>
    AndroidNotificationDetails(
      'default_channel',
      'General',
      importance: Importance.max,
      priority: Priority.high,
      groupKey: _rideGroupKey,
      setAsGroupSummary: isSummary,
    );

const DarwinNotificationDetails _iosDetails = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
);

/// Shows a notification and updates the Android group summary so the OS
/// collapses multiple notifications into a single stack in the drawer.
Future<void> _showGrouped(
    FlutterLocalNotificationsPlugin plugin, int id, String? title, String? body) async {
  await plugin.show(
    id,
    title,
    body,
    NotificationDetails(android: _androidDetails(), iOS: _iosDetails),
  );
  // The summary notification is required for Android to group the stack.
  await plugin.show(
    _rideSummaryId,
    'LeisureRyde',
    'You have new ride notifications',
    NotificationDetails(android: _androidDetails(isSummary: true)),
  );
}

// @pragma is required so the tree-shaker keeps this in release builds.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
  await _local.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  // Read from the data map first (Android data-only messages), then fall back
  // to the notification object (iOS / legacy notification messages).
  final title = message.data['title'] ?? message.notification?.title;
  final body = message.data['body'] ?? message.notification?.body;
  if (title != null || body != null) {
    // Use a timestamp-based ID in this isolate — the shared counter is not
    // accessible across isolates, and collisions are extremely unlikely.
    final id = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    await _showGrouped(_local, id, title as String?, body as String?);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await setupLocator();

  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await _local.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  // Android 13+ runtime notification permission.
  await _local
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final title = message.data['title'] ?? message.notification?.title;
    final body = message.data['body'] ?? message.notification?.body;
    if (title != null || body != null) {
      _showGrouped(_local, _nextNotifId++, title as String?, body as String?);
    }
  });

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
            theme: AppTheme.darkTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeViewModel.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
