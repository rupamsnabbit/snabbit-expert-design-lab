class LoanDetails {
  final bool isEarlyPayoutTaken;
  final bool isLoanProcessed;
  final String vendorUrl;

  LoanDetails({
    required this.isEarlyPayoutTaken,
    required this.isLoanProcessed,
    required this.vendorUrl,
  });

  factory LoanDetails.fromJson(Map<String, dynamic> json) {
    return LoanDetails(
      isEarlyPayoutTaken: json['is_early_payout_taken'] ?? false,
      isLoanProcessed: json['is_loan_processed'] ?? false,
      vendorUrl: json['vendor_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_early_payout_taken': isEarlyPayoutTaken,
      'is_loan_processed': isLoanProcessed,
      'vendor_url': vendorUrl,
    };
  }
}
