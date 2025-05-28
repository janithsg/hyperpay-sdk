import 'dart:async';
import 'dart:io';
import 'package:hyperpay_plugin/src/helper/hyperpay_logger.dart';

import 'model/custom_ui.dart';
import 'model/custom_ui_stc.dart';
import 'model/ready_ui.dart';
import 'model/stored_cards.dart';
import 'src/custom_ui/method_channel_custom_ui.dart';
import 'src/custom_ui/method_channel_custom_ui_stc.dart';
import 'src/ready_ui/method_channel_ready_ui.dart';
import 'src/store_cards/method_channel_store_cards.dart';

part 'hyper_pay_const.dart';
part 'enum.dart';

class FlutterHyperPay {
  String channelName = "Hyperpay.demo.fultter/channel";
  String shopperResultUrl = "";
  String lang;
  PaymentMode paymentMode;

  FlutterHyperPay({
    required this.shopperResultUrl,
    required this.paymentMode,
    required this.lang,
  }) {
    _initialize();
  }

  /// Initialize the SDK with logging
  void _initialize() {
    HyperPayLogger.logSDKInit(
      mode: paymentMode.toString().split('.').last,
      version: '1.0.0-enhanced',
      supportedBrands: [
        PaymentBrands.visa,
        PaymentBrands.masterCard,
        PaymentBrands.mada,
        PaymentBrands.applePay,
        PaymentBrands.stcPay,
      ],
    );

    // Validate configuration
    _validateConfiguration();
  }

  /// Validate SDK configuration
  void _validateConfiguration() {
    if (shopperResultUrl.isEmpty) {
      HyperPayLogger.logConfigError(
        component: 'FlutterHyperPay',
        issue: 'Shopper result URL is empty',
        suggestion: 'Set a valid shopper result URL in the constructor',
      );
    }

    if (lang.isEmpty) {
      HyperPayLogger.logConfigError(
        component: 'FlutterHyperPay',
        issue: 'Language is empty',
        suggestion: 'Set a valid language code (e.g., "en", "ar")',
      );
    }

    // Platform-specific validations
    if (Platform.isIOS) {
      _validateIOSConfiguration();
    } else if (Platform.isAndroid) {
      _validateAndroidConfiguration();
    }
  }

  /// Validate iOS-specific configuration
  void _validateIOSConfiguration() {
    if (!shopperResultUrl.contains('://')) {
      HyperPayLogger.logConfigError(
        component: 'iOS Configuration',
        issue: 'Shopper result URL should be a valid URL scheme for iOS',
        suggestion: 'Use format like "com.yourapp.payments" for iOS',
      );
    }
  }

  /// Validate Android-specific configuration
  void _validateAndroidConfiguration() {
    // Add Android-specific validations here
    HyperPayLogger.debug('Android configuration validated');
  }

  /// Enhanced ReadyUI payment with comprehensive error handling and logging
  Future<PaymentResultData> readyUICards({required ReadyUI readyUI}) async {
    final stopwatch = Stopwatch()..start();

    HyperPayLogger.logPaymentStart(
      paymentType: 'ReadyUI',
      checkoutId: readyUI.checkoutId,
      paymentMode: paymentMode.toString().split('.').last,
      brands: readyUI.brandsName,
      additionalData: {
        'merchantId': readyUI.merchantIdApplePayIOS,
        'countryCode': readyUI.countryCodeApplePayIOS,
        'companyName': readyUI.companyNameApplePayIOS,
        'hasApplePay': readyUI.brandsName.any((b) => b.toUpperCase() == 'APPLEPAY'),
        'storePaymentDetails': readyUI.setStorePaymentDetailsMode,
      },
    );

    try {
      // Validate ReadyUI configuration
      _validateReadyUIConfig(readyUI);

      final result = await implementPayment(
        brands: readyUI.brandsName,
        checkoutId: readyUI.checkoutId,
        shopperResultUrl: shopperResultUrl,
        channelName: channelName,
        paymentMode: paymentMode,
        merchantId: readyUI.merchantIdApplePayIOS,
        countryCode: readyUI.countryCodeApplePayIOS,
        companyName: readyUI.companyNameApplePayIOS,
        lang: lang,
        themColorHexIOS: readyUI.themColorHexIOS,
        setStorePaymentDetailsMode: readyUI.setStorePaymentDetailsMode,
      );

      stopwatch.stop();

      HyperPayLogger.logPaymentResult(
        result: result.paymentResult.toString(),
        errorCode: result.errorCode,
        errorMessage: result.errorString,
        errorDetails: result.errorDetails,
        duration: stopwatch.elapsed,
      );

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();

      HyperPayLogger.error(
        'ReadyUI payment failed with exception',
        method: 'readyUICards',
        error: e,
        stackTrace: stackTrace,
      );

      return PaymentResultData(
        errorString: 'An unexpected error occurred during payment initialization.',
        paymentResult: PaymentResult.error,
        errorCode: 'READYUI_EXCEPTION',
        errorDetails: e.toString(),
      );
    }
  }

