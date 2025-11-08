// lib/viewmodel/payment/payment_view_model.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:leisureryde/app/service_locator.dart';
import '../../services/payment_service.dart';

enum PaymentState {
  idle,
  loading, // Initializing session with backend
  processing, // WebView launched or awaiting webhook
  success,
  failed,
  cancelled,
}

class PaymentViewModel extends ChangeNotifier {
  final PaymentService _paymentService = locator<PaymentService>();

  PaymentState _state = PaymentState.idle;
  String? _errorMessage;
  String? _currentPaymentId;
  Map<String, dynamic>? _paymentDetails; // Stores verified details
  StreamSubscription<DocumentSnapshot>? _paymentListener;

  PaymentState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get currentPaymentId => _currentPaymentId;
  Map<String, dynamic>? get paymentDetails => _paymentDetails;
  bool get isLoading => _state == PaymentState.loading || _state == PaymentState.processing;

  Future<Map<String, dynamic>?> initializePayment({
    required String amount, // e.g., "12.34"
    required String currency,
    required String userId,
    required String bookingId, // Use ride ID here
    Map<String, dynamic>? metadata,
  }) async {
    _updateState(PaymentState.loading);
    _errorMessage = null;

    try {
      final sessionData = await _paymentService.createCheckoutSession(
        amount: amount,
        currency: currency,
        userId: userId,
        bookingId: bookingId,
        metadata: metadata,
      );

      if (sessionData == null) {
        _errorMessage = "Failed to create payment session";
        _updateState(PaymentState.failed);
        return null;
      }

      _currentPaymentId = sessionData['paymentId'] as String;
      _startPaymentListener(_currentPaymentId!); // Start listening to Firestore
      _updateState(PaymentState.processing); // Move to processing as WebView is about to launch

      return sessionData;
    } catch (e) {
      _errorMessage = "Payment initialization error: $e";
      _updateState(PaymentState.failed);
      return null;
    }
  }

  void _startPaymentListener(String paymentId) {
    _paymentListener?.cancel();

    _paymentListener = _paymentService.listenToPaymentStatus(paymentId).listen(
          (snapshot) {
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] as String;

        debugPrint("📡 Payment status update: $status for $paymentId (from Firestore listener)");

        switch (status) {
          case 'completed':
            _paymentDetails = data; // Store details from Firestore (could include Stripe's paymentIntentId, etc.)
            _updateState(PaymentState.success);
            _paymentListener?.cancel();
            break;
          case 'failed':
            _errorMessage = data['error'] as String? ?? 'Payment failed';
            _updateState(PaymentState.failed);
            _paymentListener?.cancel();
            break;
          case 'cancelled':
            _updateState(PaymentState.cancelled);
            _paymentListener?.cancel();
            break;
          case 'pending':
          case 'processing':
            _updateState(PaymentState.processing); // Keep as processing if still pending/waiting
            break;
        }
      },
      onError: (error) {
        _errorMessage = "Payment listener error: $error";
        _updateState(PaymentState.failed);
      },
    );
  }

  Future<void> handlePaymentSuccess(String sessionId, String paymentId) async {
    debugPrint("PaymentViewModel: handlePaymentSuccess called for session $sessionId, payment $paymentId");
    _updateState(PaymentState.processing); // Stay in processing while verifying

    try {
      final verificationResult = await _paymentService.verifyPaymentSession(sessionId);

      if (verificationResult == null) {
        // If Stripe verification fails, update Firestore payment status
        await _paymentService.updatePaymentStatus(
          paymentId: paymentId,
          status: 'failed',
          additionalData: {'error': 'Verification failed after webview success'},
        );
        _errorMessage = "Payment verification failed";
        _updateState(PaymentState.failed);
        return;
      }

      final paymentStatus = verificationResult['paymentStatus'] as String;
      final stripePaymentIntent = verificationResult['paymentIntent'] as String?;
      final amountTotal = verificationResult['amountTotal'] as int?; // in cents
      final customerEmail = verificationResult['customerEmail'] as String?;

      if (paymentStatus == 'paid') {
        // Update Firestore payment status to completed
        await _paymentService.updatePaymentStatus(
          paymentId: paymentId,
          status: 'completed',
          additionalData: {
            'stripeSessionId': sessionId, // Store session ID in payment record
            'stripePaymentIntent': stripePaymentIntent,
            'amountTotalCents': amountTotal, // Store amount in cents from Stripe
            'customerEmail': customerEmail,
            'verifiedAt': FieldValue.serverTimestamp(),
          },
        );

        _paymentDetails = { // Store details for HomeViewModel
          'paymentId': paymentId,
          'stripeSessionId': sessionId,
          'stripePaymentIntent': stripePaymentIntent,
          'amountTotal': amountTotal,
          'customerEmail': customerEmail,
        };
        _updateState(PaymentState.success);
      } else {
        // Payment might still be processing or failed on Stripe's side
        await _paymentService.updatePaymentStatus(
          paymentId: paymentId,
          status: 'pending', // Or 'failed' depending on specific Stripe status
          additionalData: {'stripeStatus': paymentStatus},
        );
        _errorMessage = "Payment pending or failed: $paymentStatus";
        _updateState(PaymentState.processing); // Keep processing or move to failed
      }
    } catch (e) {
      await _paymentService.updatePaymentStatus(
        paymentId: paymentId,
        status: 'failed',
        additionalData: {'error': e.toString()},
      );
      _errorMessage = "Verification error: $e";
      _updateState(PaymentState.failed);
    }
  }

  Future<void> handlePaymentCancelled(String paymentId) async {
    debugPrint("PaymentViewModel: handlePaymentCancelled called for payment $paymentId");
    await _paymentService.updatePaymentStatus(
      paymentId: paymentId,
      status: 'cancelled',
    );
    _updateState(PaymentState.cancelled);
  }

  void resetPayment() {
    _paymentListener?.cancel();
    _state = PaymentState.idle;
    _errorMessage = null;
    _currentPaymentId = null;
    _paymentDetails = null;
    notifyListeners();
  }

  void _updateState(PaymentState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _paymentListener?.cancel();
    super.dispose();
  }
}