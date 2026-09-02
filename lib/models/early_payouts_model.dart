import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:snabbit_runner/models/payout/upi_account.dart';
import 'package:snabbit_runner/models/payout/bank_account.dart';

enum IneligibilityReason {
  locked,
  addBankAccount,
  inProgress,
  amountIneligible,
  addPan,
  dailyLimitReached
}

class EarlyPayoutBenefit {
  final String? title;
  final String? backgroundImage;

  EarlyPayoutBenefit({
    this.title,
    this.backgroundImage,
  });

  factory EarlyPayoutBenefit.fromJson(Map<String, dynamic> json) {
    return EarlyPayoutBenefit(
      title: json['title'],
      backgroundImage: json['background_image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'background_image': backgroundImage,
    };
  }
}

class EarlyPayoutRequirement {
  final String? label;

  EarlyPayoutRequirement({
    this.label,
  });

  factory EarlyPayoutRequirement.fromJson(Map<String, dynamic> json) {
    return EarlyPayoutRequirement(
      label: json['label'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
    };
  }
}

class EarlyPayoutsData {
  final String? image;
  final int? maxWithdrawableAmount;
  final String? currency;
  final List<EarlyPayoutBenefit>? benefits;
  final int? minWithdrawalAmount;
  final int? maxWithdrawalAmount;
  final List<String>? processingNotes;
  final bool? eligible;
  final IneligibilityReason? ineligibilityReason;
  final List<EarlyPayoutRequirement>? requirements;
  final double? interest;
  final double? currentWithdrawalAmount;
  final List<BankAccount>? bankAccounts;
  final List<UpiAccount>? upiAccounts;

  EarlyPayoutsData({
    this.image,
    this.maxWithdrawableAmount,
    this.currency,
    this.benefits,
    this.minWithdrawalAmount,
    this.maxWithdrawalAmount,
    this.processingNotes,
    this.eligible,
    this.ineligibilityReason,
    this.requirements,
    this.interest,
    this.currentWithdrawalAmount,
    this.bankAccounts,
    this.upiAccounts,
  });

  factory EarlyPayoutsData.fromJson(Map<String, dynamic> json) {
    return EarlyPayoutsData(
      image: json['image'],
      maxWithdrawableAmount: anyValueToInt(json['max_withdrawable_amount']),
      currency: json['currency'],
      benefits: (json['benefits'] as List<dynamic>?)
              ?.map((item) => EarlyPayoutBenefit.fromJson(item))
              .toList() ??
          [],
      minWithdrawalAmount: anyValueToInt(json['min_withdrawal_amount']),
      maxWithdrawalAmount: anyValueToInt(json['max_withdrawal_amount']),
      processingNotes: (json['processing_notes'] as List<dynamic>?)
              ?.map((item) => item as String)
              .toList() ??
          [],
      eligible: json['eligible'] ?? false,
      ineligibilityReason: json['ineligibility_reason'] != null
          ? _parseIneligibilityReason(json['ineligibility_reason'] as String)
          : null,
      requirements: (json['requirements'] as List<dynamic>?)
              ?.map((item) => EarlyPayoutRequirement.fromJson(item))
              .toList() ??
          [],
      interest: anyValueToDouble(json['interest_rate']),
      currentWithdrawalAmount:
          anyValueToDouble(json['current_withdrawal_amount']),
      bankAccounts: json['bank_accounts'] != null
          ? (json['bank_accounts'] as List)
              .map((item) => BankAccount.fromJson(item))
              .toList()
          : null,
      upiAccounts: json['upi_accounts'] != null
          ? (json['upi_accounts'] as List)
              .map((item) => UpiAccount.fromJson(item))
              .toList()
          : null,
    );
  }

  static IneligibilityReason? _parseIneligibilityReason(String reason) {
    switch (reason.toUpperCase()) {
      case 'LOCKED':
        return IneligibilityReason.locked;
      case 'ADD_BANK_ACCOUNT':
        return IneligibilityReason.addBankAccount;
      case 'IN_PROGRESS':
        return IneligibilityReason.inProgress;
      case 'AMOUNT_INELIGIBLE':
        return IneligibilityReason.amountIneligible;
      case 'DAILY_LIMIT':
        return IneligibilityReason.dailyLimitReached;
      case 'ADD_PAN':
        return IneligibilityReason.addPan;
      default:
        return null;
    }
  }
}
