import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class Payment{

 final secretkey = "sk_test_51OZFSaHgohLFgzD9XaARhprvgpkTqmJUWwtFkXPTgyaajA0TuuPUSFVFLmHNAdnyKbcg68uhmz3RVtPqy6tMKt1C00AuREqvxV";
  createPaymentIntent(String amount,String currency) async {
    try{
      final response = await http.post(
        Uri.parse("https://api.stripe.com/v1/payment_intents"),
        headers: {
          'Authorization' : 'Bearer $secretkey',
          'Content-Type' : 'application/x-www-form-urlencoded',
        },
        body: {
          'amount' : amount,
          'currency' : currency
        }
      );

      if(response.statusCode == 200){
        if (Stripe.publishableKey.isEmpty) {
          print("Stripe key not initialized!");

        }else{
          return jsonDecode(response.body)['client_secret'];
        }
         
      }

      }catch(e){
      if (e is StripeConfigException) {
        print("Stripe exception ${e.message}");
      } else {
        print("exception $e");
      }
      }

}


Future<bool>  makePayment(amount,currency) async{
    try{
      final clientSecret = await createPaymentIntent(amount,currency);

      await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: "Leisure ride",
            style: ThemeMode.system
          )
      );

      await Stripe.instance.presentPaymentSheet();



    }catch(e){
      if (e is StripeConfigException) {
        print("Stripe exception ${e.message}");
      } else {
        print("exception $e");
      }
      return false;
    }

    return true;
  }

}