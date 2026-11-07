class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;
  final int? retryAfter;

  ApiException(this.message, {this.statusCode, this.data, this.retryAfter});

  @override
  String toString() => message;
}
