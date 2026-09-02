import 'package:flutter/material.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/models/cluster.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/models/recommended_shift.dart';
import 'package:snabbit_runner/pages/go_live/go_live_v2/models/shift_time_bucket.dart';
import 'package:snabbit_runner/services/remote_config/go_live_feature_flags.dart';
import 'package:snabbit_runner/services/server_requests/go_live_v2_http.dart';

/// Provider for Go Live V2 flow state and API interactions
class GoLiveV2Provider with ChangeNotifier {
  // ============ Screen Navigation State ============
  bool _isWeekendMode = false;
  String? _errorType; // For ClusterSelectionScreen error modals
  Region? _selectedRegion; // Selected region from region_selection_screen

  bool get isWeekendMode => _isWeekendMode;
  String? get errorType => _errorType;
  Region? get selectedRegion => _selectedRegion;

  void setWeekendMode(bool value) {
    _isWeekendMode = value;
    notifyListeners();
  }

  void setErrorType(String? value) {
    _errorType = value;
    notifyListeners();
  }

  void setSelectedRegion(Region region) {
    _selectedRegion = region;
    notifyListeners();
  }

  // ============ Loading & Error States ============
  bool _isLoadingRegions = false;
  bool _isLoadingClusters = false;
  bool _isLoadingRecommendations = false;
  bool _isVerifyingShift = false;
  bool _isConfirmingShift = false;
  String? _regionsError;
  String? _regionsErrorCode;
  String? _clustersError;
  String? _clustersErrorCode;
  String? _recommendationsError;
  String? _recommendationsErrorCode;
  String? _verifyShiftError;
  String? _verifyShiftErrorCode;
  String? _confirmShiftError;
  String? _confirmShiftErrorCode;
  int?
      _verifiedHoodId; // Stores hood_id after successful verify_shift for weekend requests

  bool get isLoadingRegions => _isLoadingRegions;
  bool get isLoadingClusters => _isLoadingClusters;
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  bool get isVerifyingShift => _isVerifyingShift;
  bool get isConfirmingShift => _isConfirmingShift;
  String? get regionsError => _regionsError;
  String? get clustersError => _clustersError;
  String? get clustersErrorCode => _clustersErrorCode;
  String? get recommendationsError => _recommendationsError;
  String? get recommendationsErrorCode => _recommendationsErrorCode;
  String? get verifyShiftError => _verifyShiftError;
  String? get verifyShiftErrorCode => _verifyShiftErrorCode;
  String? get confirmShiftError => _confirmShiftError;
  String? get confirmShiftErrorCode => _confirmShiftErrorCode;

  /// Error code constant for partner already onboarded
  static const String partnerAlreadyOnboardedCode = 'PARTNER_ALREADY_ONBOARDED';

  /// Check if regions error is PARTNER_ALREADY_ONBOARDED
  bool get isPartnerAlreadyOnboardedOnRegions =>
      _regionsErrorCode == partnerAlreadyOnboardedCode;

  /// Check if clusters error is PARTNER_ALREADY_ONBOARDED
  bool get isPartnerAlreadyOnboardedOnClusters =>
      _clustersErrorCode == partnerAlreadyOnboardedCode;

  /// Check if recommendations error is NO_SHIFTS_AVAILABLE
  bool get isNoShiftsAvailableError =>
      _recommendationsErrorCode == 'NO_SHIFTS_AVAILABLE';

  /// Check if recommendations error is PARTNER_ALREADY_ONBOARDED
  bool get isPartnerAlreadyOnboardedOnRecommendations =>
      _recommendationsErrorCode == partnerAlreadyOnboardedCode;

  /// Check if verify shift error is SHIFT_NOT_AVAILABLE
  bool get isShiftNotAvailableOnVerify =>
      _verifyShiftErrorCode == 'SHIFT_NOT_AVAILABLE';

  /// Check if verify shift error is PARTNER_ALREADY_ONBOARDED
  bool get isPartnerAlreadyOnboardedOnVerify =>
      _verifyShiftErrorCode == partnerAlreadyOnboardedCode;

