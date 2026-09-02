import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/early_payouts_model.dart';
import 'package:snabbit_runner/services/clevertap.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';
import '../services/early_payouts_http.dart';
import '../services/monitoring/uuid_generator.dart';
import '../models/errors/response_error.dart';

class WithdrawalResult {
  final bool success;
  final String? transactionId;
  final String? error;

  WithdrawalResult({
    required this.success,
    this.transactionId,
    this.error,
  });
}

class EarlyPayoutsProvider with ChangeNotifier {
  bool _loading = false;
  String? _error;
  String? _payoutDataError;
  EarlyPayoutsData? _earlyPayoutsData;

  bool get loading => _loading;
  String? get error => _error;
  String? get payoutDataError => _payoutDataError;
  EarlyPayoutsData? get earlyPayoutsData => _earlyPayoutsData;

  bool get isEligible => _earlyPayoutsData?.eligible ?? false;
  IneligibilityReason? get ineligibilityReason =>
      _earlyPayoutsData?.ineligibilityReason;

  set loading(bool value) {
    _loading = value;
    notifyListeners();
  }

  Future<void> fetchEarlyPayoutsData() async {
    _loading = true;
    _payoutDataError = null;
    notifyListeners();

    try {
      final response = await EarlyPayoutsHttp.getEarlyPayoutsData();
      if (response != null && response.statusCode == 200) {
        _earlyPayoutsData = EarlyPayoutsData.fromJson(response.data);
        _payoutDataError = null;
      } else {
        _payoutDataError = 'Failed to fetch early payouts data';
        _earlyPayoutsData = null;
      }
    } catch (e) {
      _payoutDataError = e.toString();
      _earlyPayoutsData = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<WithdrawalResult> requestManualWithdraw({
    required double requestedAmount,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final idempotencyKey = UuidGenerator().generateUuid('WITHDRAW');
      final response = await EarlyPayoutsHttp.requestManualWithdraw(
        requestedAmount: requestedAmount,
        idempotencyKey: idempotencyKey,
      );

      if (response != null && response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && data.containsKey('errors')) {
          final responseError = ResponseError.fromMap(data);
          final error = responseError.getFirstError();

          _error = error?.message ?? 'An error occurred during withdrawal';
          _loading = false;
          notifyListeners();

          return WithdrawalResult(
            success: false,
            error: error?.message ?? 'An error occurred during withdrawal',
          );
        }

        final transactionId = response.data?['transaction_id'] ?? '';

        // Refresh the early payouts data after successful withdrawal
        await fetchEarlyPayoutsData();

        return WithdrawalResult(
          success: true,
          transactionId: transactionId.toString(),
        );
      } else {
        _error = 'Failed to request withdrawal';
        _loading = false;
        notifyListeners();

        return WithdrawalResult(
          success: false,
          error: 'Failed to request withdrawal',
        );
      }
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();

      return WithdrawalResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    _loading = false;
    _error = null;
    _payoutDataError = null;
    _earlyPayoutsData = null;
    notifyListeners();
  }
}
