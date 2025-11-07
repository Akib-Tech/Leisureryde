import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentService {
  static const String _secretKey = "sk_test_51OZFSaHgohLFgzD9XaARhprvgpkTqmJUWwtFkXPTgyaajA0TuuPUSFVFLmHNAdnyKbcg68uhmz3RVtPqy6tMKt1C00AuREqvxV";

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> createCheckoutSession({
    required String amount,
    required String currency,
    required String userId,
    required String bookingId,
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
      });

      final Map<String, String> requestBody = {
        'payment_method_types[]': 'card',
        'line_items[0][price_data][currency]': currency,
        'line_items[0][price_data][unit_amount]': amount,
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

      // Create Stripe session
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

        // Update Firestore with Stripe session ID
        await paymentDocRef.update({
          'stripeSessionId': data['id'],
          'checkoutUrl': data['url'],
        });

        return {
          'paymentId': paymentId,
          'sessionId': data['id'],
          'checkoutUrl': data['url'],
          'amount': data['amount_total'],
          'currency': data['currency'],
        };
      } else {
        print("Checkout Session Error: ${response.body}");
        await paymentDocRef.update({'status': 'failed', 'error': response.body});
        return null;
      }
    } catch (e) {
      print("Create Checkout Session Exception: $e");
      return null;
    }
  }

  /// Verify payment status from Stripe
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
          'amountTotal': data['amount_total'],
          'customerEmail': data['customer_details']?['email'],
          'metadata': data['metadata'],
        };
      } else {
        print("Verify Session Error: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Verify Payment Exception: $e");
      return null;
    }
  }

  /// Update payment status in Firestore
  /// Update payment status in Firestore
  Future<void> updatePaymentStatus({
    required String paymentId,
    required String status,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Use Map<String, Object> instead of Map<String, dynamic>
      final Map<String, Object> updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (additionalData != null) {
        // Convert dynamic values to Object and add them
        additionalData.forEach((key, value) {
          if (value != null) {
            updateData[key] = value as Object;
          }
        });
      }

      await _firestore.collection('payments').doc(paymentId).update(updateData);
    } catch (e) {
      print("Update Payment Status Exception: $e");
    }
  }
  /// Listen to payment status changes (Real-time)
  Stream<DocumentSnapshot> listenToPaymentStatus(String paymentId) {
    return _firestore.collection('payments').doc(paymentId).snapshots();
  }
}