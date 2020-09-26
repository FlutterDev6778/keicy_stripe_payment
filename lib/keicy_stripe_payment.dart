library keicy_stripe_payment;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:stripe_payment/stripe_payment.dart';

class KeicyStripePayment {
  static final String apiBase = 'https://api.stripe.com/v1';
  static String paymentApiUrl;
  static Map<String, String> headers;
  static String secretKey;
  static String publicKey;

  // static final KeicyStripePayment _instance = KeicyStripePayment();
  // static KeicyStripePayment get instance => _instance;

  static init({
    @required String publicKey,
    @required String secretKey,
    String merchantId = "Test",
    String androidPayMode = "test", // production
  }) {
    secretKey = secretKey;
    publicKey = publicKey;
    paymentApiUrl = '${KeicyStripePayment.apiBase}/payment_intents';
    headers = {
      'Authorization': 'Bearer $secretKey',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    StripePayment.setOptions(
      StripeOptions(publishableKey: publicKey, merchantId: merchantId, androidPayMode: androidPayMode),
    );
  }

  static Future<Map<String, dynamic>> getPaymentMethodFromExistingCard({
    CreditCard card,
    BillingAddress billingAddress,
    Map<String, String> metadata,
  }) async {
    try {
      var paymentMethod =
          await StripePayment.createPaymentMethod(PaymentMethodRequest(card: card, billingAddress: billingAddress, metadata: metadata));
      return {
        "success": true,
        "message": "Create PaymentMethod Success",
        "data": paymentMethod,
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

  static Future<Map<String, dynamic>> getPaymentMethodFromNewCard() async {
    try {
      var paymentMethod = await StripePayment.paymentRequestWithCardForm(CardFormPaymentRequest());
      return {
        "success": true,
        "message": "Create PaymentMethod Success",
        "data": paymentMethod,
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

  static Future<Map<String, dynamic>> createPaymentIntent({
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
      var result = jsonDecode(response.body);
      if (result["id"] != null) {
        return {
          "success": true,
          "message": "Create Payment Intent Success",
          'data': result,
        };
      } else {
        return {
          "success": false,
          "message": result["error"]["message"],
          "code": result["error"]["code"],
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
        "message": "Create Payment Intent Failed",
        "code": "404",
      };
    }
  }

  static Future<Map<String, dynamic>> payViaPaymentMethod({
    @required PaymentMethod paymentMethod,
    @required String amount,
    @required String currency,
  }) async {
    var paymentIntent = await createPaymentIntent(amount: amount);
    if (!paymentIntent["success"]) {
      return paymentIntent;
    } else {
      try {
        PaymentIntentResult paymentIntentResult = await StripePayment.confirmPaymentIntent(
          PaymentIntent(
            clientSecret: paymentIntent['data']['client_secret'],
            paymentMethodId: paymentMethod.id,
          ),
        );
        if (paymentIntentResult.status == 'succeeded') {
          return {
            "success": true,
            "message": 'Transaction successful',
            "paymentIntentResult": paymentIntentResult,
            "paymentIntent": paymentIntent['data'],
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
