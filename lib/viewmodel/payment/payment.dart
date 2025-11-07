import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:leisureryde/app/service_locator.dart';

import '../../services/payment_service.dart';

enum PaymentState {
  idle,
  loading,
  processing,
  success,
  failed,
  cancelled,
}

class PaymentViewModel extends ChangeNotifier {
  final  _paymentService = locator<PaymentService>();

  // State management
  PaymentState _state = PaymentState.idle;
  String? _errorMessage;
  String? _currentPaymentId;
  Map<String, dynamic>? _paymentDetails;
  StreamSubscription<DocumentSnapshot>? _paymentListener;

  // Getters
  PaymentState get state => _state;
  String? get errorMessage => _errorMessage;
  String? get currentPaymentId => _currentPaymentId;
  Map<String, dynamic>? get paymentDetails => _paymentDetails;
  bool get isLoading => _state == PaymentState.loading || _state == PaymentState.processing;

  Future<Map<String, dynamic>?> initializePayment({
    required String amount,
    required String currency,
    required String userId,
    required String bookingId,
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
      _startPaymentListener(_currentPaymentId!);
      _updateState(PaymentState.processing);

      return sessionData;
    } catch (e) {
      _errorMessage = "Payment initialization error: $e";
      _updateState(PaymentState.failed);
      return null;
    }
  }

  /// Start listening to Firestore payment status changes
  void _startPaymentListener(String paymentId) {
    _paymentListener?.cancel(); // Cancel any existing listener

    _paymentListener = _paymentService.listenToPaymentStatus(paymentId).listen(
          (snapshot) {
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'] as String;

        print("📡 Payment status update: $status");

        switch (status) {
          case 'completed':
            _paymentDetails = data;
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
            _updateState(PaymentState.processing);
            break;
        }
      },
      onError: (error) {
        _errorMessage = "Payment listener error: $error";
        _updateState(PaymentState.failed);
      },
    );
  }

  /// Handle successful payment from WebView
  Future<void> handlePaymentSuccess(String sessionId, String paymentId) async {
    _updateState(PaymentState.processing);

    try {
      final verificationResult = await _paymentService.verifyPaymentSession(sessionId);

      if (verificationResult == null) {
        await _paymentService.updatePaymentStatus(
          paymentId: paymentId,
          status: 'failed',
          additionalData: {'error': 'Verification failed'},
        );
        _errorMessage = "Payment verification failed";
        _updateState(PaymentState.failed);
        return;
      }

      final paymentStatus = verificationResult['paymentStatus'] as String;

      if (paymentStatus == 'paid') {
        // Update Firestore
        await _paymentService.updatePaymentStatus(
          paymentId: paymentId,
          status: 'completed',
          additionalData: {
            'stripePaymentIntent': verificationResult['paymentIntent'],
            'amountTotal': verificationResult['amountTotal'],
            'customerEmail': verificationResult['customerEmail'],
            'verifiedAt': FieldValue.serverTimestamp(),
          },
        );

        _paymentDetails = verificationResult;
        _updateState(PaymentState.success);
      } else {
        await _paymentService.updatePaymentStatus(
          paymentId: paymentId,
          status: 'pending',
          additionalData: {'stripeStatus': paymentStatus},
        );
        _errorMessage = "Payment pending: $paymentStatus";
        _updateState(PaymentState.processing);
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

  /// Handle cancelled payment from WebView
  Future<void> handlePaymentCancelled(String paymentId) async {
    await _paymentService.updatePaymentStatus(
      paymentId: paymentId,
      status: 'cancelled',
    );
    _updateState(PaymentState.cancelled);
  }

  /// Reset payment state
  void resetPayment() {
    _paymentListener?.cancel();
    _state = PaymentState.idle;
    _errorMessage = null;
    _currentPaymentId = null;
    _paymentDetails = null;
    notifyListeners();
  }

  /// Update state and notify listeners
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