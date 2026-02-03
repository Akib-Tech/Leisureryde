import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:leisureryde/app/service_locator.dart';
import '../../services/payment_service.dart';

enum PaymentState {
  idle,       // Nothing is happening
  loading,    // Creating the session via Cloud Function
  processing, // WebView is open, waiting for webhook
  success,    // Webhook confirmed payment
  failed,     // Payment failed (webhook or error)
  cancelled,  // User manually closed the WebView
}

class PaymentViewModel extends ChangeNotifier {
  final PaymentService _paymentService = locator<PaymentService>();

  PaymentState _state = PaymentState.idle;
  String? _errorMessage;
  String? _currentPaymentId;
  StreamSubscription<DocumentSnapshot>? _paymentListener;

  PaymentState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get currentPaymentId => _currentPaymentId;
  bool get isLoading => _state == PaymentState.loading || _state == PaymentState.processing;

  /// Step 1: Initiates the payment flow.
  /// Returns the checkout URL and payment ID needed to launch the WebView.
  /// Step 1: Initiates the payment flow.
  /// Returns the checkout URL and payment ID needed to launch the WebView.
  Future<Map<String, dynamic>?> initializePayment({
    required String amount,
    required String currency,
    required String bookingId,
  }) async {
    _updateState(PaymentState.loading);
    _errorMessage = null;

    try {
      debugPrint("🔄 Calling createStripeSessionViaFunction...");
      debugPrint("   Amount: $amount, Currency: $currency, BookingId: $bookingId");

      // Call our secure Cloud Function to get the session details
      final sessionData = await _paymentService.createStripeSessionViaFunction(
        amount: amount,
        currency: currency,
        bookingId: bookingId,
      );

      debugPrint("✅ Session created successfully!");
      debugPrint("   Response: $sessionData");

      _currentPaymentId = sessionData['paymentId'] as String;


      // IMPORTANT: Start listening for backend updates immediately
      _startPaymentListener(_currentPaymentId!);

      _updateState(PaymentState.processing);
      return sessionData; // Pass {'checkoutUrl', 'paymentId'} to the UI
    } catch (e) {
      debugPrint("❌ Payment initialization failed!");
      debugPrint("   Error Type: ${e.runtimeType}");
      debugPrint("   Error Message: $e");
      debugPrint("   Full Stack Trace: ${e is Exception ? (e as Exception).toString() : 'N/A'}");

      _errorMessage = "Failed to create payment session. Please try again.";
      _updateState(PaymentState.failed);
      return null;
    }
  }

  void handlePaymentSuccess(String paymentId) {
    _state = PaymentState.success;
    _currentPaymentId = paymentId; // Store the payment ID
    _errorMessage = null;
    notifyListeners();
  }

  /// Step 2: Listens for status changes from the webhook.
  void _startPaymentListener(String paymentId) {
    _paymentListener?.cancel(); // Cancel any previous listener
    _paymentListener = _paymentService.listenToPaymentStatus(paymentId).listen(
          (snapshot) {
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] as String;

        debugPrint("📡 Firestore Payment Status Updated: $status");

        switch (status) {
          case 'succeeded': // This status is set by our webhook
            _updateState(PaymentState.success);
            _paymentListener?.cancel(); // Stop listening on final state
            break;
          case 'failed':
            _errorMessage = data['error'] as String? ?? 'Payment failed.';
            _updateState(PaymentState.failed);
            _paymentListener?.cancel();
            break;
          case 'cancelled':
            _updateState(PaymentState.cancelled);
            _paymentListener?.cancel();
            break;
        }
      },
      onError: (error) {
        _errorMessage = "Error listening to payment status.";
        _updateState(PaymentState.failed);
      },
    );
  }

  /// Step 3: Called by the UI when the user manually closes the WebView.
  Future<void> handlePaymentCancelled() async {
    if (_currentPaymentId == null) return;

    // Only update status if payment isn't already completed
    if (_state == PaymentState.processing) {
      debugPrint("User cancelled payment. Updating status for $_currentPaymentId");
      await _paymentService.cancelPayment(_currentPaymentId!);
      _updateState(PaymentState.cancelled);
    }
    resetPayment(); // Clean up
  }

  /// Resets the ViewModel to its initial state for a new payment.
  void resetPayment() {
    _paymentListener?.cancel();
    _paymentListener = null;
    _state = PaymentState.idle;
    _errorMessage = null;
    _currentPaymentId = null;

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