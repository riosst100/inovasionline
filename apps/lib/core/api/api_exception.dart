class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  String? firstErrorFor(String field) {
    final fieldErrors = errors?[field];
    if (fieldErrors is List && fieldErrors.isNotEmpty) {
      return fieldErrors.first.toString();
    }
    return null;
  }

  @override
  String toString() => message;
}
