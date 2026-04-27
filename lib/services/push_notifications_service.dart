import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/services/database_service.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final DatabaseService _db = locator<DatabaseService>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  Future<void> initialize(String userId) async {
    // Ask iOS for alert + badge + sound; Android 13+ is handled via
    // flutter_local_notifications in main.dart.
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final granted = settings.authorizationStatus == AuthorizationStatus.authorized
        || settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!granted) return;

    final token = await _fcm.getToken();
    if (token != null) {
      await saveTokenToDatabase(token, userId);
      _fcm.onTokenRefresh.listen((newToken) {
        saveTokenToDatabase(newToken, userId);
      });
    }

    final userProfile = await _db.getUserProfile(userId);
    if (userProfile.pushNotificationsEnabled) {
      subscribeToUserTopic(userId);
    }
  }

  Future<void> saveTokenToDatabase(String token, String userId) async {
    await _firestore.collection('users').doc(userId).collection('tokens').doc(token).set({
      'token': token,
      'createdAt': FieldValue.serverTimestamp(),
      'platform': Platform.operatingSystem,
    });
  }

  void subscribeToUserTopic(String userId) {
    _fcm.subscribeToTopic('user_$userId');
  }

  void unsubscribeFromUserTopic(String userId) {
    _fcm.unsubscribeFromTopic('user_$userId');
  }

  Future<void> updateUserPushNotificationPreference(String userId, bool enable) async {
    await _db.updateUserProfileData(userId, {'pushNotificationsEnabled': enable});
    if (enable) {
      subscribeToUserTopic(userId);
    } else {
      unsubscribeFromUserTopic(userId);
    }
  }

  void subscribeToOnlineDriversTopic() {
    _fcm.subscribeToTopic('online_drivers');
  }

  void unsubscribeFromOnlineDriversTopic() {
    _fcm.unsubscribeFromTopic('online_drivers');
  }
}