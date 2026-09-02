import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/errors/response_error.dart';
import 'package:snabbit_runner/models/go_live/earning_model.dart';
import 'package:snabbit_runner/models/potential_earnings.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/server_requests/go_live_http.dart';
import 'package:dio/dio.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/utils/error_handler.dart';
import 'package:snabbit_runner/widgets/go_live/slots_unavailable.dart';

class PotentialEarningsProvider with ChangeNotifier {
  DateTime? _selectedRegularStartTime;
  Cluster? _selectedCluster;
  int? _runnerId;
  Hood? _selectedLocality;
  String? _selectedTransport;
  Shift? _selectedRegularShiftDuration;
  DateTime? _selectedWeekendStartTime;
  Shift? _selectedWeekendShiftDuration;

  PotentialEarningsTopSection? topSectionData;
  PotentialEarningsBottomSection? bottomSectionData;

  bool loading = false;
  String? error;

  /// Returns all clusters with recommended clusters prepended
  List<Cluster> get allClusters => topSectionData?.getAllClusters() ?? [];

  /// Returns true if there are recommended clusters
  bool get hasRecommendedClusters =>
      topSectionData?.hasRecommendedClusters ?? false;

  /// Returns all hoods with recommended hoods prepended
  List<Hood> get allHoods => bottomSectionData?.getAllHoods() ?? [];

  /// Returns true if there are recommended hoods
  bool get hasRecommendedHoods =>
      bottomSectionData?.hasRecommendedHoods ?? false;

  /// Returns the recommended status (1, 2, or 3) for a cluster, or null if not recommended
  /// 1 = "1 - Most Recommended"
  /// 2 = "2 - Recommended"
  /// 3 = "3 - Recommended"
  int? getClusterRecommendedStatus(Cluster? cluster) {
    if (cluster == null || topSectionData?.recommendedClusters == null) {
      return null;
    }
    final recommendedClusters = topSectionData!.recommendedClusters!;
    final index = recommendedClusters.indexWhere((c) => c.id == cluster.id);
    if (index == -1) {
      return null;
    }
    // Return 1-based index (1, 2, or 3)
    return index < 3 ? index + 1 : null;
  }

  /// Returns the recommended status text for a cluster, or null if not recommended
  String? getClusterRecommendedStatusText(Cluster? cluster) {
    final status = getClusterRecommendedStatus(cluster);
    if (status == null) return null;
    switch (status) {
      case 1:
        return '1 - Most Recommended';
      case 2:
        return '2 - Recommended';
      case 3:
        return '3 - Recommended';
      default:
        return null;
    }
  }

  /// Returns the recommended status (1, 2, or 3) for a hood, or null if not recommended
  /// 1 = "1 - Most Recommended"
  /// 2 = "2 - Recommended"
  /// 3 = "3 - Recommended"
  int? getHoodRecommendedStatus(Hood? hood) {
    if (hood == null || bottomSectionData?.recommendedHoods == null) {
      return null;
    }
    final recommendedHoods = bottomSectionData!.recommendedHoods!;
    final index = recommendedHoods.indexWhere((h) => h.hoodId == hood.hoodId);
    if (index == -1) {
      return null;
    }
    // Return 1-based index (1, 2, or 3)
    return index < 3 ? index + 1 : null;
  }

  /// Returns the recommended status text for a hood, or null if not recommended
  String? getHoodRecommendedStatusText(Hood? hood) {
    final status = getHoodRecommendedStatus(hood);
    if (status == null) return null;
    switch (status) {
      case 1:
        return '1 - Most Recommended';
      case 2:
        return '2 - Recommended';
      case 3:
        return '3 - Recommended';
      default:
        return null;
    }
  }

  DateTime? get selectedRegularStartTime => _selectedRegularStartTime;
  Cluster? get selectedCluster => _selectedCluster;
  int? get runnerId => _runnerId;
  Hood? get selectedLocality => _selectedLocality ?? allHoods.firstOrNull;
  String? get selectedTransport =>
      _selectedTransport ?? bottomSectionData?.modeTransport?.firstOrNull;
  Shift? get selectedRegularShiftDuration => _selectedRegularShiftDuration;
  DateTime? get selectedWeekendStartTime => _selectedWeekendStartTime;
  Shift? get selectedWeekendShiftDuration => _selectedWeekendShiftDuration;
  List<Shift>? weekendShifts;

