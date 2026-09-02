import 'dart:async';
import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/loan_details.dart';
import 'package:snabbit_runner/services/loan_http.dart';
import 'package:snabbit_runner/utils/retry_helper.dart';

class LoanProvider with ChangeNotifier {
  LoanDetails? _loanDetails;
  bool _isLoading = false;
  String? _error;
  int _retryCount = 0;
  static const int maxRetries = 3;

  LoanDetails? get loanDetails => _loanDetails;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get retryCount => _retryCount;
  bool get hasMaxRetries => _retryCount >= maxRetries;

  Future<void> fetchLoanDetails() async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      await RetryHelper.exponentialBackoff(
        () async {
          final response = await LoanHttp.getLoanDetails();
          if (response != null && response.statusCode == 200) {
            _loanDetails = LoanDetails.fromJson(response.data);
            return;
          } else {
            throw Exception('Failed to load loan details');
          }
        },
        maxRetries: maxRetries,
      );
      _error = null;
    } catch (e) {
      _error = 'Failed to load loan details after $maxRetries attempts';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manual retry method for user-triggered retries
  Future<void> retryFetchLoanDetails() async {
    await fetchLoanDetails();
  }

  /// Reset the provider state
  void reset() {
    if (_isLoading) return; // Prevent reset if fetch is in progress
    _loanDetails = null;
    _isLoading = false;
    _error = null;
    _retryCount = 0;
    notifyListeners();
  }
}