  /// Enhanced CustomUI payment with comprehensive error handling and logging
  Future<PaymentResultData> customUICards({required CustomUI customUI}) async {
    final stopwatch = Stopwatch()..start();

    HyperPayLogger.logPaymentStart(
      paymentType: 'CustomUI',
      checkoutId: customUI.checkoutId,
      paymentMode: paymentMode.toString().split('.').last,
      brands: [customUI.brandName],
      additionalData: {
        'tokenization': customUI.enabledTokenization,
        'cardType': _detectCardType(customUI.cardNumber),
      },
    );

    try {
      // Validate CustomUI configuration
      _validateCustomUIConfig(customUI);

      final result = await implementPaymentCustomUI(
        brand: customUI.brandName,
        checkoutId: customUI.checkoutId,
        shopperResultUrl: shopperResultUrl,
        channelName: channelName,
        paymentMode: paymentMode,
        cardNumber: customUI.cardNumber,
        holderName: customUI.holderName,
        month: customUI.month,
        year: customUI.year,
        cvv: customUI.cvv,
        lang: lang,
        enabledTokenization: customUI.enabledTokenization,
      );

      stopwatch.stop();

      HyperPayLogger.logPaymentResult(
        result: result.paymentResult.toString(),
        errorCode: result.errorCode,
        errorMessage: result.errorString,
        errorDetails: result.errorDetails,
        duration: stopwatch.elapsed,
      );

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();

      HyperPayLogger.error(
        'CustomUI payment failed with exception',
        method: 'customUICards',
        error: e,
        stackTrace: stackTrace,
      );

      return PaymentResultData(
        errorString: 'An unexpected error occurred during payment processing.',
        paymentResult: PaymentResult.error,
        errorCode: 'CUSTOMUI_EXCEPTION',
        errorDetails: e.toString(),
      );
    }
  }

  /// Enhanced STC Pay implementation
  Future<PaymentResultData> customUISTC({required CustomUISTC customUISTC}) async {
    final stopwatch = Stopwatch()..start();

    HyperPayLogger.logPaymentStart(
      paymentType: 'STC Pay',
      checkoutId: customUISTC.checkoutId,
      paymentMode: paymentMode.toString().split('.').last,
      brands: ['STC_PAY'],
      additionalData: {
        'phoneNumber': HyperPayLogger.maskSensitiveData(customUISTC.phoneNumber),
      },
    );

    try {
      _validateSTCConfig(customUISTC);

      final result = await implementPaymentCustomUISTC(
        checkoutId: customUISTC.checkoutId,
        shopperResultUrl: shopperResultUrl,
        channelName: channelName,
        paymentMode: paymentMode,
        lang: lang,
        phoneNumber: customUISTC.phoneNumber,
      );

      stopwatch.stop();

      HyperPayLogger.logPaymentResult(
        result: result.paymentResult.toString(),
        errorCode: result.errorCode,
        errorMessage: result.errorString,
        errorDetails: result.errorDetails,
        duration: stopwatch.elapsed,
      );

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();

      HyperPayLogger.error(
        'STC Pay payment failed with exception',
        method: 'customUISTC',
        error: e,
        stackTrace: stackTrace,
      );

      return PaymentResultData(
        errorString: 'An unexpected error occurred during STC Pay processing.',
        paymentResult: PaymentResult.error,
        errorCode: 'STC_EXCEPTION',
        errorDetails: e.toString(),
      );
    }
  }

  /// Enhanced stored cards payment
  Future<PaymentResultData> payWithStoredCards({required StoredCards storedCards}) async {
    final stopwatch = Stopwatch()..start();

    HyperPayLogger.logPaymentStart(
      paymentType: 'StoredCards',
      checkoutId: storedCards.checkoutId,
      paymentMode: paymentMode.toString().split('.').last,
      brands: [storedCards.brandName ?? 'UNKNOWN'], // Handle nullable brandName
      additionalData: {
        'tokenId': HyperPayLogger.maskSensitiveData(storedCards.tokenId),
        'hasCVV': storedCards.cvv.isNotEmpty,
      },
    );

    try {
      _validateStoredCardsConfig(storedCards);

      final result = await implementPaymentStoredCards(
        brand: storedCards.brandName,
        checkoutId: storedCards.checkoutId,
        tokenId: storedCards.tokenId,
        cvv: storedCards.cvv,
        shopperResultUrl: shopperResultUrl,
        channelName: channelName,
        paymentMode: paymentMode,
        lang: lang,
      );

      stopwatch.stop();

      HyperPayLogger.logPaymentResult(
        result: result.paymentResult.toString(),
        errorCode: result.errorCode,
        errorMessage: result.errorString,
        errorDetails: result.errorDetails,
        duration: stopwatch.elapsed,
      );

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();

      HyperPayLogger.error(
        'Stored cards payment failed with exception',
        method: 'payWithStoredCards',
        error: e,
        stackTrace: stackTrace,
      );

      return PaymentResultData(
        errorString: 'An unexpected error occurred during stored card payment.',
        paymentResult: PaymentResult.error,
        errorCode: 'STORED_CARDS_EXCEPTION',
        errorDetails: e.toString(),
      );
    }
  }