  /// Check if confirm shift error is SHIFT_NOT_AVAILABLE
  bool get isShiftNotAvailableOnConfirm =>
      _confirmShiftErrorCode == 'SHIFT_NOT_AVAILABLE';

  /// Check if confirm shift error is PARTNER_ALREADY_ONBOARDED
  bool get isPartnerAlreadyOnboardedOnConfirm =>
      _confirmShiftErrorCode == partnerAlreadyOnboardedCode;

  // ============ API Response Data ============
  RegionsResponse? _regionsResponse;
  ClustersResponse? _clustersResponse;
  RecommendedShiftsResponse? _recommendedShiftsResponse;
  RecommendedShiftsResponse? _weekendRecommendedShiftsResponse;

  RegionsResponse? get regionsResponse => _regionsResponse;
  ClustersResponse? get clustersResponse => _clustersResponse;
  RecommendedShiftsResponse? get recommendedShiftsResponse =>
      _recommendedShiftsResponse;
  RecommendedShiftsResponse? get weekendRecommendedShiftsResponse =>
      _weekendRecommendedShiftsResponse;

  /// Returns available regions from API
  List<Region> get availableRegions => _regionsResponse?.regions ?? [];

  /// Returns available clusters from API
  List<GoLiveCluster> get availableClusters =>
      _clustersResponse?.clusters ?? [];

  /// Returns recommended shifts from API (sorted by rank)
  List<RecommendedShift> get recommendedShifts {
    final shifts = _recommendedShiftsResponse?.shifts ?? [];
    // Sort by rank to ensure correct order
    shifts.sort((a, b) => a.rank.compareTo(b.rank));
    return shifts;
  }

  /// Current index in the recommendations list
  int _currentRecommendationIndex = 0;

  /// Returns current recommendation index
  int get currentRecommendationIndex => _currentRecommendationIndex;

  /// Returns current recommended shift based on index
  RecommendedShift? get currentRecommendedShift {
    final shifts = recommendedShifts;
    if (shifts.isEmpty || _currentRecommendationIndex >= shifts.length) {
      return null;
    }
    return shifts[_currentRecommendationIndex];
  }

  /// Returns top recommended shift (first one, rank 1)
  RecommendedShift? get topRecommendedShift =>
      _recommendedShiftsResponse?.topShift;

  /// Check if there are more recommendations available
  bool get hasMoreRecommendations =>
      _currentRecommendationIndex < recommendedShifts.length - 1;

  // ============ User Selections ============
  List<GoLiveCluster> _selectedClusters = [];
  Map<int, List<Hood>> _selectedHoods =
      {}; // Map of cluster ID -> selected Hoods list (up to 3) for big clusters
  int? _shiftMinHours;
  int? _shiftMaxHours;
  ShiftTimeBucket? _shiftTime;
  int? _weekendShiftMinHours;
  int? _weekendShiftMaxHours;
  ShiftTimeBucket? _weekendShiftTime;
  RecommendedShift? _selectedShift;
  RecommendedShift? _selectedWeekendShift;
  bool _hasSelectedWeekend = false;

  List<GoLiveCluster> get selectedClusters => _selectedClusters;
  Map<int, List<Hood>> get selectedHoods => _selectedHoods;
  int? get shiftMinHours => _shiftMinHours;
  int? get shiftMaxHours => _shiftMaxHours;
  ShiftTimeBucket? get shiftTime => _shiftTime;
  int? get weekendShiftMinHours => _weekendShiftMinHours;
  int? get weekendShiftMaxHours => _weekendShiftMaxHours;
  ShiftTimeBucket? get weekendShiftTime => _weekendShiftTime;
  RecommendedShift? get selectedShift => _selectedShift;
  RecommendedShift? get selectedWeekendShift => _selectedWeekendShift;
  bool get hasSelectedWeekend => _hasSelectedWeekend;

  /// Set whether user selected weekend earnings
  void setHasSelectedWeekend(bool value) {
    _hasSelectedWeekend = value;
    notifyListeners();
  }

