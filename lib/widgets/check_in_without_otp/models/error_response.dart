import 'failure_type.dart';

class ErrorResponse {
  FailureType? failureType;

  ErrorResponse({this.failureType});

  factory ErrorResponse.fromJson(Map<String, dynamic> json) {
    return ErrorResponse(
      failureType: FailureType.fromKey(json['failure_type']),
    );
  }
}
