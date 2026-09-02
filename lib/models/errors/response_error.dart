import 'package:snabbit_runner/models/errors/custom_error.dart';

class ResponseError {
  List<CustomError>? errors;

  ResponseError({
    this.errors,
  });

  CustomError? getFirstError() {
    try {
      return errors?.first;
    } catch (e) {
      return null;
    }
  }

  factory ResponseError.fromMap(Map<String, dynamic> map) {
    return ResponseError(
      errors: map['errors']
          ?.map<CustomError>((e) => CustomError.fromMap(e))
          .toList(),
    );
  }
}
