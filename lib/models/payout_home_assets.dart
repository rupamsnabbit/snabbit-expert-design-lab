class ItemAsset {
  final String? backgroundImage;
  final String? icon;

  ItemAsset({
    this.backgroundImage,
    this.icon,
  });

  factory ItemAsset.fromJson(Map<String, dynamic> json) {
    return ItemAsset(
      backgroundImage: json['background_image'],
      icon: json['icon'],
    );
  }
}

class PayoutHomeAssets {
  final ItemAsset? viewDailyEarnings;
  final ItemAsset? viewMonthlyBonus;
  final ItemAsset? viewCustomerTips;
  final ItemAsset? viewTransactionHistory;
  final ItemAsset? withdrawEarlyPayout;
  final ItemAsset? viewReferralDetails;
  PayoutHomeAssets({
    this.viewDailyEarnings,
    this.viewMonthlyBonus,
    this.viewCustomerTips,
    this.viewTransactionHistory,
    this.withdrawEarlyPayout,
    this.viewReferralDetails,
  });

  factory PayoutHomeAssets.fromJson(Map<String, dynamic> json) {
    return PayoutHomeAssets(
      viewDailyEarnings: json['view_daily_earnings'] != null
          ? ItemAsset.fromJson(json['view_daily_earnings'])
          : null,
      viewMonthlyBonus: json['view_monthly_bonus'] != null
          ? ItemAsset.fromJson(json['view_monthly_bonus'])
          : null,
      viewCustomerTips: json['view_customer_tips'] != null
          ? ItemAsset.fromJson(json['view_customer_tips'])
          : null,
      viewTransactionHistory: json['view_transaction_history'] != null
          ? ItemAsset.fromJson(json['view_transaction_history'])
          : null,
      withdrawEarlyPayout: json['withdraw_early_payout'] != null
          ? ItemAsset.fromJson(json['withdraw_early_payout'])
          : null,
      viewReferralDetails: json['view_referral_details'] != null
          ? ItemAsset.fromJson(json['view_referral_details'])
          : null,
    );
  }
}
