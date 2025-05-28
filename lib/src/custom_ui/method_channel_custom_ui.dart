import 'package:flutter/services.dart';
import '../../flutter_hyperpay.dart';
import '../helper/helper.dart';

/// Enhanced implementation of custom UI payment with detailed error handling and logging
Future<PaymentResultData> implementPaymentCustomUI({
  required String brand,
  required String checkoutId,
  required String shopperResultUrl,
  required String channelName,
  required PaymentMode paymentMode,
  required String cardNumber,
  required String holderName,
  required String month,
  required String year,
  required String cvv,
  required String lang,
  required bool enabledTokenization,
}) async {
  // Enhanced logging
  print('HyperPay: Starting payment with CustomUI');
  print('HyperPay: CheckoutId: $checkoutId');
  print('HyperPay: Brand: $brand');
  print('HyperPay: PaymentMode: $paymentMode');
  print('HyperPay: Card Number: ${cardNumber.length > 4 ? cardNumber.substring(0, 4) + "****" : "****"}');
  print('HyperPay: Holder Name: $holderName');
  print('HyperPay: Expiry: $month/$year');
  print('HyperPay: Tokenization: $enabledTokenization');

  String transactionStatus;
  var platform = MethodChannel(channelName);

  try {
    // Client-side validation before sending to iOS
    final validationError = _validateCardDetails(
      cardNumber: cardNumber,
      holderName: holderName,
      month: month,
      year: year,
      cvv: cvv,
      brand: brand,
      checkoutId: checkoutId,
    );

    if (validationError != null) {
      print('HyperPay: Client-side validation failed: ${validationError.errorString}');
      return validationError;
    }

    final Map<String, dynamic> paymentArgs = getCustomUIPaymentArgs(
      brand: brand,
      checkoutId: checkoutId,
      shopperResultUrl: shopperResultUrl,
      paymentMode: paymentMode,
      cardNumber: cardNumber,
      holderName: holderName,
      month: month,
      year: year,
      cvv: cvv,
      lang: lang,
      enabledTokenization: enabledTokenization,
    );

    print('HyperPay: Sending custom UI payment arguments');

    final String? result = await platform.invokeMethod(
      PaymentConst.methodCall,
      paymentArgs,
    );

    transactionStatus = '$result';
    print('HyperPay: Received result from iOS: $transactionStatus');

    return PaymentResultManger.getPaymentResult(transactionStatus);
  } on PlatformException catch (e) {
    print('HyperPay: PlatformException caught');
    print('HyperPay: Error Code: ${e.code}');
    print('HyperPay: Error Message: ${e.message}');
    print('HyperPay: Error Details: ${e.details}');

    transactionStatus = "${e.message}";

    return PaymentResultData(
      errorString: _getEnhancedErrorMessage(e),
      paymentResult: _getPaymentResultFromException(e),
      errorCode: e.code,
      errorDetails: e.details?.toString(),
    );
  } catch (e) {
    print('HyperPay: Unexpected error: $e');

    return PaymentResultData(
      errorString: 'An unexpected error occurred. Please try again.',
      paymentResult: PaymentResult.error,
      errorCode: 'UNEXPECTED_ERROR',
      errorDetails: e.toString(),
    );
  }
}

