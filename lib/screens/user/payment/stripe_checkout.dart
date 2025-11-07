import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StripeCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;
  final String sessionId;
  final String paymentId;
  final Function(String sessionId, String paymentId) onPaymentSuccess;
  final Function(String paymentId) onPaymentCancelled;

  const StripeCheckoutScreen({
    Key? key,
    required this.checkoutUrl,
    required this.sessionId,
    required this.paymentId,
    required this.onPaymentSuccess,
    required this.onPaymentCancelled,
  }) : super(key: key);

  @override
  State<StripeCheckoutScreen> createState() => _StripeCheckoutScreenState();
}

class _StripeCheckoutScreenState extends State<StripeCheckoutScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
            _handleNavigation(url);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            // Intercept custom scheme URLs
            if (request.url.startsWith('leisureryde://')) {
              _handleDeepLink(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            print("WebView Error: ${error.description}");
            _showErrorDialog(error.description);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _handleNavigation(String url) {
    // Handle success/cancel URLs
    if (url.contains('leisureryde://payment/success')) {
      _handleDeepLink(url);
    } else if (url.contains('leisureryde://payment/cancel')) {
      _handleDeepLink(url);
    }
  }

  void _handleDeepLink(String url) {
    final uri = Uri.parse(url);

    if (uri.path == '/payment/success') {
      final sessionId = uri.queryParameters['session_id'] ?? widget.sessionId;
      final paymentId = uri.queryParameters['payment_id'] ?? widget.paymentId;

      Navigator.pop(context);
      widget.onPaymentSuccess(sessionId, paymentId);
    }
    else if (uri.path == '/payment/cancel') {
      final paymentId = uri.queryParameters['payment_id'] ?? widget.paymentId;

      Navigator.pop(context);
      widget.onPaymentCancelled(paymentId);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close webview
              widget.onPaymentCancelled(widget.paymentId);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        widget.onPaymentCancelled(widget.paymentId);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Secure Payment'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.pop(context);
              widget.onPaymentCancelled(widget.paymentId);
            },
          ),
          backgroundColor: Colors.blueAccent,
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _webViewController),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}