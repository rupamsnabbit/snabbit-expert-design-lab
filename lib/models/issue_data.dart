// Updated enum IssueStatus
enum IssueStatus {
  open("Open"),
  resolved("Resolved"),
  rejected("Rejected"),
  underReview("Under Review");

  final String displayText;

  const IssueStatus(this.displayText);

  static IssueStatus? fromString(String? status) {
    switch (status?.toLowerCase()) {
      case "pending":
      case "open":
        return open;
      case "resolved":
        return resolved;
      case "rejected":
        return rejected;
      case "under_review":
        return underReview;
      default:
        return null;
    }
  }

  static String? fromViewString(String? status) {
    switch (status?.toLowerCase()) {
      case "all":
        return null;
      case "open":
        return "open";
      case "resolved":
        return "resolved";
      case "rejected":
        return "rejected";
      case "under review":
        return "under_review";
      default:
        return null;
    }
  }
}

// Updated model class to hold the data for an IssueCard.
class IssueData {
  final int? id;
  final String? issueType;
  final DateTime? issueDate;
  final IssueStatus? status;
  final String? comment;
  final String? resolutionComment;
  final int? reviewCount;
  final String? appealComment;
  final DateTime? createdAt;
  final String? expertName;
  final double? manualAdjustmentAmount;

  IssueData({
    this.id,
    this.issueType,
    this.issueDate,
    this.status,
    this.comment,
    this.resolutionComment,
    this.reviewCount,
    this.appealComment,
    this.createdAt,
    this.expertName,
    this.manualAdjustmentAmount,
  });

  /// Factory constructor to create an [IssueData] instance from a JSON map.
  factory IssueData.fromJson(Map<String, dynamic> json) {
    return IssueData(
      id: json['id'],
      issueType: json['issue_type'],
      issueDate: json['issue_date'] != null
          ? DateTime.tryParse(json['issue_date'])
          : null,
      status: IssueStatus.fromString(json['status']),
      comment: json['comment'],
      resolutionComment: json['resolution_comment'],
      reviewCount: json['review_count'],
      appealComment: json['appeal_comment'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      expertName: json['expert_name'],
      manualAdjustmentAmount:
          (json['manual_adjustment_amount'] as num?)?.toDouble(),
    );
  }

  /// Converts the [IssueData] instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'issue_type': issueType,
      'issue_date': issueDate?.toIso8601String(),
      'status': status?.name,
      'comment': comment,
      'resolution_comment': resolutionComment,
      'review_count': reviewCount,
      'appeal_comment': appealComment,
      'created_at': createdAt?.toIso8601String(),
      'expert_name': expertName,
      'manual_adjustment_amount': manualAdjustmentAmount,
    };
  }

  /// CopyWith method for immutability
  IssueData copyWith({
    int? id,
    String? issueType,
    DateTime? issueDate,
    IssueStatus? status,
    String? comment,
    String? resolutionComment,
    int? reviewCount,
    String? appealComment,
    DateTime? createdAt,
    String? expertName,
    double? manualAdjustmentAmount,
  }) {
    return IssueData(
      id: id ?? this.id,
      issueType: issueType ?? this.issueType,
      issueDate: issueDate ?? this.issueDate,
      status: status ?? this.status,
      comment: comment ?? this.comment,
      resolutionComment: resolutionComment ?? this.resolutionComment,
      reviewCount: reviewCount ?? this.reviewCount,
      appealComment: appealComment ?? this.appealComment,
      createdAt: createdAt ?? this.createdAt,
      expertName: expertName ?? this.expertName,
      manualAdjustmentAmount:
          manualAdjustmentAmount ?? this.manualAdjustmentAmount,
    );
  }
}
