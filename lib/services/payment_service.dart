// lib/services/payment_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class PaymentService {
  static const String _secretKey = "sk_test_51OZFSaHgohLFgzD9XaARhprvgpkTqmJUWwtFkXPTgyaajA0TuuPUSFVFLmHNAdnyKbcg68uhmz3RVtPqy6tMKt1C00AuREqvxV";

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> createCheckoutSession({
    required String amount, // Amount as a string, e.g., "12.34"
    required String currency,
    required String userId,
    required String bookingId, // This is your rideId or a temporary booking ID
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final paymentDocRef = _firestore.collection('payments').doc();
      final paymentId = paymentDocRef.id;

      await paymentDocRef.set({
        'userId': userId,
        'bookingId': bookingId,
        'amount': amount,
        'currency': currency,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
        'paymentMethod': 'card', // Assuming card for Stripe Checkout
      });

      // Convert amount string to integer cents for Stripe API
      final int amountInCents = (double.parse(amount) * 100).toInt();

      final Map<String, String> requestBody = {
        'payment_method_types[]': 'card',
        'line_items[0][price_data][currency]': currency,
        'line_items[0][price_data][unit_amount]': amountInCents.toString(),
        'line_items[0][price_data][product_data][name]': 'Leisure Ride Service',
        'line_items[0][quantity]': '1',
        'mode': 'payment',

        'success_url': 'leisureryde://payment/success?session_id={CHECKOUT_SESSION_ID}&payment_id=$paymentId',
        'cancel_url': 'leisureryde://payment/cancel?payment_id=$paymentId',

        // Store Firebase payment ID in Stripe metadata
        'metadata[payment_id]': paymentId,
        'metadata[user_id]': userId,
        'metadata[booking_id]': bookingId,
        'metadata[platform]': 'mobile_app',
      };

      // Add custom metadata if provided
      if (metadata != null) {
        metadata.forEach((key, value) {
          requestBody['metadata[$key]'] = value.toString();
        });
      }

      final response = await http.post(
        Uri.parse("https://api.stripe.com/v1/checkout/sessions"),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await paymentDocRef.update({
          'stripeSessionId': data['id'],
          'checkoutUrl': data['url'],
        });

        return {
          'paymentId': paymentId,
          'sessionId': data['id'],
          'checkoutUrl': data['url'],
          'amount': data['amount_total'], // in cents
          'currency': data['currency'],
        };
      } else {
        debugPrint("Checkout Session Error: ${response.body}");
        await paymentDocRef.update({'status': 'failed', 'error': response.body});
        return null;
      }
    } catch (e) {
      debugPrint("Create Checkout Session Exception: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> verifyPaymentSession(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse("https://api.stripe.com/v1/checkout/sessions/$sessionId"),
        headers: {
          'Authorization': 'Bearer $_secretKey',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'paymentStatus': data['payment_status'],
          'paymentIntent': data['payment_intent'],
          'amountTotal': data['amount_total'], // in cents
          'customerEmail': data['customer_details']?['email'],
          'metadata': data['metadata'],
        };
      } else {
        debugPrint("Verify Session Error: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Verify Payment Exception: $e");
      return null;
    }
  }

  Future<void> updatePaymentStatus({
    required String paymentId,
    required String status,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final Map<String, Object?> updateData = { // Use Object? for nullable values
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (additionalData != null) {
        additionalData.forEach((key, value) {
          updateData[key] = value;
        });
      }

      await _firestore.collection('payments').doc(paymentId).update(updateData);
    } catch (e) {
      debugPrint("Update Payment Status Exception: $e");
    }
  }

  Stream<DocumentSnapshot> listenToPaymentStatus(String paymentId) {
    return _firestore.collection('payments').doc(paymentId).snapshots();
  }
}