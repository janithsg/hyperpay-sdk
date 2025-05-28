import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Comprehensive logging utility for HyperPay SDK
class HyperPayLogger {
  static const String _tag = 'HyperPay';
  static bool _enableLogging = kDebugMode;
  static LogLevel _logLevel = LogLevel.debug;

  /// Enable or disable logging
  static void setLoggingEnabled(bool enabled) {
    _enableLogging = enabled;
  }

  /// Set minimum log level
  static void setLogLevel(LogLevel level) {
    _logLevel = level;
  }

  /// Log debug messages
  static void debug(String message, {String? method, Map<String, dynamic>? data}) {
    if (_enableLogging && _logLevel.priority <= LogLevel.debug.priority) {
      final formattedMessage = _formatMessage(message, method: method, data: data);
      developer.log(formattedMessage, name: _tag, level: 300);
      if (kDebugMode) print('🔵 $_tag: $formattedMessage');
    }
  }

  /// Log info messages
  static void info(String message, {String? method, Map<String, dynamic>? data}) {
    if (_enableLogging && _logLevel.priority <= LogLevel.info.priority) {
      final formattedMessage = _formatMessage(message, method: method, data: data);
      developer.log(formattedMessage, name: _tag, level: 400);
      if (kDebugMode) print('🟢 $_tag: $formattedMessage');
    }
  }

  /// Log warning messages
  static void warning(String message, {String? method, Map<String, dynamic>? data}) {
    if (_enableLogging && _logLevel.priority <= LogLevel.warning.priority) {
      final formattedMessage = _formatMessage(message, method: method, data: data);
      developer.log(formattedMessage, name: _tag, level: 500);
      if (kDebugMode) print('🟡 $_tag: $formattedMessage');
    }
  }

