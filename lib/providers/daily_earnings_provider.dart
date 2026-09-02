import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/daily_earnings_models.dart';
import '../services/daily_earnings_http.dart';
import '../utils/common_methods.dart';
import '../utils/constants.dart';

class DailyEarningsProvider with ChangeNotifier {
  bool _loading = false;
  String? _error;
  DailyEarningsResponse? _dailyEarningsData;

  bool get loading => _loading;
  String? get error => _error;
  DailyEarningsResponse? get dailyEarningsData => _dailyEarningsData;

  set loading(bool val) {
    _loading = val;
    // notifyListeners();
  }

  Future<void> fetchDailyEarnings(DateTime date) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Single API call to get all daily earnings data
      final response = await DailyEarningsHttp.getDailyEarnings(
          queryParameters: {'date': dateFormat.format(date)});

      if (response == null || response.data == null) {
        _error = 'Failed to fetch data';
        _loading = false;
        notifyListeners();
        return;
      }

      // Use the fromJson method to create the DailyEarningsResponse object
      _dailyEarningsData = DailyEarningsResponse.fromJson(response.data);

      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      _dailyEarningsData = null;
      notifyListeners();
    }
  }

  Map<String, dynamic> _transformServerResponse(Map<String, dynamic> data) {
    // Create a transformed data structure that matches what our models expect
    final Map<String, dynamic> transformedData = {};

    // Transform base_pay data
    transformedData['base_pay_data'] = _transformBasePayData(data);

    // Transform daily_earnings data
    transformedData['daily_earning_data'] = _transformDailyEarningData(data);

    // Transform job entries
    transformedData['job_entries'] = _transformJobEntries(data);

    return transformedData;
  }

  Map<String, dynamic> _transformBasePayData(Map<String, dynamic> data) {
    final basePayList = data['base_pay'] as List<dynamic>?;
    if (basePayList == null || basePayList.isEmpty) {
      return {
        'hours_worked': null,
        'rate_per_hour': null,
        'total': null,
        'ming_applicable': false,
      };
    }

    int? minsWorked;
    int? ratePerHour;
    int? totalBasePay;

    // Extract values from the key-value pairs
    for (var item in basePayList) {
      if (item['key'] == 'mins_worked') {
        minsWorked =
            item['value'] != null ? anyValueToInt(item['value']) : null;
      } else if (item['key'] == 'rate_per_hour') {
        ratePerHour =
            item['value'] != null ? anyValueToInt(item['value']) : null;
      } else if (item['key'] == 'total_base_pay') {
        totalBasePay =
            item['value'] != null ? anyValueToInt(item['value']) : null;
      }
    }

    // Check if MING is applicable
    bool mingApplicable = data.containsKey('ming_details') &&
        data['ming_details'] != null &&
        data['ming_details'].isNotEmpty;

    return {
      'hours_worked': minsWorked,
      'rate_per_hour': ratePerHour,
      'total': totalBasePay,
      'ming_applicable': mingApplicable,
    };
  }

  Map<String, dynamic> _transformDailyEarningData(Map<String, dynamic> data) {
    final dailyEarningsList = data['daily_earnings'] as List<dynamic>?;
    if (dailyEarningsList == null || dailyEarningsList.isEmpty) {
      return {
        'earning_items': [],
        'total': null,
        'cash_collected': null,
        'amount_due': null,
      };
    }

    List<Map<String, dynamic>> earningItems = [];
    int? total;
    int? cashCollected;
    int? amountDue;

    // Process daily earnings data
    for (var item in dailyEarningsList) {
      if (item['key'] == 'line_items' && item['value'] is List) {
        // Extract earning items from line_items
        _processLineItems(item['value'], earningItems);
      } else if (item['key'] == 'total_amount') {
        total = item['value'] != null ? anyValueToInt(item['value']) : null;
      } else if (item['key'] == 'cash_collected') {
        cashCollected =
            item['value'] != null ? anyValueToInt(item['value']) : null;
      } else if (item['key'] == 'amount_due') {
        amountDue = item['value'] != null ? anyValueToInt(item['value']) : null;
      }
    }

    return {
      'earning_items': earningItems,
      'total': total,
      'cash_collected': cashCollected,
      'amount_due': amountDue,
    };
  }

  void _processLineItems(
      List<dynamic> lineItems, List<Map<String, dynamic>> earningItems) {
    for (var lineItem in lineItems) {
      if (lineItem is Map<String, dynamic>) {
        // Handle single key-value objects (e.g., ming_pay)
        String key = lineItem.keys.first;
        var value = lineItem[key];

        if (value is Map && value.containsKey('amount')) {
          // For structured values like overtime with 'amount' field
          earningItems.add({
            'key': key,
            'amount':
                value['amount'] != null ? anyValueToInt(value['amount']) : null,
          });
        } else {
          // For simple values
          earningItems.add({
            'key': key,
            'amount': value != null ? anyValueToInt(value) : null,
          });
        }
      } else if (lineItem is List) {
        // Handle arrays of incentives
        for (var incentive in lineItem) {
          if (incentive is Map<String, dynamic>) {
            String key = incentive.keys.first;
            earningItems.add({
              'key': key,
              'amount':
                  incentive[key] != null ? anyValueToInt(incentive[key]) : null,
            });
          }
        }
      }
    }
  }

  List<Map<String, dynamic>> _transformJobEntries(Map<String, dynamic> data) {
    final jobDetailsList = data['daily_payout_job_details'] as List<dynamic>?;
    if (jobDetailsList == null || jobDetailsList.isEmpty) {
      return [];
    }

    List<Map<String, dynamic>> transformedJobEntries = [];

    for (var job in jobDetailsList) {
      // Process incentives
      Map<String, dynamic> incentivesBreakdown =
          job['incentives_breakdown'] ?? {};
      String? timePe;
      String? longDistance;
      bool? hasLateTimePe;

      // Check for incentives
      if (incentivesBreakdown.isNotEmpty) {
        incentivesBreakdown.forEach((key, value) {
          if (value['criteria'] == 'JOB_EARLY_ARRIVAL') {
            double amount = value['amount'] ?? 0.0;
            timePe = amount > 0 ? '+₹$amount' : '₹$amount';
            hasLateTimePe = false; // Early arrival, not late
          }
          // Add other incentives types here
        });
      }

      // Handle overtime
      String? overtime;
      String? partialOvertime;
      int? otMins = job['ot_mins'];
      double? otPay = job['ot_pay'];

      if (otPay != null && otPay > 0) {
        overtime = '+₹$otPay';
      }

      // Create transformed job entry
      transformedJobEntries.add({
        'id': job['runner_job_id']?.toString() ?? '',
        'hours_worked': job['base_mins'],
        'amount': job['earning'],
        'time_pe': timePe,
        'long_distance': longDistance,
        'overtime': overtime,
        'partial_overtime': partialOvertime,
        'has_late_time_pe': hasLateTimePe,
      });
    }

    return transformedJobEntries;
  }
}
