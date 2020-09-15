library keicy_stripe_payment;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:stripe_payment/stripe_payment.dart';

class KeicyStripePayment {
  static String apiBase = 'https://api.stripe.com/v1';
  String paymentApiUrl;
  Map<String, String> headers;
  String secretKey;
  String publicKey;

  KeicyStripePayment _instance = KeicyStripePayment();
  KeicyStripePayment get instance => _instance;

  init({
    @required String publicKey,
    @required String secretKey,
    String merchantId = "Test",
    String androidPayMode = "Test", // production
  }) {
    this.secretKey = secretKey;
    this.publicKey = publicKey;
    this.paymentApiUrl = '${KeicyStripePayment.apiBase}/payment_intents';
    headers = {
      'Authorization': 'Bearer $secretKey',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    StripePayment.setOptions(
      StripeOptions(publishableKey: this.publicKey, merchantId: merchantId, androidPayMode: androidPayMode),
    );
  }

  Future<Map<String, dynamic>> getPaymentMethodFromExistingCard(CreditCard card) async {
    try {
      var paymentMethod = await StripePayment.createPaymentMethod(PaymentMethodRequest(card: card));
      return {
        "success": true,
        "message": "Create PaymentMethod Success",
        "data": paymentMethod.toJson(),
      };
    } on PlatformException catch (err) {
      print('getPaymentMethodFromExistingCard: ${err.toString()}');
      return {
        "success": false,
        "message": err.message,
        "code": err.code,
      };
    } catch (err) {
      return {
        "success": false,
        "message": "Create PaymentMethod Failed",
        "code": "404",
      };
    }
  }

  Future<Map<String, dynamic>> getPaymentMethodFromNewCard() async {
    try {
      var paymentMethod = await StripePayment.paymentRequestWithCardForm(CardFormPaymentRequest());
      return {
        "success": true,
        "message": "Create PaymentMethod Success",
        "data": paymentMethod.toJson(),
      };
    } on PlatformException catch (err) {
      return {
        "success": false,
        "message": err.message,
        "code": err.code,
      };
    } catch (err) {
      print('getPaymentMethodFromNew: ${err.toString()}');
      return {
        "success": false,
        "message": "Create PaymentMethod Failed",
        "code": "404",
      };
    }
  }

  Future<Map<String, dynamic>> createPaymentIntent({
    @required String amount,
    String currency = 'usd',
    String paymentMethodTypes = 'card',
  }) async {
    try {
      Map<String, dynamic> body = {
        'amount': amount,
        'currency': currency,
        'payment_method_types[]': paymentMethodTypes,
      };
      var response = await http.post(paymentApiUrl, body: body, headers: headers);
      return {
        "success": true,
        "message": "Create Payment Intent Success",
        'data': jsonDecode(response.body),
      };
    } on PlatformException catch (err) {
      return {
        "success": false,
        "message": err.message,
        "code": err.code,
      };
    } catch (err) {
      print('createPaymentIntentViaCard: ${err.toString()}');
      return {
        "success": false,
        "message": "Create Payment Intent Failed",
        "code": "404",
      };
    }
  }

  Future<Map<String, dynamic>> payViaPaymentMethod({
    @required Map<String, dynamic> jsonData,
    @required String amount,
    @required String currency,
  }) async {
    PaymentMethod paymentMethod = PaymentMethod.fromJson(jsonData);

    var paymentIntent = await createPaymentIntent(amount: amount);
    if (!paymentIntent["success"]) {
      return paymentIntent;
    } else {
      try {
        var response = await StripePayment.confirmPaymentIntent(
          PaymentIntent(
            clientSecret: paymentIntent['data']['client_secret'],
            paymentMethodId: paymentMethod.id,
          ),
        );
        if (response.status == 'succeeded') {
          return {
            "success": true,
            "message": 'Transaction successful',
          };
        } else {
          return {
            "success": false,
            "message": 'Transaction failed',
          };
        }
      } on PlatformException catch (err) {
        return {
          "success": false,
          "message": err.message,
          "code": err.code,
        };
      } catch (err) {
        print('createPaymentIntentViaCard: ${err.toString()}');
        return {
          "success": false,
          "message": 'Transaction failed',
          "code": "404",
        };
      }
    }
  }
}
