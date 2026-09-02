class Assets {
  final String? bankWarning;
  final String? debit;
  final String? credit;
  final String? payoutsEmptyStateView;
  final String? bankInstitution;
  final String? bank;
  final String? cashWithdrawn;
  final String? totalAmount;
  final String? uniformSet;
  final String? cashCollected;
  final String? withdrawalSuccessful;
  final String? withdrawalFailed;

  Assets({
    this.bankWarning,
    this.debit,
    this.credit,
    this.payoutsEmptyStateView,
    this.bankInstitution,
    this.bank,
    this.cashWithdrawn,
    this.totalAmount,
    this.uniformSet,
    this.cashCollected,
    this.withdrawalSuccessful,
    this.withdrawalFailed,
  });

  factory Assets.fromJson(Map<String, dynamic> json) {
    return Assets(
      bankWarning: json['bank_warning'] as String?,
      debit: json['debit'] as String?,
      credit: json['credit'] as String?,
      payoutsEmptyStateView: json['payouts_empty_state_view'] as String?,
      bankInstitution: json['bank_institution'] as String?,
      bank: json['bank'] as String?,
      cashWithdrawn: json['cash_withdrawn'] as String?,
      totalAmount: json['total_amount'] as String?,
      uniformSet: json['uniform_set'] as String?,
      cashCollected: json['cash_collected'] as String?,
      withdrawalSuccessful: json['withdrawal_successful'] as String?,
      withdrawalFailed: json['withdrawal_failed'] as String?,
    );
  }
}