  /// Returns selected cluster IDs in ranked order
  List<int> get rankedClusterIds => _selectedClusters.map((c) => c.id).toList();

  /// Returns big clusters that need hood selection
  List<GoLiveCluster> get bigClustersNeedingHoodSelection {
    return _selectedClusters
        .where((c) => c.isBigCluster && c.hoods != null && c.hoods!.isNotEmpty)
        .toList();
  }

  /// Returns big clusters that still need hood selection (not yet selected)
  List<GoLiveCluster> get pendingBigClusters {
    return bigClustersNeedingHoodSelection
        .where((c) =>
            !_selectedHoods.containsKey(c.id) || _selectedHoods[c.id]!.isEmpty)
        .toList();
  }

  /// Check if all big clusters have hood selections
  bool get allBigClustersHaveHoodSelection {
    final bigClusters = bigClustersNeedingHoodSelection;
    if (bigClusters.isEmpty) return true;
    return bigClusters.every((c) =>
        _selectedHoods.containsKey(c.id) && _selectedHoods[c.id]!.isNotEmpty);
  }

  /// Build big cluster hood preferences for API request
  /// Returns null if no hood selections exist
  List<BigClusterHoodPreference>? _buildBigClusterHoodPreferences() {
    if (_selectedHoods.isEmpty) return null;

    final preferences = <BigClusterHoodPreference>[];

    for (final entry in _selectedHoods.entries) {
      final clusterId = entry.key;
      final hoods = entry.value;

      if (hoods.isNotEmpty) {
        // Extract hood IDs in the order they were selected (ranked order)
        final rankedHoodIds = hoods.map((h) => h.id).toList();

        preferences.add(BigClusterHoodPreference(
          clusterId: clusterId,
          rankedHoodIds: rankedHoodIds,
        ));
      }
    }

    return preferences.isEmpty ? null : preferences;
  }

  // ============ API Methods ============

  /// Fetch regions from API
  /// Called when user lands on region_selection_screen.dart
  Future<void> fetchRegions() async {
    _isLoadingRegions = true;
    _regionsError = null;
    _regionsErrorCode = null;
    notifyListeners();

    try {
      _regionsResponse = await GoLiveV2Http.getRegions();
      _isLoadingRegions = false;
      notifyListeners();
    } on GoLiveV2ApiException catch (e) {
      _isLoadingRegions = false;
      _regionsError = e.message;
      _regionsErrorCode = e.errorCode;
      notifyListeners();
    } catch (e) {
      _isLoadingRegions = false;
      _regionsError = e.toString();
      _regionsErrorCode = null;
      notifyListeners();
    }
  }

  /// Fetch clusters from API
  /// Called when user lands on cluster_selection_screen.dart
  Future<void> fetchClusters({int? tcId}) async {
    _isLoadingClusters = true;
    _clustersError = null;
    _clustersErrorCode = null;
    notifyListeners();

    try {
      if (_selectedRegion == null) {
        throw Exception('Region must be selected before fetching clusters');
      }
      _clustersResponse = await GoLiveV2Http.getClusters(
        tcId: tcId,
        regionId: _selectedRegion!.id,
      );
      _isLoadingClusters = false;
      notifyListeners();
    } on GoLiveV2ApiException catch (e) {
      _isLoadingClusters = false;
      _clustersError = e.message;
      _clustersErrorCode = e.errorCode;
      notifyListeners();
    } catch (e) {
      _isLoadingClusters = false;
      _clustersError = e.toString();
      _clustersErrorCode = null;
      notifyListeners();
    }
  }

