import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/errors/response_error.dart';

class ErrorHandler {
  static void handleResponseError({
    required Response? response,
    required BuildContext context,
    required Function(
      BuildContext context,
      ResponseError responseError,
    ) onError,
  }) {
    try {
      final data = response?.data as Map<String, dynamic>;
      if (data.containsKey("errors")) {
        final error = ResponseError.fromMap(data);
        onError(context,error);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Exception occurred when parsing error $e");
      }
    }
  }
}