  set selectedRegularStartTime(DateTime? value) {
    if (_selectedRegularStartTime != value) {
      _selectedRegularStartTime = value;
      notifyListeners();
    }
  }

  set selectedWeekendStartTime(DateTime? value) {
    if (_selectedWeekendStartTime != value) {
      _selectedWeekendStartTime = value;
      notifyListeners();
    }
  }

  set runnerId(int? value) {
    if (_runnerId != value) {
      _runnerId = value;
      notifyListeners();
    }
  }

  set selectedCluster(Cluster? value) {
    if (_selectedCluster != value) {
      _selectedCluster = value;
      selectedLocality = null;
      bottomSectionData = null;
      notifyListeners();
      // Fetch bottom section data if runnerId and cluster are set
      fetchShiftData();
    }
  }

  void fetchShiftData() {
    if (_runnerId != null &&
        _selectedCluster != null &&
        _selectedCluster!.id != null) {
      fetchBottomSectionData(_runnerId!, _selectedCluster!.id!);
    } else {
      bottomSectionData = null;
      notifyListeners();
    }
  }

  set selectedLocality(Hood? value) {
    if (_selectedLocality != value) {
      _selectedLocality = value;

      notifyListeners();
    }
  }

  set selectedTransport(String? value) {
    if (_selectedTransport != value) {
      _selectedTransport = value;
      notifyListeners();
    }
  }

  set selectedRegularShiftDuration(Shift? value) {
    if (_selectedRegularShiftDuration != value) {
      _selectedRegularShiftDuration = value;
      if (value == null ||
          _selectedRegularShiftDuration?.startTimes
                  ?.contains(_selectedRegularStartTime) ==
              false) {
        _selectedRegularStartTime =
            null; // Reset start time if not in available times
      }
      notifyListeners();
    }
  }

  set selectedWeekendShiftDuration(Shift? value) {
    if (_selectedWeekendShiftDuration != value) {
      _selectedWeekendShiftDuration = value;
      if (value == null ||
          _selectedWeekendShiftDuration?.startTimes
                  ?.contains(_selectedWeekendStartTime) ==
              false) {
        _selectedWeekendStartTime =
            null; // Reset start time if not in available times
      }
      notifyListeners();
    }
  }