  /// Fetch recommended shifts from API
  /// Called when user lands on go_live_recommendations_screen.dart
  Future<void> fetchRecommendedShifts({bool isWeekend = false}) async {
    if (_selectedClusters.isEmpty ||
        _shiftMinHours == null ||
        _shiftMaxHours == null ||
        _shiftTime == null) {
      _recommendationsError = 'Please complete all selections first';
      _recommendationsErrorCode = null;
      notifyListeners();
      return;
    }

    _isLoadingRecommendations = true;
    _recommendationsError = null;
    _recommendationsErrorCode = null;
    notifyListeners();

    try {
      final request = RecommendedShiftsRequest(
        rankedClusterIds: rankedClusterIds,
        shiftDurationMin: _shiftMinHours!,
        shiftDurationMax: _shiftMaxHours!,
        startHourRangeMin: _shiftTime!.startHourRangeMin,
        startHourRangeMax: _shiftTime!.startHourRangeMax,
        isWeekend: isWeekend,
        limit: GoLiveFeatureFlags.getRecommendedShiftsLimit(),
        bigClusterHoodPreferences: _buildBigClusterHoodPreferences(),
      );

      if (isWeekend) {
        _weekendRecommendedShiftsResponse =
            await GoLiveV2Http.getRecommendedShifts(request);
      } else {
        _recommendedShiftsResponse =
            await GoLiveV2Http.getRecommendedShifts(request);
        // Auto-select top shift
        _selectedShift = _recommendedShiftsResponse?.topShift;
      }

      _isLoadingRecommendations = false;
      notifyListeners();
    } on GoLiveV2ApiException catch (e) {
      _isLoadingRecommendations = false;
      _recommendationsError = e.message;
      _recommendationsErrorCode = e.errorCode;
      notifyListeners();
    } catch (e) {
      _isLoadingRecommendations = false;
      _recommendationsError = e.toString();
      _recommendationsErrorCode = null;
      notifyListeners();
    }
  }

  /// Fetch weekend recommended shifts from API
  /// Called when user lands on weekend recommendations screen
  /// Uses weekend-specific duration and time selections
  Future<void> fetchWeekendRecommendedShifts() async {
    if (_selectedClusters.isEmpty ||
        _weekendShiftMinHours == null ||
        _weekendShiftMaxHours == null ||
        _weekendShiftTime == null) {
      _recommendationsError = 'Please complete all weekend selections first';
      _recommendationsErrorCode = null;
      notifyListeners();
      return;
    }

    _isLoadingRecommendations = true;
    _recommendationsError = null;
    _recommendationsErrorCode = null;
    notifyListeners();

    try {
      // Use same clusters but weekend duration and time
      final request = RecommendedShiftsRequest(
        rankedClusterIds: rankedClusterIds,
        shiftDurationMin: _weekendShiftMinHours!,
        shiftDurationMax: _weekendShiftMaxHours!,
        startHourRangeMin: _weekendShiftTime!.startHourRangeMin,
        startHourRangeMax: _weekendShiftTime!.startHourRangeMax,
        isWeekend: true,
        hoodId: _verifiedHoodId, // Pass verified hood_id from weekday shift
        limit: GoLiveFeatureFlags.getRecommendedShiftsLimit(),
        bigClusterHoodPreferences: _buildBigClusterHoodPreferences(),
      );

      _weekendRecommendedShiftsResponse =
          await GoLiveV2Http.getRecommendedShifts(request);

      // Reset recommendation index for weekend shifts
      _currentRecommendationIndex = 0;

      _isLoadingRecommendations = false;
      notifyListeners();
    } on GoLiveV2ApiException catch (e) {
      _isLoadingRecommendations = false;
      _recommendationsError = e.message;
      _recommendationsErrorCode = e.errorCode;
      notifyListeners();
    } catch (e) {
      _isLoadingRecommendations = false;
      _recommendationsError = e.toString();
      _recommendationsErrorCode = null;
      notifyListeners();
    }
  }

  /// Returns recommended shifts for weekend from API (sorted by rank)
  List<RecommendedShift> get weekendRecommendedShifts {
    final shifts = _weekendRecommendedShiftsResponse?.shifts ?? [];
    shifts.sort((a, b) => a.rank.compareTo(b.rank));
    return shifts;
  }

  /// Returns current weekend recommended shift based on index
  RecommendedShift? get currentWeekendRecommendedShift {
    final shifts = weekendRecommendedShifts;
    if (shifts.isEmpty || _currentRecommendationIndex >= shifts.length) {
      return null;
    }
    return shifts[_currentRecommendationIndex];
  }