  /// Log error messages
  static void error(String message, {String? method, Map<String, dynamic>? data, Object? error, StackTrace? stackTrace}) {
    if (_enableLogging && _logLevel.priority <= LogLevel.error.priority) {
      final formattedMessage = _formatMessage(message, method: method, data: data);
      developer.log(
        formattedMessage,
        name: _tag,
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
      if (kDebugMode) {
        print('🔴 $_tag: $formattedMessage');
        if (error != null) print('🔴 $_tag Error: $error');
        if (stackTrace != null) print('🔴 $_tag Stack: $stackTrace');
      }
    }
  }

  /// Log payment initiation
  static void logPaymentStart({
    required String paymentType,
    required String checkoutId,
    required String paymentMode,
    List<String>? brands,
    Map<String, dynamic>? additionalData,
  }) {
    info(
      'Payment initiated',
      method: 'PaymentStart',
      data: {
        'paymentType': paymentType,
        'checkoutId': checkoutId,
        'paymentMode': paymentMode,
        'brands': brands,
        ...?additionalData,
      },
    );
  }

  /// Log payment result
  static void logPaymentResult({
    required String result,
    String? errorCode,
    String? errorMessage,
    String? errorDetails,
    Duration? duration,
  }) {
    final isSuccess = result == 'success' || result == 'SYNC';
    final logMethod = isSuccess ? info : error;

    logMethod(
      'Payment ${isSuccess ? 'completed' : 'failed'}',
      method: 'PaymentResult',
      data: {
        'result': result,
        'success': isSuccess,
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'errorDetails': errorDetails,
        'duration': duration?.inMilliseconds,
      },
    );
  }

  /// Log validation errors
  static void logValidationError({
    required String field,
    required String error,
    String? value,
  }) {
    warning(
      'Validation failed',
      method: 'Validation',
      data: {
        'field': field,
        'error': error,
        'value': field.toLowerCase().contains('card') ? _maskCardData(value) : value,
      },
    );
  }

  /// Log network errors
  static void logNetworkError({
    required String operation,
    required String error,
    int? statusCode,
    Map<String, dynamic>? headers,
  }) {
    HyperPayLogger.error(
      'Network error during $operation',
      method: 'Network',
      data: {
        'operation': operation,
        'error': error,
        'statusCode': statusCode,
        'headers': headers,
      },
    );
  }

  /// Log 3DS authentication
  static void log3DSAuth({
    required String status,
    String? redirectUrl,
    String? error,
  }) {
    final logMethod = status == 'success' ? info : HyperPayLogger.error;
    logMethod(
      '3DS Authentication $status',
      method: '3DSAuth',
      data: {
        'status': status,
        'hasRedirectUrl': redirectUrl != null,
        'error': error,
      },
    );
  }

  /// Log Apple Pay events
  static void logApplePay({
    required String event,
    String? merchantId,
    String? countryCode,
    String? error,
  }) {
    final logMethod = error != null ? HyperPayLogger.error : info;
    logMethod(
      'Apple Pay: $event',
      method: 'ApplePay',
      data: {
        'event': event,
        'merchantId': merchantId,
        'countryCode': countryCode,
        'error': error,
      },
    );
  }

  /// Log configuration issues
  static void logConfigError({
    required String component,
    required String issue,
    String? suggestion,
  }) {
    error(
      'Configuration error in $component',
      method: 'Configuration',
      data: {
        'component': component,
        'issue': issue,
        'suggestion': suggestion,
      },
    );
  }

  /// Log SDK initialization
  static void logSDKInit({
    required String mode,
    required String version,
    List<String>? supportedBrands,
  }) {
    info(
      'HyperPay SDK initialized',
      method: 'SDKInit',
      data: {
        'mode': mode,
        'version': version,
        'supportedBrands': supportedBrands,
      },
    );
  }

  /// Format log message with method and data
  static String _formatMessage(
    String message, {
    String? method,
    Map<String, dynamic>? data,
  }) {
    final buffer = StringBuffer();

    if (method != null) {
      buffer.write('[$method] ');
    }

    buffer.write(message);

    if (data != null && data.isNotEmpty) {
      buffer.write(' | Data: ${_formatData(data)}');
    }

    return buffer.toString();
  }

  /// Format data for logging (with sensitive data masking)
  static String _formatData(Map<String, dynamic> data) {
    final maskedData = <String, dynamic>{};

    data.forEach((key, value) {
      if (key.toLowerCase().contains('card') || key.toLowerCase().contains('cvv') || key.toLowerCase().contains('number')) {
        maskedData[key] = _maskCardData(value?.toString());
      } else if (key.toLowerCase().contains('token') || key.toLowerCase().contains('id') || key.toLowerCase().contains('secret')) {
        maskedData[key] = _maskSensitiveData(value?.toString());
      } else {
        maskedData[key] = value;
      }
    });

    return maskedData.toString();
  }

  /// Mask card data for logging
  static String? _maskCardData(String? data) {
    if (data == null || data.isEmpty) return data;

    if (data.length > 6) {
      return '${data.substring(0, 4)}${'*' * (data.length - 6)}${data.substring(data.length - 2)}';
    } else if (data.length > 4) {
      return '${data.substring(0, 2)}${'*' * (data.length - 2)}';
    } else {
      return '*' * data.length;
    }
  }

  /// Mask sensitive data for logging
  static String? _maskSensitiveData(String? data) {
    if (data == null || data.isEmpty) return data;

    if (data.length > 8) {
      return '${data.substring(0, 4)}***${data.substring(data.length - 2)}';
    } else if (data.length > 4) {
      return '${data.substring(0, 2)}***';
    } else {
      return '***';
    }
  }

  /// Public method to mask sensitive data for external use
  static String maskSensitiveData(String data) {
    return _maskSensitiveData(data) ?? '***';
  }

  /// Create a summary report of all logged events
  static Map<String, dynamic> getLogSummary() {
    return {
      'loggingEnabled': _enableLogging,
      'logLevel': _logLevel.toString(),
      'timestamp': DateTime.now().toIso8601String(),
      'sdkVersion': 'flutter_hyperpay_enhanced',
    };
  }
}

/// Log levels for filtering
enum LogLevel {
  debug(0),
  info(1),
  warning(2),
  error(3);

  const LogLevel(this.priority);
  final int priority;
}

/// Extension methods for easier logging in payment flows
extension HyperPayLoggerExtension on Object {
  void logPaymentStep(String step, {Map<String, dynamic>? data}) {
    HyperPayLogger.debug(
      'Payment step: $step',
      method: runtimeType.toString(),
      data: data,
    );
  }

  void logError(String message, {Object? error, StackTrace? stackTrace}) {
    HyperPayLogger.error(
      message,
      method: runtimeType.toString(),
      error: error,
      stackTrace: stackTrace,
    );
  }
}