  Future<void> fetchAvailableClusters(int runnerId) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await GoLiveHttp.availableClusters(runnerId);
      if (response != null &&
          response.statusCode == 200 &&
          response.data != null) {
        debugPrint(
          'availableClustersRequest headers: ${response.requestOptions.headers}',
        );
        debugPrint(
          "availableClusters response.data: ${response.data}",
          wrapWidth: 1024,
        );
        final topSection = response.data;
        if (topSection != null) {
          topSectionData = PotentialEarningsTopSection.fromJson(topSection);
        } else {
          topSectionData = null;
        }
        // Optionally parse bottomSectionData if needed
        // bottomSectionData = PotentialEarningsBottomSection.fromJson(response.data['bottomSection']);
        error = null;
      } else {
        try {
          debugPrint("availableClusters error: $error");
          ErrorHandler.handleResponseError(
            response: response,
            context: GlobalState().navigatorKey.currentContext!,
            onError: (context, responseError) {
              error = responseError.errors?.firstOrNull?.message;
              showSnackbar(
                  context, responseError.errors?.firstOrNull?.message ?? '');
            },
          );
        } catch (e) {
          error = 'Failed to fetch cluster details';
        }
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  bool regularShiftsLoading = false;

  Future<void> fetchBottomSectionData(int runnerId, int clusterId) async {
    regularShiftsLoading = true;
    error = null;
    notifyListeners();
    try {
      final response =
          await GoLiveHttp.getShiftData(runnerId, clusterId, false);
      if (response != null &&
          response.statusCode == 200 &&
          response.data != null) {
        final bottomSection = response.data;
        if (bottomSection != null) {
          bottomSectionData =
              PotentialEarningsBottomSection.fromJson(bottomSection);
        } else {
          bottomSectionData = null;
        }
        error = null;
      } else {
        error = 'Failed to fetch cluster details';
        bottomSectionData = null;
        try {
          final responseError = ResponseError.fromMap(response?.data);
          final firstError = responseError.getFirstError();
          if (firstError != null) {
            showSlotsUnavailable(
              GlobalState().navigatorKey.currentContext!,
              firstError,
              () {
                Navigator.pop(GlobalState().navigatorKey.currentContext!);
              },
            );
          }
        } catch (e) {
          try {
            showSnackbar(GlobalState().navigatorKey.currentContext!,
                error ?? 'An error occurred while fetching weekday shifts');
          } catch (_) {}
        }
      }
    } catch (e) {
      error = e.toString();
      bottomSectionData = null;
    } finally {
      regularShiftsLoading = false;
      notifyListeners();
    }
  }

  bool weekendShiftsLoading = false;
  Map<String, int>? weekendEarningsData;
  Future<void> fetchWeekendShiftData() async {
    weekendShiftsLoading = true;
    error = null;
    notifyListeners();
    try {
      final response = await GoLiveHttp.getShiftData(
          _runnerId ?? 0, selectedCluster?.id ?? 0, true);
      if (response != null &&
          response.statusCode == 200 &&
          response.data != null) {
        final weekendDurations = response.data["weekend_durations"];
        if (weekendDurations != null) {
          weekendShifts = weekendDurations
              .map<Shift>((e) => Shift.fromJson(e as Map<String, dynamic>))
              .toList();
        } else {
          weekendShifts = null;
        }

        final maxEarnings = response.data["weekend_max_earnings"] ?? {};

        if (maxEarnings != null) {
          Map<String, int> maxEarningsInt = {};
          maxEarnings.forEach((key, value) {
            maxEarningsInt[key] = anyValueToInt(value) ?? 0;
          });
          weekendEarningsData = maxEarningsInt;
        } else {
          weekendEarningsData = null;
        }
        error = null;
      } else {
        error = 'Failed to fetch cluster details';
        weekendShifts = null;
        weekendEarningsData = null;
        try {
          final responseError = ResponseError.fromMap(response?.data);
          final firstError = responseError.getFirstError();
          if (firstError != null) {
            showSlotsUnavailable(
              GlobalState().navigatorKey.currentContext!,
              firstError,
              () {
                Navigator.pop(GlobalState().navigatorKey.currentContext!);
              },
            );
          }
        } catch (e) {
          try {
            showSnackbar(GlobalState().navigatorKey.currentContext!,
                error ?? 'An error occurred while fetching weekend shifts');
          } catch (_) {}
        }
      }
    } catch (e) {
      error = e.toString();
      weekendShifts = null;
    } finally {
      weekendShiftsLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    try {
      _selectedRegularStartTime = null;
      _selectedCluster = null;
      _selectedLocality = null;
      _selectedTransport = null;
      _selectedRegularShiftDuration = null;
      topSectionData = null;
      bottomSectionData = null;
      resetWeekendsData();
    } catch (_) {}
  }

  void resetWeekendsData() {
    try {
      weekendShifts = null;
      weekendEarningsData = null;
      _selectedWeekendShiftDuration = null;
      _selectedWeekendStartTime = null;
    } catch (_) {}
  }

  int get regularShiftDays => selectedWeekendShiftDuration == null ? 30 : 22;

  int get regularEarnings => maxEarningsFromShiftSelection(
      selectedRegularShiftDuration?.hourlyRates ?? []);

  int get weekendEarnings => maxEarningsFromShiftSelection(
      selectedWeekendShiftDuration?.hourlyRates ?? [], true);
  int get weekendRegularEarnings => maxEarningsFromShiftSelection(
      selectedWeekendShiftDuration?.hourlyRates ?? []);

  int get maxEarnings {
    try {
      final maxPay = topSectionData?.weekdayMaxEarnings?[selectedTransport] ??
          topSectionData?.weekdayMaxEarnings?["DEFAULT"] ??
          0;
      if (selectedLocality != null) {
        return bottomSectionData?.maxEarnings?[selectedTransport] ?? maxPay;
      }
      return maxPay;
    } catch (_) {
      return 0;
    }
  }

  int maxEarningsFromShiftSelection(List<EarningModel> hourlyRates,
      [bool weekend = false]) {
    try {
      EarningModel match =
          hourlyRates.where((rate) => rate.adm == selectedTransport).first;
      final detail = weekend ? match.weekend : match.weekday;
      return detail?.maxEarning ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