  /// Check if there are more weekend recommendations available
  bool get hasMoreWeekendRecommendations =>
      _currentRecommendationIndex < weekendRecommendedShifts.length - 1;

  // ============ Selection Methods ============

  /// Toggle cluster selection (max 3)
  void toggleCluster(GoLiveCluster cluster) {
    if (_selectedClusters.contains(cluster)) {
      _selectedClusters.remove(cluster);
    } else if (_selectedClusters.length < 3) {
      _selectedClusters.add(cluster);
    }
    notifyListeners();
  }

  /// Set selected clusters directly
  void setSelectedClusters(List<GoLiveCluster> clusters) {
    _selectedClusters = clusters;
    notifyListeners();
  }

  /// Set selected hoods for a big cluster (up to 3)
  void setSelectedHoods(int clusterId, List<Hood> hoods) {
    _selectedHoods[clusterId] = hoods;
    notifyListeners();
  }

  /// Get selected hoods for a specific cluster
  List<Hood> getSelectedHoodsForCluster(int clusterId) {
    return _selectedHoods[clusterId] ?? [];
  }

  /// Check if a hood is selected for a specific cluster
  bool isHoodSelected(int clusterId, Hood hood) {
    return _selectedHoods[clusterId]?.any((h) => h.id == hood.id) ?? false;
  }

  /// Get selection index (1-3) for a hood in a specific cluster
  int? getHoodSelectionIndex(int clusterId, Hood hood) {
    final hoods = _selectedHoods[clusterId];
    if (hoods == null) return null;
    final index = hoods.indexWhere((h) => h.id == hood.id);
    return index == -1 ? null : index + 1;
  }

  /// Clear all hood selections (used when user goes back to cluster selection)
  void clearAllHoodSelections() {
    _selectedHoods.clear();
    notifyListeners();
  }

  /// Clear all cluster selections (used when user goes back to region selection)
  void clearSelectedClusters() {
    _selectedClusters = [];
    notifyListeners();
  }

  /// Set shift hours (min and max)
  void setShiftHours(int minHours, int maxHours) {
    _shiftMinHours = minHours;
    _shiftMaxHours = maxHours;
    notifyListeners();
  }

  /// Set shift time
  void setShiftTime(ShiftTimeBucket time) {
    _shiftTime = time;
    notifyListeners();
  }

  /// Set weekend shift hours (min and max)
  void setWeekendShiftHours(int minHours, int maxHours) {
    _weekendShiftMinHours = minHours;
    _weekendShiftMaxHours = maxHours;
    notifyListeners();
  }

  /// Set weekend shift time
  void setWeekendShiftTime(ShiftTimeBucket time) {
    _weekendShiftTime = time;
    notifyListeners();
  }

  /// Set selected shift from recommendations
  void setSelectedShift(RecommendedShift shift) {
    _selectedShift = shift;
    notifyListeners();
  }

  /// Set selected weekend shift from recommendations
  void setSelectedWeekendShift(RecommendedShift shift) {
    _selectedWeekendShift = shift;
    notifyListeners();
  }

  // ============ Helper Methods ============

  /// Check if user can proceed from cluster selection
  bool get canProceedFromClusterSelection {
    final minRequired =
        availableClusters.length < 2 ? availableClusters.length : 2;
    return _selectedClusters.isNotEmpty &&
        _selectedClusters.length >= minRequired;
  }

  /// Check if user can proceed from shift hours selection
  bool get canProceedFromShiftHours =>
      _shiftMinHours != null && _shiftMaxHours != null;

  /// Check if user can proceed from shift time selection
  bool get canProceedFromShiftTime => _shiftTime != null;

  /// Check if flow is complete
  bool get isFlowComplete =>
      _selectedClusters.isNotEmpty &&
      _shiftMinHours != null &&
      _shiftMaxHours != null &&
      _shiftTime != null &&
      _selectedShift != null;

