import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class NotificationDiagnosticsScreen extends StatefulWidget {
  const NotificationDiagnosticsScreen({super.key});

  @override
  State<NotificationDiagnosticsScreen> createState() => _NotificationDiagnosticsScreenState();
}

class _NotificationDiagnosticsScreenState extends State<NotificationDiagnosticsScreen> {
  final Map<String, String> diagnosticResults = {};
  bool isLoading = true;
  String? fcmToken;
  String? apnsToken;

  @override
  void initState() {
    super.initState();
    runDiagnostics();
  }

  Future<void> runDiagnostics() async {
    setState(() {
      isLoading = true;
      diagnosticResults.clear();
    });

    await checkPlatform();
    await checkNotificationPermission();
    await checkApnsToken();
    await checkFcmToken();
    await checkAutoInitEnabled();
    await checkForegroundPresentationOptions();
    await saveTokenToFirestore();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> checkPlatform() async {
    diagnosticResults['Platform'] = Platform.isIOS ? 'iOS detected' : 'Not iOS (${Platform.operatingSystem})';
  }

  Future<void> checkNotificationPermission() async {
    try {
      final firebaseMessaging = FirebaseMessaging.instance;
      final notificationSettings = await firebaseMessaging.getNotificationSettings();
      diagnosticResults['Authorization Status'] = notificationSettings.authorizationStatus.toString();
      diagnosticResults['Alert Setting'] = notificationSettings.alert.toString();
      diagnosticResults['Badge Setting'] = notificationSettings.badge.toString();
      diagnosticResults['Sound Setting'] = notificationSettings.sound.toString();
      diagnosticResults['Lock Screen Setting'] = notificationSettings.lockScreen.toString();
      diagnosticResults['Notification Center Setting'] = notificationSettings.notificationCenter.toString();

      if (notificationSettings.authorizationStatus == AuthorizationStatus.notDetermined) {
        final requestedSettings = await firebaseMessaging.requestPermission(alert: true, badge: true, sound: true);
        diagnosticResults['After Request Authorization Status'] = requestedSettings.authorizationStatus.toString();
      }
    } catch (error) {
      diagnosticResults['Permission Check Error'] = error.toString();
    }
  }

  Future<void> checkApnsToken() async {
    try {
      final firebaseMessaging = FirebaseMessaging.instance;
      apnsToken = await firebaseMessaging.getAPNSToken();
      if (apnsToken == null) {
        diagnosticResults['APNS Token'] = 'NULL - This is likely the root issue. APNS token not set yet.';
      } else {
        diagnosticResults['APNS Token'] = 'Present (${apnsToken!.substring(0, 12)}...)';
      }
    } catch (error) {
      diagnosticResults['APNS Token Error'] = error.toString();
    }
  }

  Future<void> checkFcmToken() async {
    try {
      final firebaseMessaging = FirebaseMessaging.instance;
      fcmToken = await firebaseMessaging.getToken();
      if (fcmToken == null) {
        diagnosticResults['FCM Token'] = 'NULL - Failed to retrieve FCM token';
      } else {
        diagnosticResults['FCM Token'] = 'Present (${fcmToken!.substring(0, 20)}...)';
      }
    } catch (error) {
      diagnosticResults['FCM Token Error'] = error.toString();
    }
  }

  Future<void> checkAutoInitEnabled() async {
    try {
      final firebaseMessaging = FirebaseMessaging.instance;
      diagnosticResults['Auto Init Enabled'] = firebaseMessaging.isAutoInitEnabled.toString();
    } catch (error) {
      diagnosticResults['Auto Init Error'] = error.toString();
    }
  }

  Future<void> checkForegroundPresentationOptions() async {
    try {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      diagnosticResults['Foreground Presentation Options'] = 'Set successfully (alert, badge, sound)';
    } catch (error) {
      diagnosticResults['Foreground Presentation Options Error'] = error.toString();
    }
  }

  Future<void> saveTokenToFirestore() async {
    try {
      if (fcmToken == null) {
        diagnosticResults['Firestore Save'] = 'Skipped - no FCM token available';
        return;
      }

      final diagnosticData = <String, dynamic>{
        'fcmToken': fcmToken,
        'apnsToken': apnsToken,
        'platform': Platform.operatingSystem,
        'platformVersion': Platform.operatingSystemVersion,
        'timestamp': FieldValue.serverTimestamp(),
        'authorizationStatus': diagnosticResults['Authorization Status'],
      };

      await FirebaseFirestore.instance.collection('notificationDiagnostics').add(diagnosticData);

      diagnosticResults['Firestore Save'] = 'Saved successfully - check notificationDiagnostics collection';
    } catch (error) {
      diagnosticResults['Firestore Save Error'] = error.toString();
    }
  }

  Future<void> sendTestNotificationToSelf() async {
    if (fcmToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No FCM token available to send test notification')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('testNotificationRequests').add({
        'targetToken': fcmToken,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification request queued. Check your Cloud Function logs.')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error queuing test notification: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: runDiagnostics,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (fcmToken != null)
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Full FCM Token (tap to copy)', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SelectableText(fcmToken!, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ...diagnosticResults.entries.map((entry) {
                  final isError = entry.key.contains('Error') || entry.value.contains('NULL') || entry.value.contains('denied');
                  return Card(
                    color: isError ? Colors.red.shade50 : Colors.green.shade50,
                    child: ListTile(
                      leading: Icon(
                        isError ? Icons.error_outline : Icons.check_circle_outline,
                        color: isError ? Colors.red : Colors.green,
                      ),
                      title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(entry.value),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: sendTestNotificationToSelf,
                  child: const Text('Queue Test Notification'),
                ),
              ],
            ),
    );
  }
}