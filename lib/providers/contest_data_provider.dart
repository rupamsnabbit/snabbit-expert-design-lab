import 'package:flutter/material.dart';
import 'package:snabbit_runner/providers/referral.dart';
import 'package:snabbit_runner/referrals/models/leaderboard_models.dart';
import 'package:snabbit_runner/services/server_requests/contest_http.dart';
import 'package:snabbit_runner/utils/enums.dart';

class ContestDataProvider with ChangeNotifier {
  // Cache for contest data by contest ID
  final Map<int, ContestModel> _contestCache = {};
  final Map<int, LeaderboardResponse> _leaderboardCache = {};

  // Current contest data
  ContestModel? _currentContest;
  LeaderboardResponse? _currentLeaderboard;

  // Loading and error states
  bool _loading = false;
  String? _error;

  // Getters
  ContestModel? get currentContest => _currentContest;

  LeaderboardResponse? get currentLeaderboard => _currentLeaderboard;

  bool get loading => _loading;

  String? get error => _error;

  Map<String, dynamic>? get currentContestUnit => _currentContest?.unit;

  // Check if contest is active
  bool isContestActive(int? contestId) {
    if (contestId == null) return false;

    final contest = _contestCache[contestId];
    if (contest == null) return false;

    // Check if contest status is active and not expired
    if (contest.status != ContestStatus.active) return false;

    // Check if contest hasn't ended
    if (contest.endDate != null && DateTime.now().isAfter(contest.endDate!)) {
      return false;
    }

    return true;
  }

  // Get current user's rank in leaderboard
  int? getCurrentUserRank() {
    if (_currentLeaderboard == null) return null;

    return _currentLeaderboard!.currentUser?.order;
  }

  // Set contest data
  void setContestData(ContestModel contest) {
    _currentContest = contest;
    if (contest.id != null) {
      _contestCache[contest.id!] = contest;
    }
    notifyListeners();
  }

  // Set leaderboard data
  void setLeaderboardData(LeaderboardResponse leaderboard) {
    _currentLeaderboard = leaderboard;
    if (leaderboard.id != null) {
      _leaderboardCache[leaderboard.id!] = leaderboard;
    }
    notifyListeners();
  }

  // Fetch leaderboard data for a contest
  Future<void> fetchLeaderboardData(int contestId) async {
    if (_loading) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response =
          await ContestHttp.getContestLeaderboard(contestId: contestId);

      if (response != null && response.statusCode == 200) {
        final leaderboardData = LeaderboardResponse.fromMap(response.data);
        setLeaderboardData(leaderboardData);
        _error = null;
      } else {
        _error = "Failed to fetch leaderboard data - ${response?.statusCode}";
      }
    } catch (e) {
      _error = "Error fetching leaderboard data: $e";
    }

    _loading = false;
    notifyListeners();
  }
}