  /// Get selection index for a cluster (1-based, or null if not selected)
  int? getClusterSelectionIndex(GoLiveCluster cluster) {
    final index = _selectedClusters.indexOf(cluster);
    return index >= 0 ? index + 1 : null;
  }

  /// Check if a cluster is selected
  bool isClusterSelected(GoLiveCluster cluster) {
    return _selectedClusters.contains(cluster);
  }

  /// Check if max clusters are selected
  bool get isMaxClustersSelected => _selectedClusters.length >= 3;

  /// Get primary cluster name
  String get primaryClusterName =>
      _selectedClusters.isNotEmpty ? _selectedClusters.first.name : '';

  /// Get shift time text
  String get shiftTimeText => _shiftTime?.timeText ?? '';

  /// Reset all state
  void reset() {
    _isWeekendMode = false;
    _errorType = null;
    _selectedRegion = null;
    _isLoadingClusters = false;
    _isLoadingRecommendations = false;
    _isVerifyingShift = false;
    _isConfirmingShift = false;
    _regionsError = null;
    _regionsErrorCode = null;
    _clustersError = null;
    _clustersErrorCode = null;
    _recommendationsError = null;
    _recommendationsErrorCode = null;
    _verifyShiftError = null;
    _verifyShiftErrorCode = null;
    _confirmShiftError = null;
    _confirmShiftErrorCode = null;
    _regionsResponse = null;
    _clustersResponse = null;
    _recommendedShiftsResponse = null;
    _weekendRecommendedShiftsResponse = null;
    _selectedClusters = [];
    _selectedHoods = {};
    _shiftMinHours = null;
    _shiftMaxHours = null;
    _shiftTime = null;
    _weekendShiftMinHours = null;
    _weekendShiftMaxHours = null;
    _weekendShiftTime = null;
    _selectedShift = null;
    _selectedWeekendShift = null;
    _hasSelectedWeekend = false;
    _currentRecommendationIndex = 0;
    notifyListeners();
  }

  // ============ Shift Navigation Methods ============

  /// Show next recommendation (called when Cancel is tapped)
  /// Always increments the index. When index exceeds available shifts,
  /// currentRecommendedShift will return null and UI shows exhausted state.
  void showNextRecommendation() {
    _currentRecommendationIndex++;
    notifyListeners();
  }

  /// Reset recommendation index to start
  void resetRecommendationIndex() {
    _currentRecommendationIndex = 0;
    notifyListeners();
  }

  // ============ Verify Shift API ============