/// Client-side validation for card details
PaymentResultData? _validateCardDetails({
  required String cardNumber,
  required String holderName,
  required String month,
  required String year,
  required String cvv,
  required String brand,
  required String checkoutId,
}) {
  // Validate checkout ID
  if (checkoutId.isEmpty) {
    return PaymentResultData(
      errorString: 'Invalid payment session. Please try again.',
      paymentResult: PaymentResult.error,
      errorCode: 'INVALID_CHECKOUT_ID',
      errorDetails: 'Checkout ID is empty',
    );
  }

  // Validate card number
  String cleanCardNumber = cardNumber.replaceAll(RegExp(r'\D'), '');
  if (cleanCardNumber.isEmpty) {
    return PaymentResultData(
      errorString: 'Please enter a valid card number.',
      paymentResult: PaymentResult.error,
      errorCode: 'INVALID_CARD_NUMBER',
      errorDetails: 'Card number is empty',
    );
  }

  if (cleanCardNumber.length < 13 || cleanCardNumber.length > 19) {
    return PaymentResultData(
      errorString: 'Please enter a valid card number.',
      paymentResult: PaymentResult.error,
      errorCode: 'INVALID_CARD_NUMBER',
      errorDetails: 'Card number length is invalid: ${cleanCardNumber.length}',
    );
  }

  // Basic Luhn algorithm check
  if (!_isValidLuhn(cleanCardNumber)) {
    return PaymentResultData(
      errorString: 'Please enter a valid card number.',
      paymentResult: PaymentResult.error,
      errorCode: 'INVALID_CARD_NUMBER',
      errorDetails: 'Card number failed Luhn check',
    );
  }

  // Validate holder name
  if (holderName.trim().isEmpty) {
    return PaymentResultData(
      errorString: 'Please enter the cardholder name.',
      paymentResult: PaymentResult.error,
      errorCode: 'INVALID_CARD_HOLDER',
      errorDetails: 'Holder name is empty',
    );
  }

  if (holderName.trim().length < 2) {
    return PaymentResultData(
      errorString: 'Please enter a valid cardholder name.',
      paymentResult: PaymentResult.error,
      errorCode: 'INVALID_CARD_HOLDER',
      errorDetails: 'Holder name is too short',
    );
  }

  // Validate expiry month
  int? monthInt = int.tryParse(month);
  if (monthInt == null || monthInt < 1 || monthInt > 12) {
    return PaymentResultData(
      errorString: 'Please enter a valid expiry month.',
      paymentResult: PaymentResult.error,
      errorCode: 'INVALID_EXPIRY_MONTH',
      errorDetails: 'Month value: $month',
    );
  }

  // Validate expiry year
  int? yearInt = int.tryParse(year);
  int currentYear = DateTime.now().year;
  if (yearInt == null || yearInt < currentYear || yearInt > (currentYear + 20)) {
    return PaymentResultData(
      errorString: 'Please enter a valid expiry year.',
      paymentResult: PaymentResult.error,
      errorCode: 'INVALID_EXPIRY_YEAR',
      errorDetails: 'Year value: $year, Current year: $currentYear',
    );
  }

  // Check if card is expired
  DateTime cardExpiry = DateTime(yearInt, monthInt + 1, 0); // Last day of expiry month
  DateTime now = DateTime.now();
  if (cardExpiry.isBefore(now)) {
    return PaymentResultData(
      errorString: 'Your card has expired. Please use a different card.',
      paymentResult: PaymentResult.error,
      errorCode: 'EXPIRED_CARD',
      errorDetails: 'Card expired on: ${month}/${year}',
    );
  }

  // Validate CVV
  if (cvv.isEmpty || cvv.length < 3 || cvv.length > 4) {
    return PaymentResultData(
      errorString: 'Please enter a valid CVV code.',
      paymentResult: PaymentResult.error,
      errorCode: 'INVALID_CVV',
      errorDetails: 'CVV length: ${cvv.length}',
    );
  }

  if (!RegExp(r'^\d+$').hasMatch(cvv)) {
    return PaymentResultData(
      errorString: 'Please enter a valid CVV code.',
      paymentResult: PaymentResult.error,
      errorCode: 'INVALID_CVV',
      errorDetails: 'CVV contains non-numeric characters',
    );
  }

  // Validate brand
  final validBrands = ['VISA', 'MASTERCARD', 'MADA'];
  if (!validBrands.contains(brand.toUpperCase())) {
    return PaymentResultData(
      errorString: 'Invalid payment method selected.',
      paymentResult: PaymentResult.error,
      errorCode: 'INVALID_BRAND',
      errorDetails: 'Brand: $brand',
    );
  }

  return null; // No validation errors
}

