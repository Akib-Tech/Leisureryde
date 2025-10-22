import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show Stripe, CardField;
import 'package:leisureryde/payment.dart';
import 'package:leisureryde/userspage/chat.dart';
import 'package:leisureryde/userspage/splash.dart';
Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  /*
 await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

   */
 // Stripe.publishableKey = "pk_test_51OZFSaHgohLFgzD9HlcOJOIBMOSLJjflsszJ2VAFa2nzNohZlSvqFCTTZ7u9bbVvo9wsiYW86VCehXZ2mqQqhwpx009JGSDueI";
  //await Stripe.instance.applySettings();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // remove debug banner
      title: 'LeisureRide',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: SplashScreen()

    );  }
}


