import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Calls the 'createStripeCheckout' Cloud Function to securely generate a Stripe session.
  Future<Map<String, dynamic>> createStripeSessionViaFunction({
    required String amount,
    required String currency,
    required String bookingId,
  }) async {
    try {
      // The name here ('createStripeCheckout') must exactly match the function name in index.js
      final HttpsCallable callable = _functions.httpsCallable('createStripeCheckout');

      final response = await callable.call<Map<String, dynamic>>({
        'amount': amount,
        'currency': currency,
        'bookingId': bookingId,
      });

      return response.data; // Expected to return {'checkoutUrl': '...', 'paymentId': '...'}
    } on FirebaseFunctionsException catch (e) {
      debugPrint("Cloud Functions Error: ${e.code} - ${e.message}");
      rethrow; // Rethrow to be caught by the ViewModel
    } catch (e) {
      debugPrint("Generic Error calling createStripeSessionViaFunction: $e");
      rethrow;
    }
  }

  /// Listens to real-time status changes of a payment document in Firestore.
  Stream<DocumentSnapshot> listenToPaymentStatus(String paymentId) {
    return _firestore.collection('payments').doc(paymentId).snapshots();
  }

  /// Updates a payment document's status, typically used for cancellation.
  Future<void> cancelPayment(String paymentId) async {
    try {
      await _firestore.collection('payments').doc(paymentId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // It's okay if this fails (e.g., document doesn't exist yet).
      // The main goal is to stop listening.
      debugPrint("Could not mark payment as cancelled: $e");
    }
  }
}