  /// Verify the current selected shift
  /// Called when user taps Confirm on recommendations screen
  /// Pass isWeekend: true when verifying weekend shift
  Future<VerifyShiftResponse?> verifyCurrentShift(
      {bool isWeekend = false}) async {
    final shift =
        isWeekend ? currentWeekendRecommendedShift : currentRecommendedShift;
    if (shift == null) return null;

    _isVerifyingShift = true;
    _verifyShiftError = null;
    _verifyShiftErrorCode = null;
    notifyListeners();

    try {
      final request = VerifyShiftRequest(
        hoodId: shift.hoodId,
        shiftTimings: ShiftTimingsData(
          start: shift.shiftTimings.start,
          end: shift.shiftTimings.end,
        ),
        isWeekend: isWeekend,
      );

      final response = await GoLiveV2Http.verifyShift(request);

      _isVerifyingShift = false;

      if (response.isAvailable) {
        // Set the selected shift on success
        if (isWeekend) {
          _selectedWeekendShift = shift;
          _hasSelectedWeekend = true;
        } else {
          _selectedShift = shift;
          // Save hood_id for weekend recommendations API
          _verifiedHoodId = shift.hoodId;
        }
        notifyListeners();
        return response;
      } else {
        _verifyShiftError = response.errors.isNotEmpty
            ? response.errors.first.message
            : 'Shift not available';
        notifyListeners();
        return response;
      }
    } on GoLiveV2ApiException catch (e) {
      _isVerifyingShift = false;
      _verifyShiftError = e.message;
      _verifyShiftErrorCode = e.errorCode;
      notifyListeners();
      return null;
    } catch (e) {
      _isVerifyingShift = false;
      _verifyShiftError = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ============ Confirm Shift API ============

  /// Confirm the shift and go live
  /// Called when user taps Proceed on confirm shift timings screen
  Future<ConfirmShiftResponse?> confirmShift() async {
    // debugPrint('[GoLiveV2Provider] confirmShift() called');
    // debugPrint('[GoLiveV2Provider] _hasSelectedWeekend: $_hasSelectedWeekend');
    // debugPrint(
    //     '[GoLiveV2Provider] _selectedShift: ${_selectedShift?.shiftTimings.start} - ${_selectedShift?.shiftTimings.end}');
    // debugPrint(
    //     '[GoLiveV2Provider] _selectedWeekendShift: ${_selectedWeekendShift?.shiftTimings.start} - ${_selectedWeekendShift?.shiftTimings.end}');

    // For weekend-only users: they won't have a weekday shift, only weekend
    // For everyday users: they will have a weekday shift, and optionally weekend
    final hasWeekdayShift = _selectedShift != null;
    final hasWeekendShift =
        _hasSelectedWeekend && _selectedWeekendShift != null;

    if (!hasWeekdayShift && !hasWeekendShift) {
      // debugPrint(
      //     '[GoLiveV2Provider] confirmShift() - No shift selected (weekday or weekend), returning null');
      return null;
    }

    _isConfirmingShift = true;
    _confirmShiftError = null;
    _confirmShiftErrorCode = null;
    notifyListeners();

    try {
      // Build weekday selection only if user has a weekday shift (everyday users)
      ShiftSelectionData? weekdaySelection;
      if (hasWeekdayShift) {
        weekdaySelection = ShiftSelectionData(
          hoodId: _selectedShift!.hoodId,
          shiftTimings: ShiftTimingsData(
            start: _selectedShift!.shiftTimings.start,
            end: _selectedShift!.shiftTimings.end,
          ),
          rateCardId: _selectedShift!.rateCardId,
        );
      }

      // Add weekend selection only if user selected Yes on weekend modal AND weekend API succeeded
      // OR if user is weekend-only
      ShiftSelectionData? weekendSelection;
      if (hasWeekendShift) {
        // debugPrint(
        //     '[GoLiveV2Provider] confirmShift() - Including weekend selection in request');
        weekendSelection = ShiftSelectionData(
          hoodId: _selectedWeekendShift!.hoodId,
          shiftTimings: ShiftTimingsData(
            start: _selectedWeekendShift!.shiftTimings.start,
            end: _selectedWeekendShift!.shiftTimings.end,
          ),
          rateCardId: _selectedWeekendShift!.rateCardId,
        );
      }
      // else {
      //   debugPrint(
      //       '[GoLiveV2Provider] confirmShift() - NOT including weekend selection (hasSelectedWeekend: $_hasSelectedWeekend, selectedWeekendShift: $_selectedWeekendShift)');
      // }

      // debugPrint(
      //     '[GoLiveV2Provider] confirmShift() - weekdaySelection: ${weekdaySelection != null ? "present" : "null"}, weekendSelection: ${weekendSelection != null ? "present" : "null"}');

      final request = ConfirmShiftRequest(
        weekdaySelection: weekdaySelection,
        weekendSelection: weekendSelection,
      );

      final response = await GoLiveV2Http.confirmShift(request);

      _isConfirmingShift = false;

      if (response.success) {
        notifyListeners();
        return response;
      } else {
        _confirmShiftError = response.errors.isNotEmpty
            ? response.errors.first.message
            : 'Confirmation failed';
        notifyListeners();
        return response;
      }
    } on GoLiveV2ApiException catch (e) {
      _isConfirmingShift = false;
      _confirmShiftError = e.message;
      _confirmShiftErrorCode = e.errorCode;
      notifyListeners();
      return null;
    } catch (e) {
      _isConfirmingShift = false;
      _confirmShiftError = e.toString();
      notifyListeners();
      return null;
    }
  }
}