/// Simple Luhn algorithm implementation for card number validation
bool _isValidLuhn(String cardNumber) {
  int sum = 0;
  bool alternate = false;

  for (int i = cardNumber.length - 1; i >= 0; i--) {
    int digit = int.parse(cardNumber[i]);

    if (alternate) {
      digit *= 2;
      if (digit > 9) {
        digit = (digit % 10) + 1;
      }
    }

    sum += digit;
    alternate = !alternate;
  }

  return sum % 10 == 0;
}

/// Enhanced error message based on platform exception
String _getEnhancedErrorMessage(PlatformException e) {
  switch (e.code) {
    case 'INVALID_CARD_NUMBER':
      return 'Please check your card number and try again.';
    case 'INVALID_CARD_HOLDER':
      return 'Please enter a valid cardholder name.';
    case 'INVALID_CVV':
      return 'Please enter a valid CVV code.';
    case 'INVALID_EXPIRY_YEAR':
      return 'Please enter a valid expiry year.';
    case 'INVALID_EXPIRY_MONTH':
      return 'Please enter a valid expiry month.';
    case 'CARD_PARAMS_ERROR':
      return 'Invalid card details. Please check and try again.';
    case 'MISSING_CUSTOM_UI_ARGS':
      return 'Payment configuration error. Please contact support.';
    case 'TRANSACTION_ERROR':
      return 'Transaction failed. Please try again.';
    case 'HYPERPAY_ERROR_100':
      return 'Transaction processing failed. Please try again.';
    case 'HYPERPAY_ERROR_200':
      return 'Network connection failed. Please check your internet connection.';
    case 'HYPERPAY_ERROR_300':
      return 'Invalid payment session. Please try again.';
    case 'MISSING_REDIRECT_URL':
      return '3D Secure authentication failed. Please try again.';
    default:
      return e.message ?? 'Payment failed. Please try again.';
  }
}

/// Determine PaymentResult type from PlatformException
PaymentResult _getPaymentResultFromException(PlatformException e) {
  switch (e.code) {
    case 'PAYMENT_CANCELLED':
      return PaymentResult.canceled;
    case 'HYPERPAY_ERROR_200':
    case 'CONNECTION_FAILED':
      return PaymentResult.networkError;
    case 'TIMEOUT':
      return PaymentResult.timeout;
    default:
      return PaymentResult.error;
  }
}

/// Get custom UI payment arguments with validation
Map<String, dynamic> getCustomUIPaymentArgs({
  required String brand,
  required String checkoutId,
  required String shopperResultUrl,
  required PaymentMode paymentMode,
  required String cardNumber,
  required String holderName,
  required String month,
  required String year,
  required String cvv,
  required String lang,
  required bool enabledTokenization,
}) {
  // Clean card number (remove spaces and special characters)
  String cleanCardNumber = cardNumber.replaceAll(RegExp(r'\D'), '');

  // Ensure month is 2 digits
  String formattedMonth = month.padLeft(2, '0');

  // Ensure year is 4 digits (convert 2-digit to 4-digit if necessary)
  String formattedYear = year;
  if (year.length == 2) {
    int currentCentury = DateTime.now().year ~/ 100;
    int currentYear = DateTime.now().year % 100;
    int yearInt = int.parse(year);

    // If year is less than current year, assume next century
    if (yearInt < currentYear) {
      formattedYear = '${currentCentury + 1}$year';
    } else {
      formattedYear = '$currentCentury$year';
    }
  }

  final Map<String, dynamic> args = {
    "type": PaymentConst.customUi,
    "mode": paymentMode.toString().split('.').last,
    "checkoutid": checkoutId,
    "brand": brand.toUpperCase(),
    "card_number": cleanCardNumber,
    "holder_name": holderName.trim(),
    "month": formattedMonth,
    "year": formattedYear,
    "cvv": cvv,
    "lang": lang,
    "EnabledTokenization": enabledTokenization.toString(),
    "ShopperResultUrl": shopperResultUrl,
  };

  print('HyperPay: Custom UI arguments prepared');
  print('HyperPay: Brand: ${args["brand"]}');
  print('HyperPay: Expiry: ${args["month"]}/${args["year"]}');
  print('HyperPay: Tokenization: ${args["EnabledTokenization"]}');

  return args;
}
