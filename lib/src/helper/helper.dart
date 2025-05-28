import '../../flutter_hyperpay.dart';

/// Enhanced PaymentResultManager with detailed error handling and logging
/// Backward compatible with existing PaymentResult enum structure
class PaymentResultManger {
  /// Generates a PaymentResultData object based on the paymentResult passed
  /// Now includes comprehensive error handling and logging
  static PaymentResultData getPaymentResult(String paymentResult) {
    // Log the result for debugging
    print('HyperPay Payment Result: $paymentResult');

    if (paymentResult == PaymentConst.success) {
      print('HyperPay: Payment completed successfully');
      return PaymentResultData(
        errorString: null,
        paymentResult: PaymentResult.success,
      );
    } else if (paymentResult == PaymentConst.sync) {
      print('HyperPay: Synchronous payment completed');
      return PaymentResultData(
        errorString: null,
        paymentResult: PaymentResult.sync,
      );
    } else {
      // Handle different types of errors
      String errorType = _categorizeError(paymentResult);
      String userFriendlyMessage = _getUserFriendlyMessage(paymentResult);
      String? errorCode = _extractErrorCode(paymentResult);

      print('HyperPay Error: $paymentResult');
      print('HyperPay Error Type: $errorType');
      print('HyperPay User Message: $userFriendlyMessage');
      if (errorCode != null) print('HyperPay Error Code: $errorCode');

      return PaymentResultData(
        errorString: userFriendlyMessage,
        paymentResult: _getErrorResultType(paymentResult),
        errorCode: errorCode,
        errorDetails: paymentResult,
      );
    }
  }

  /// Extract error code from error message if present
  static String? _extractErrorCode(String error) {
    // Check if error contains structured error information
    if (error.contains('PlatformException(')) {
      final regex = RegExp(r'PlatformException\(([^,]+),');
      final match = regex.firstMatch(error);
      if (match != null) {
        return match.group(1);
      }
    }

    // Check for specific error patterns
    if (error.contains('INVALID_')) {
      return error.split(',').first.trim();
    } else if (error.contains('HYPERPAY_ERROR_')) {
      return error.split(',').first.trim();
    } else if (error.contains('TRANSACTION_ERROR')) {
      return 'TRANSACTION_ERROR';
    } else if (error.contains('PAYMENT_CANCELLED')) {
      return 'PAYMENT_CANCELLED';
    }

    return null;
  }

  /// Categorizes the error type for better debugging
  static String _categorizeError(String error) {
    if (error.contains('INVALID_')) {
      return 'Validation Error';
    } else if (error.contains('NETWORK') || error.contains('CONNECTION')) {
      return 'Network Error';
    } else if (error.contains('HYPERPAY_ERROR')) {
      return 'HyperPay SDK Error';
    } else if (error.contains('TRANSACTION_ERROR')) {
      return 'Transaction Error';
    } else if (error.contains('PAYMENT_CANCELLED')) {
      return 'User Cancellation';
    } else if (error.contains('TIMEOUT')) {
      return 'Timeout Error';
    } else if (error.contains('PlatformException')) {
      return 'Platform Error';
    } else {
      return 'Unknown Error';
    }
  }

  /// Provides user-friendly error messages
  static String _getUserFriendlyMessage(String error) {
    // Convert error to lowercase for easier matching
    String lowerError = error.toLowerCase();

    if (lowerError.contains('invalid') && lowerError.contains('card') && lowerError.contains('number')) {
      return 'Please check your card number and try again.';
    } else if (lowerError.contains('invalid') && lowerError.contains('holder')) {
      return 'Please enter a valid cardholder name.';
    } else if (lowerError.contains('invalid') && lowerError.contains('cvv')) {
      return 'Please enter a valid CVV code.';
    } else if (lowerError.contains('invalid') && lowerError.contains('year')) {
      return 'Please enter a valid expiry year.';
    } else if (lowerError.contains('invalid') && lowerError.contains('month')) {
      return 'Please enter a valid expiry month.';
    } else if (lowerError.contains('invalid') && lowerError.contains('checkout')) {
      return 'Invalid payment session. Please try again.';
    } else if (lowerError.contains('connection') || lowerError.contains('network')) {
      return 'Please check your internet connection and try again.';
    } else if (lowerError.contains('cancel')) {
      return 'Payment was cancelled.';
    } else if (lowerError.contains('insufficient') && lowerError.contains('funds')) {
      return 'Insufficient funds. Please check your account balance.';
    } else if (lowerError.contains('declined')) {
      return 'Your card was declined. Please try a different payment method.';
    } else if (lowerError.contains('expired')) {
      return 'Your card has expired. Please use a different card.';
    } else if (lowerError.contains('3ds') || lowerError.contains('authentication')) {
      return '3D Secure authentication failed. Please try again.';
    } else if (lowerError.contains('timeout')) {
      return 'Payment request timed out. Please try again.';
    } else if (lowerError.contains('applepay') || lowerError.contains('apple pay')) {
      return 'Apple Pay transaction failed. Please try again or use a different payment method.';
    } else if (lowerError.contains('transaction')) {
      return 'Transaction failed. Please try again.';
    } else if (lowerError.contains('operation cancel')) {
      return 'Payment was cancelled.';
    } else {
      return 'Payment failed. Please try again or contact support.';
    }
  }

  /// Determines the appropriate PaymentResult type based on error
  static PaymentResult _getErrorResultType(String error) {
    String lowerError = error.toLowerCase();

    if (lowerError.contains('cancel')) {
      return PaymentResult.canceled;
    } else if (lowerError.contains('network') || lowerError.contains('connection')) {
      return PaymentResult.networkError;
    } else if (lowerError.contains('timeout')) {
      return PaymentResult.timeout;
    } else {
      return PaymentResult.error;
    }
  }

  /// Create enhanced error result with detailed information
  static PaymentResultData createErrorResult({
    required String errorMessage,
    required String errorCode,
    String? errorDetails,
    PaymentResult? resultType,
  }) {
    return PaymentResultData(
      errorString: errorMessage,
      paymentResult: resultType ?? PaymentResult.error,
      errorCode: errorCode,
      errorDetails: errorDetails,
    );
  }
}
