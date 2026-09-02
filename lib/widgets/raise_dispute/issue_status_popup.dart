import 'package:flutter/material.dart';
import 'package:snabbit_runner/models/issue_data.dart';
import 'package:snabbit_runner/widgets/raise_dispute/issue_open.dart';
import 'package:snabbit_runner/widgets/raise_dispute/issue_rejected.dart';
import 'package:snabbit_runner/widgets/raise_dispute/issue_resolved.dart';


class IssueStatusPopup extends StatelessWidget {
  final IssueData issueData;

  const IssueStatusPopup({super.key, required this.issueData});

  @override
  Widget build(BuildContext context) {
    switch (issueData.status) {
      case IssueStatus.open:
        return IssueOpen(issueData: issueData);
      case IssueStatus.resolved:
        return IssueResolved(issueData: issueData);
      case IssueStatus.rejected:
        return IssueRejected(issueData: issueData);
      default:
        return  IssueOpen(issueData: issueData);
    }
  }
}
