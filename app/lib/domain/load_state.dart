import 'app_failure.dart';

enum LoadStatus { loading, success, empty, error }

class LoadState<T> {
  final LoadStatus status;
  final T? data;
  final AppFailure? failure;
  const LoadState(this.status, {this.data, this.failure});
}
