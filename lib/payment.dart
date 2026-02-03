// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:url_launcher/url_launcher.dart';
//
// class Payment {
//   final String secretKey = "sk_test_51OZFSaHgohLFgzD9XaARhprvgpkTqmJUWwtFkXPTgyaajA0TuuPUSFVFLmHNAdnyKbcg68uhmz3RVtPqy6tMKt1C00AuREqvxV";
//   final String publishableKey = "pk_test_51OZFSaHgohLFgzD9HlcOJOIBMOSLJjflsszJ2VAFa2nzNohZlSvqFCTTZ7u9bbVvo9wsiYW86VCehXZ2mqQqhwpx009JGSDueI";
//
//   Future<String?> createCheckoutSession(String amount, String currency) async {
//     try {
//       final response = await http.post(
//         Uri.parse("https://api.stripe.com/v1/checkout/sessions"),
//         headers: {
//           'Authorization': 'Bearer $secretKey',
//           'Content-Type': 'application/x-www-form-urlencoded',
//         },
//         body: {
//           'payment_method_types[]': 'card',
//           'line_items[0][price_data][currency]': currency,
//           'line_items[0][price_data][unit_amount]': amount,
//           'line_items[0][price_data][product_data][name]': 'Leisure Ride',
//           'line_items[0][quantity]': '1',
//           'mode': 'payment',
//           'success_url': 'https://yourdomain.com/success?session_id={CHECKOUT_SESSION_ID}',
//           'cancel_url': 'https://yourdomain.com/cancelled',
//         },
//       );
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         return data['url']; // Checkout URL
//       } else {
//         print("Checkout Session Error: ${response.body}");
//         return null;
//       }
//     } catch (e) {
//       print("Create Checkout Session Exception: $e");
//       return null;
//     }
//   }
//
//   Future<bool> makePayment(String amount, String currency) async {
//     try {
//       final checkoutUrl = await createCheckoutSession(amount, currency);
//
//       if (checkoutUrl == null) {
//         print("Failed to create checkout session");
//         return false;
//       }
//
//       if (await canLaunchUrl(Uri.parse(checkoutUrl))) {
//         await launchUrl(
//           Uri.parse(checkoutUrl),
//           mode: LaunchMode.externalApplication,
//         );
//         return true;
//       } else {
//         print("Could not launch checkout URL");
//         return false;
//       }
//     } catch (e) {
//       print("Payment Exception: $e");
//       return false;
//     }
//   }
// }