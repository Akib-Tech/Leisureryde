import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StripeCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;
  // We no longer need callbacks here, it will pop with a result.
  const StripeCheckoutScreen({
    Key? key,
    required this.checkoutUrl,
  }) : super(key: key);

  @override
  State<StripeCheckoutScreen> createState() => _StripeCheckoutScreenState();
}

class _StripeCheckoutScreenState extends State<StripeCheckoutScreen> {
  late final WebViewController _controller;

  // --- CRITICAL DEBUGGING STEP ---
  // Make sure these URLs are IDENTICAL to the ones you configured when creating
  // the Stripe Checkout Session on your backend server.
  // Example: "https://yourdomain.com/success"
  final String successUrl = "https://example.com/success";
  final String cancelUrl = "https://example.com/cancel";

  bool _isPopping = false; // Prevents double-pop issues

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // Log every navigation request to debug URL issues
            debugPrint("[StripeCheckoutScreen] Navigating to: ${request.url}");

            if (request.url.startsWith(successUrl) && !_isPopping) {
              _isPopping = true;
              debugPrint("✅ [StripeCheckoutScreen] SUCCESS redirect detected. Popping with TRUE.");
              // Pop with a success result
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent; // Stop the navigation
            }
            if (request.url.startsWith(cancelUrl) && !_isPopping) {
              _isPopping = true;
              debugPrint("🟡 [StripeCheckoutScreen] CANCEL redirect detected. Popping with FALSE.");
              // Pop with a failure/cancel result
              Navigator.of(context).pop(false);
              return NavigationDecision.prevent; // Stop the navigation
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  void dispose() {
    _controller.loadRequest(Uri.parse('about:blank'));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Secure Payment"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (!_isPopping) {
              _isPopping = true;
              debugPrint("🟡 [StripeCheckoutScreen] Manual cancel (X button) pressed. Popping with FALSE.");
              // The user manually closed the page
              Navigator.of(context).pop(false);
            }
          },
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}