  /// Validate ReadyUI configuration
  void _validateReadyUIConfig(ReadyUI readyUI) {
    if (readyUI.checkoutId.isEmpty) {
      throw ArgumentError('Checkout ID cannot be empty for ReadyUI');
    }

    if (readyUI.brandsName.isEmpty) {
      throw ArgumentError('At least one payment brand must be specified for ReadyUI');
    }

    // Validate Apple Pay configuration if Apple Pay is included
    if (readyUI.brandsName.any((brand) => brand.toUpperCase() == 'APPLEPAY')) {
      if (Platform.isIOS) {
        if (readyUI.merchantIdApplePayIOS.isEmpty) {
          HyperPayLogger.logConfigError(
            component: 'Apple Pay',
            issue: 'Merchant ID is required for Apple Pay on iOS',
            suggestion: 'Set merchantIdApplePayIOS in ReadyUI configuration',
          );
        }

        if (readyUI.countryCodeApplePayIOS.isEmpty) {
          HyperPayLogger.logConfigError(
            component: 'Apple Pay',
            issue: 'Country code is required for Apple Pay on iOS',
            suggestion: 'Set countryCodeApplePayIOS in ReadyUI configuration',
          );
        }
      }
    }
  }

  /// Validate CustomUI configuration
  void _validateCustomUIConfig(CustomUI customUI) {
    if (customUI.checkoutId.isEmpty) {
      throw ArgumentError('Checkout ID cannot be empty for CustomUI');
    }

    if (customUI.brandName.isEmpty) {
      throw ArgumentError('Brand name cannot be empty for CustomUI');
    }

    // Additional validations are handled in the method channel implementation
  }

  /// Validate STC configuration
  void _validateSTCConfig(CustomUISTC customUISTC) {
    if (customUISTC.checkoutId.isEmpty) {
      throw ArgumentError('Checkout ID cannot be empty for STC Pay');
    }

    if (customUISTC.phoneNumber.isEmpty) {
      throw ArgumentError('Phone number cannot be empty for STC Pay');
    }

    // Validate phone number format (basic validation)
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(customUISTC.phoneNumber.replaceAll(RegExp(r'\s'), ''))) {
      HyperPayLogger.logValidationError(
        field: 'phoneNumber',
        error: 'Invalid phone number format for STC Pay',
        value: customUISTC.phoneNumber,
      );
    }
  }

  /// Validate stored cards configuration
  void _validateStoredCardsConfig(StoredCards storedCards) {
    if (storedCards.checkoutId.isEmpty) {
      throw ArgumentError('Checkout ID cannot be empty for stored cards');
    }

    if (storedCards.tokenId.isEmpty) {
      throw ArgumentError('Token ID cannot be empty for stored cards');
    }

    if (storedCards.brandName == null || storedCards.brandName!.isEmpty) {
      throw ArgumentError('Brand name cannot be empty for stored cards');
    }
  }

  /// Detect card type from card number for logging purposes
  String _detectCardType(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(RegExp(r'\D'), '');

    if (cleanNumber.startsWith('4')) {
      return 'VISA';
    } else if (cleanNumber.startsWith(RegExp(r'^5[1-5]'))) {
      return 'MASTERCARD';
    } else if (cleanNumber.startsWith(RegExp(r'^(9665|5|4|6)'))) {
      return 'MADA';
    } else {
      return 'UNKNOWN';
    }
  }

  /// Get SDK status and configuration
  Map<String, dynamic> getSDKStatus() {
    return {
      'isInitialized': true,
      'shopperResultUrl': shopperResultUrl,
      'paymentMode': paymentMode.toString().split('.').last,
      'language': lang,
      'platform': Platform.operatingSystem,
      'logSummary': HyperPayLogger.getLogSummary(),
    };
  }

  /// Enable or disable detailed logging
  void setLoggingEnabled(bool enabled) {
    HyperPayLogger.setLoggingEnabled(enabled);
    HyperPayLogger.info('Logging ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Set minimum log level
  void setLogLevel(LogLevel level) {
    HyperPayLogger.setLogLevel(level);
    HyperPayLogger.info('Log level set to: ${level.toString()}');
  }
}
