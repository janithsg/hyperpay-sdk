import 'package:flutter/services.dart';
import '../../flutter_hyperpay.dart';
import '../helper/helper.dart';

/// Enhanced implementation of payment with detailed error handling and logging
Future<PaymentResultData> implementPayment({
  required List<String> brands,
  required String checkoutId,
  required String channelName,
  required String shopperResultUrl,
  required String lang,
  required PaymentMode paymentMode,
  required String merchantId,
  required String countryCode,
  String? companyName = "",
  String? themColorHexIOS,
  required bool setStorePaymentDetailsMode,
}) async {
  // Enhanced logging
  print('HyperPay: Starting payment with ReadyUI');
  print('HyperPay: CheckoutId: $checkoutId');
  print('HyperPay: Brands: $brands');
  print('HyperPay: PaymentMode: $paymentMode');
  print('HyperPay: Language: $lang');

  String transactionStatus;
  var platform = MethodChannel(channelName);

  try {
    // Validate input parameters
    if (checkoutId.isEmpty) {
      throw PlatformException(
        code: 'INVALID_CHECKOUT_ID',
        message: 'Checkout ID cannot be empty',
        details: 'Please ensure checkout ID is properly generated from your server',
      );
    }

    if (brands.isEmpty) {
      throw PlatformException(
        code: 'INVALID_BRANDS',
        message: 'Payment brands cannot be empty',
        details: 'Please specify at least one payment brand',
      );
    }

    if (shopperResultUrl.isEmpty) {
      throw PlatformException(
        code: 'INVALID_SHOPPER_URL',
        message: 'Shopper result URL cannot be empty',
        details: 'Please provide a valid shopper result URL',
      );
    }

    final Map<String, dynamic> paymentArgs = getReadyModelCards(
      brands: brands,
      checkoutId: checkoutId,
      themColorHexIOS: themColorHexIOS,
      shopperResultUrl: shopperResultUrl,
      paymentMode: paymentMode,
      countryCode: countryCode,
      merchantId: merchantId,
      companyName: companyName,
      lang: lang,
      setStorePaymentDetailsMode: setStorePaymentDetailsMode,
    );

    print('HyperPay: Sending payment arguments: ${paymentArgs.toString()}');

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

/// Enhanced error message based on platform exception
String _getEnhancedErrorMessage(PlatformException e) {
  switch (e.code) {
    case 'INVALID_ARGUMENTS':
    case 'MISSING_REQUIRED_ARGS':
    case 'MISSING_READY_UI_ARGS':
      return 'Payment configuration error. Please contact support.';
    case 'CHECKOUT_PROVIDER_INIT_ERROR':
      return 'Failed to initialize payment. Please try again.';
    case 'PAYMENT_CANCELLED':
      return 'Payment was cancelled.';
    case 'INVALID_CHECKOUT_ID':
      return 'Invalid payment session. Please try again.';
    case 'HYPERPAY_ERROR_100':
      return 'Transaction processing failed. Please try again.';
    case 'HYPERPAY_ERROR_200':
      return 'Network connection failed. Please check your internet connection.';
    case 'HYPERPAY_ERROR_300':
      return 'Invalid payment session. Please try again.';
    case 'HYPERPAY_ERROR_400':
      return 'Invalid payment method. Please try a different payment method.';
    case 'TRANSACTION_ERROR':
      return 'Transaction failed. Please try again.';
    case 'METHOD_NOT_FOUND':
      return 'Payment service unavailable. Please contact support.';
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

/// Enhanced getReadyModelCards with validation
Map<String, dynamic> getReadyModelCards({
  required List<String> brands,
  required String checkoutId,
  required String shopperResultUrl,
  required String lang,
  required PaymentMode paymentMode,
  required String merchantId,
  required String countryCode,
  String? companyName = "",
  String? themColorHexIOS,
  required bool setStorePaymentDetailsMode,
}) {
  // Validate brands
  final validBrands = ['VISA', 'MASTERCARD', 'MADA', 'APPLEPAY', 'STC_PAY'];
  final invalidBrands = brands.where((brand) => !validBrands.contains(brand.toUpperCase())).toList();

  if (invalidBrands.isNotEmpty) {
    print('HyperPay Warning: Invalid brands detected: $invalidBrands');
  }

  // Log Apple Pay configuration if present
  if (brands.any((brand) => brand.toUpperCase() == 'APPLEPAY')) {
    print('HyperPay: Apple Pay detected');
    print('HyperPay: Merchant ID: $merchantId');
    print('HyperPay: Country Code: $countryCode');
    print('HyperPay: Company Name: ${companyName ?? "Not provided"}');

    if (merchantId.isEmpty) {
      print('HyperPay Warning: Apple Pay merchant ID is empty');
    }

    if (countryCode.isEmpty) {
      print('HyperPay Warning: Apple Pay country code is empty');
    }
  }

  final Map<String, dynamic> args = {
    "type": PaymentConst.readyUi,
    "mode": paymentMode.toString().split('.').last,
    "checkoutid": checkoutId,
    "brand": brands,
    "lang": lang,
    "merchantId": merchantId,
    "CountryCode": countryCode,
    "companyName": companyName ?? "",
    "themColorHexIOS": themColorHexIOS ?? "",
    "ShopperResultUrl": shopperResultUrl,
    "setStorePaymentDetailsMode": setStorePaymentDetailsMode.toString(),
  };

  print('HyperPay: Payment arguments prepared: ${args.keys.join(', ')}');

  return args;
}
