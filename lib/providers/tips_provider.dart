import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/errors/response_error.dart';
import 'package:snabbit_runner/models/tips_model.dart';
import 'package:snabbit_runner/services/tips_http.dart';
import 'package:snabbit_runner/utils/common_methods.dart';

/// Provider for the Tips Info Screen
class TipsProvider with ChangeNotifier {
  bool _loading = false;
  String? _error;
  List<TipItem> _tipsList = [];
  int _totalTips = 0;

  bool get loading => _loading;

  String? get error => _error;

  List<TipItem> get tipsList => _tipsList;

  int get totalTips => _totalTips;

  Future<void> fetchMonthlyTips(DateTime monthStart, DateTime monthEnd) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await TipsHttp.getMonthlyTips(
        startDate: monthStart,
        endDate: monthEnd,
      );

      if (response == null) {
        _error = 'Failed to fetch data';
        _loading = false;
        notifyListeners();
        return;
      }

      if (response.statusCode == 200) {
        _error = null;
        final data = response.data;
        final tipsListData = data['tips_list'] as List? ?? [];
        _tipsList = tipsListData
            .map<TipItem>((item) => TipItem.fromJson(item))
            .where((tip) => tip.date != null && tip.amount != null)
            .toList();

        // Sort tips list by date in ascending order (oldest first)
        _tipsList.sort((a, b) {
          final dateA = a.date ?? DateTime(1970);
          final dateB = b.date ?? DateTime(1970);
          return dateB.compareTo(dateA);
        });

        // Use total tips directly from API
        _totalTips = anyValueToInt(data['total_tips']) ?? 0;
      } else {
        try {
          _error =
              ResponseError.fromMap(response.data).getFirstError()?.message ??
                  "Server error - ${response.statusCode}";
        } catch (e) {
          _error = "Error while parsing custom error - $e";
        }
      }

      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = "Client error - $e";
      _loading = false;
      notifyListeners();
    }
  }
}
