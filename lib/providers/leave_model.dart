import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/runner_leave_http.dart';
import '../utils/constants.dart';

enum LeaveApplicationStep {
  applyForLeave,
  leaveReason,
  leaveSubmitted,
  leavePending,
  leaveCancelled,
  leaveDenied,
  cancelConfirmation,
  leaveApproved,
}

class LeaveApplicationData with ChangeNotifier {
  LeaveApplicationStep leaveApplicationStep =
      LeaveApplicationStep.applyForLeave;
  DateTime? startDate;
  DateTime? endDate;
  String? reason;
  String? otherReason;
  String? errorWhileApplyingLeave;
  LeaveApplication? currentLeaveApplication;
  bool loading = true;
  bool hasMore = true;
  String? leavePageError;
  LeaveResponse? leaveResponse;
  List<LeaveApplication>? leaveRequests;

  LeaveApplicationData();

  void reset() {
    resetLeaveApplicationParams();
    loading = true;
    hasMore = true;
    leaveResponse = null;
    leaveRequests = null;
  }

  void resetLeaveApplicationParams() {
    leaveApplicationStep = LeaveApplicationStep.applyForLeave;
    startDate = null;
    endDate = null;
    reason = null;
    otherReason = null;
    errorWhileApplyingLeave = null;
    currentLeaveApplication = null;
  }

  void updateLeaveApplicationStep(
      LeaveApplicationStep newLeaveApplicationStep) {
    leaveApplicationStep = newLeaveApplicationStep;
    notifyListeners();
  }

  void updateStartDate(DateTime? newStartDate) {
    startDate = newStartDate;
    notifyListeners();
  }

  void updateEndDate(DateTime? newEndDate) {
    endDate = newEndDate;
    notifyListeners();
  }

  void updateReason(String? newReason) {
    reason = newReason;
    notifyListeners();
  }

  void updateOtherReason(String? newOtherReason) {
    otherReason = newOtherReason;
    notifyListeners();
  }

  void updateErrorWhileApplyingLeave(String? newErrorWhileApplyingLeave) {
    errorWhileApplyingLeave = newErrorWhileApplyingLeave;
    notifyListeners();
  }

  void updateCurrentLeaveApplication(LeaveApplication? newCurrentLeaveApplication) {
    currentLeaveApplication = newCurrentLeaveApplication;
    notifyListeners();
  }

  void updateLoading(bool val) {
    loading = val;
  }

  Future<void> getAllLeaveApplications({String? cursor}) async {
    try {
      updateLoading(true);
      notifyListeners();
      Response? response = await RunnerLeaveHTTP.getLeaves(queryParameters: {
        "size": leavePageSize,
        "cursor": cursor,
      });
      if (response?.statusCode == 200 && response?.data != null) {
        leaveResponse = LeaveResponse.fromMap(response?.data);
        if (cursor == null) {
          leaveRequests = leaveResponse?.items;
        } else {
          leaveRequests?.addAll(leaveResponse?.items ?? []);
        }
        if (leaveResponse?.nextPage == null) {
          hasMore = false;
        } else {
          hasMore = true;
        }
        // Logger().d(response?.data);
      } else {
        leavePageError = "Something went wrong on server - ${response?.statusCode}";
      }
    } catch (e) {
      leavePageError = "Something went wrong - $e";
    }
    updateLoading(false);
    notifyListeners();
  }

  void notify() {
    notifyListeners();
  }
}


class LeaveResponse {
  final List<LeaveApplication>? items;
  final int? total;
  final String? currentPage;
  final String? nextPage;
  final String? previousPage;

  LeaveResponse({
    this.items,
    this.total,
    this.currentPage,
    this.nextPage,
    this.previousPage,
  });

  factory LeaveResponse.fromMap(Map<String, dynamic> map) {
    return LeaveResponse(
      items: map['items']
          ?.map<LeaveApplication>(
              (e) => LeaveApplication.fromMap(e as Map<String, dynamic>))
          .toList(),
      total: map['total'],
      currentPage: map['current_page'],
      nextPage: map['next_page'],
      previousPage: map['previous_page'],
    );
  }
}

class LeaveApplication {
  final int id;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? reason;
  final String? status;
  final String? rejectionReason;
  final DateTime? createdAt;

  LeaveApplication({
    required this.id,
    this.startDate,
    this.endDate,
    this.reason,
    this.status,
    this.rejectionReason,
    this.createdAt,
  });

  factory LeaveApplication.fromMap(Map<String, dynamic> map) {
    return LeaveApplication(
      id: map['id'],
      startDate: DateTime.tryParse(map['start_date'] ?? ""),
      endDate: DateTime.tryParse(map['end_date'] ?? ""),
      reason: map['reason'],
      status: map['status'],
      rejectionReason: map['rejection_reason'],
      createdAt: DateTime.tryParse(map['created_at'] ?? ""),
    );
  }
}
