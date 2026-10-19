enum FailureKind { network, timeout, http, invalidData, storage }

class AppFailure implements Exception {
  final String message;
  final FailureKind kind;
  final int? statusCode;
  const AppFailure(this.message, {required this.kind, this.statusCode});
  @override
  String toString() => message;
}
