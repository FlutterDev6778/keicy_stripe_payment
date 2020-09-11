library keicy_stripe_payment;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:stripe_payment/stripe_payment.dart';

class StripeTransactionResponse {
  String message;
  bool success;
  StripeTransactionResponse({this.message, this.success});
}

class KeicyStripePayment {
  static String apiBase = 'https://api.stripe.com/v1';
  static String paymentApiUrl = '${KeicyStripePayment.apiBase}/payment_intents';
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
    headers = {
      'Authorization': 'Bearer $secretKey',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    StripePayment.setOptions(
      StripeOptions(publishableKey: this.publicKey, merchantId: merchantId, androidPayMode: androidPayMode),
    );
  }

  Future<StripeTransactionResponse> payViaExistingCard({String amount, String currency, CreditCard card}) async {
    try {
      var paymentMethod = await StripePayment.createPaymentMethod(PaymentMethodRequest(card: card));
      var paymentIntent = await createPaymentIntent(amount, currency);
      var response = await StripePayment.confirmPaymentIntent(
        PaymentIntent(clientSecret: paymentIntent['client_secret'], paymentMethodId: paymentMethod.id),
      );
      if (response.status == 'succeeded') {
        return new StripeTransactionResponse(message: 'Transaction successful', success: true);
      } else {
        return new StripeTransactionResponse(message: 'Transaction failed', success: false);
      }
    } on PlatformException catch (err) {
      return getPlatformExceptionErrorResult(err);
    } catch (err) {
      return new StripeTransactionResponse(message: 'Transaction failed', success: false);
    }
  }

  Future<StripeTransactionResponse> payWithNewCard({String amount, String currency}) async {
    try {
      var paymentMethod = await StripePayment.paymentRequestWithCardForm(CardFormPaymentRequest());
      var paymentIntent = await createPaymentIntent(amount, currency);
      var response =
          await StripePayment.confirmPaymentIntent(PaymentIntent(clientSecret: paymentIntent['client_secret'], paymentMethodId: paymentMethod.id));
      if (response.status == 'succeeded') {
        return new StripeTransactionResponse(message: 'Transaction successful', success: true);
      } else {
        return new StripeTransactionResponse(message: 'Transaction failed', success: false);
      }
    } on PlatformException catch (err) {
      return getPlatformExceptionErrorResult(err);
    } catch (err) {
      return new StripeTransactionResponse(message: 'Transaction failed: ${err.toString()}', success: false);
    }
  }

  getPlatformExceptionErrorResult(PlatformException err) {
    String message = 'Something went wrong';
    if (err.code == 'cancelled') {
      message = 'Transaction cancelled';
    }

    return new StripeTransactionResponse(message: err.message, success: false);
  }

  Future<Map<String, dynamic>> createPaymentIntent(String amount, String currency) async {
    try {
      Map<String, dynamic> body = {'amount': amount, 'currency': currency, 'payment_method_types[]': 'card'};
      var response = await http.post(KeicyStripePayment.paymentApiUrl, body: body, headers: headers);
      return jsonDecode(response.body);
    } catch (err) {
      print('err charging user: ${err.toString()}');
    }
    return null;
  }
}
