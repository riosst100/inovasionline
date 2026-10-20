import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  /// First validation message of any field, falling back to [message].
  String get displayMessage {
    for (final value in errors?.values ?? const []) {
      if (value is List && value.isNotEmpty) return value.first.toString();
    }
    return message;
  }

  @override
  String toString() => message;
}

/// User-facing message for anything thrown by a service call.
String errorMessage(Object error) {
  if (error is DioException && error.error is ApiException) return (error.error as ApiException).displayMessage;
  if (error is ApiException) return error.displayMessage;
  return 'Terjadi kesalahan. Coba lagi.';
}
