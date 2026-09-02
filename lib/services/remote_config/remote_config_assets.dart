import 'package:snabbit_runner/services/remote_config/remote_config_service.dart'
    show RemoteConfigService;
import 'package:snabbit_runner/utils/extensions/cdn_extensions.dart';

class RemoteConfigAssetKeys {
  RemoteConfigAssetKeys._();

  /// The single Remote Config key holding the JSON map every asset key below
  /// is looked up in — listen on this one for asset live-updates.
  static const String assetsRoot = 'assets';

  static const String addBankIcon = 'add_bank_icon';
  static const String addPanIcon = 'add_pan_icon';
  static const String linkPanAadhaarIcon = 'link_pan_aadhaar_icon';
  static const String addBankMiniBanner = 'add_bank_mini_banner';
  static const String addPanMiniBanner = 'add_pan_mini_banner';
  static const String panIdCardMiniBanner = 'pan_id_card_mini_banner';
  static const String collectViaCashIcon = 'collect_via_cash_icon';
  static const String collectViaQrIcon = 'collect_via_qr_icon';
  static const String qrLoadingState = 'qr_loading_state';
  static const String autoOtDetailsHeader = 'auto_ot_details_header';
  static const String downArrow = 'down_arrow';
  static const String newMingIcon = 'new_ming_icon';
  static const String newShiftTimingIcon = 'new_shift_timing_icon';
  static const String otAssignmentFailureIcon = 'ot_assignment_failure_icon';
  static const String otAssignmentSuccessIcon = 'ot_assignment_success_icon';
  static const String otShiftTimingIcon = 'ot_shift_timing_icon';
  static const String regularShiftTimingIcon = 'regular_shift_timing_icon';
  static const String doNotDenyJobs = 'do_not_deny_jobs';
  static const String logOutOnTime = 'log_out_on_time';
  static const String loginOnTime = 'login_on_time';
  static const String autoOtLastStepBg = 'auto_ot_last_step_bg';

  //? Sunday Attendance Nudge Asset Keys
  static const String sundayAttendanceNudgePlayAudio =
      'sunday_attendance_nudge_play_audio';
  static const String sundayAttendanceBonus = 'sunday_bonus';
  static const String sundayAttendanceExtraIncome = 'sunday_extra_income';
  static const String sundayAttendanceMing = 'sunday_ming';
  static const String sundayAttendanceNudgeTopBanner =
      'sunday_nudge_top_banner';
  static const String sundayAttendanceNudgeBaseAudioPath =
      'sunday_attendance_nudge_base_audio_path';
  static const String jobRejectionWarningImage = 'job_rejection_warning_image';
  static const String jobRejectionWarningStatusYellow =
      'job_rejection_warning_status_yellow';
  static const String jobRejectionWarningStatusGreen =
      'job_rejection_warning_status_green';
  static const String jobRejectionWarningStatusRed =
      'job_rejection_warning_status_red';
  static const String deallocationFirstWarningHeader =
      'deallocation_first_warning_header';
  static const String deallocationFirstWarningItem =
      'deallocation_first_warning_item';
  static const String checkInPhoneNumberError = 'check_in_phone_number_error';
  static const String checkInLocationError = 'check_in_location_error';
  //? Referral Short shift
  static const String referralShortShiftWhoToRefer =
      'referral_short_shift_who_to_refer_';
  static const String referralShortShiftTimings =
      'referral_short_shift_timings';
  static const String referralShortShiftDurations =
      'referral_short_shift_durations';
  static const String referralShortShiftIncome = 'referral_short_shift_income';
  static const String referralShortShiftBenefitsAudio =
      'referral_short_shift_benefits_audio';
  static const String referralInformOnWhatsapp = 'referral_inform_on_whatsapp';
  static const String referAndEarnV2Banner = 'refer_and_earn_v2_banner';

  //? AWOL Asset Keys
  static const String awolEnterHotspot = 'awol_enter_hotspot';
  static const String awolBackInHotspot = 'awol_back_in_hotspot';

  //? Lunch Asset Keys
  static const String lunchBanner = 'lunch_banner';

  //? Tiering Asset Keys
  static const String goldTier = 'gold_tier';
  static const String silverTier = 'silver_tier';
  static const String diamondTier = 'diamond_tier';
  static const String pinkDiamondTier = 'pink_diamond_tier';
  static const String tierCoin = 'tier_coin';
  static const String tierJob = 'tier_job';
  // Base tier (renamed from BASIC); RC key + CDN path kept as `basic_tier`.
  static const String baseTier = 'basic_tier';
  static const String udaanBannerHeaderImage = 'udaan_banner_header_image';
  static const String drawerMenuBasicPinkDiamondBg =
      'drawer_menu_basic_pink_diamond_bg';
  static const String drawerMenuDiamondTierBg = 'drawer_menu_diamond_tier_bg';
  static const String drawerMenuGoldTierBg = 'drawer_menu_gold_tier_bg';
  static const String drawerMenuSilverTierBg = 'drawer_menu_silver_tier_bg';
  static const String drawerMenuBasicTierBg = 'drawer_menu_basic_tier_bg';

  //? Tiering Nudge Image Keys
  static const String genericSeeBenefits = 'generic_see_benefits';
  static const String genericMissedWeek = 'generic_missed_week';
  static const String genericCoinSummary = 'generic_coin_summary';
  static const String genericTierSummary = 'generic_tier_summary';
  static const String motivationRank = 'motivation_rank';
  static const String benefitMerch = 'benefit_merch';
  static const String benefitRedCardWaiver = 'benefit_red_card_waiver';
  static const String benefitBirthday = 'benefit_birthday';
  static const String benefitVouchers = 'benefit_vouchers';
  static const String benefitCustomerPriority = 'benefit_customer_priority';
  static const String benefitLunch = 'benefit_lunch';
  static const String benefitPromotion = 'benefit_promotion';
  static const String benefitBasePay = 'benefit_base_pay';
  static const String benefitMinG = 'benefit_min_g';
  static const String benefitEarlyPayout = 'benefit_early_payout';
  static const String benefitAccidental = 'benefit_accidental';
  static const String benefitLoan = 'benefit_loan';
  static const String benefitSeva = 'benefit_seva';
  static const String benefitHealthInsurance = 'benefit_health_insurance';
}

class RemoteConfigAssets {
  static String _helper(String key, String value) {
    try {
      final remoteConfig = RemoteConfigService.instance;
      final json = remoteConfig.getJson(RemoteConfigAssetKeys.assetsRoot);
      return json?[key] ?? value;
    } catch (_) {
      return value;
    }
  }

  static String get referAndEarnV2Banner {
    return _helper(
      RemoteConfigAssetKeys.referAndEarnV2Banner,
      "referral/referral_header/refer_and_earn_v2_banner.png",
    ).cdn;
  }

  static String get collectViaCashIcon {
    return _helper(
      RemoteConfigAssetKeys.collectViaCashIcon,
      "payouts/cash_or_qr_payment/collect_via_cash.svg",
    ).cdn;
  }

  static String get collectViaQrIcon {
    return _helper(
      RemoteConfigAssetKeys.collectViaQrIcon,
      "payouts/cash_or_qr_payment/collect_via_qr.svg",
    ).cdn;
  }

  static String get qrLoadingState {
    return _helper(
      RemoteConfigAssetKeys.qrLoadingState,
      "payouts/cash_or_qr_payment/qr_loading_state.png",
    ).cdn;
  }

  static String get addBankIcon {
    return _helper(
      RemoteConfigAssetKeys.addBankIcon,
      "payouts/bank_and_pan/add_bank_icon.png",
    ).cdn;
  }

  static String get addPanIcon {
    return _helper(
      RemoteConfigAssetKeys.addPanIcon,
      "payouts/bank_and_pan/add_pan_icon.png",
    ).cdn;
  }

  static String get linkPanAadhaarIcon {
    return _helper(
      RemoteConfigAssetKeys.linkPanAadhaarIcon,
      "payouts/bank_and_pan/link_pan_aadhaar.png",
    ).cdn;
  }

  static String get addBankMiniBanner {
    return _helper(
      RemoteConfigAssetKeys.addBankMiniBanner,
      "payouts/bank_and_pan/add_bank_mini_banner.png",
    ).cdn;
  }

  static String get addPanMiniBanner {
    return _helper(
      RemoteConfigAssetKeys.addPanMiniBanner,
      "payouts/bank_and_pan/add_pan_mini_banner.png",
    ).cdn;
  }

  static String get panIdCardMiniBanner {
    return _helper(
      RemoteConfigAssetKeys.panIdCardMiniBanner,
      "payouts/bank_and_pan/pan_id_icon.svg",
    ).cdn;
  }

  //in auto_ot directory
  static String get autoOtDetailsHeader {
    return _helper(
      RemoteConfigAssetKeys.autoOtDetailsHeader,
      "auto_ot/auto_ot_details_header.png",
    ).cdn;
  }

  static String get downArrow {
    return _helper(
      RemoteConfigAssetKeys.downArrow,
      "auto_ot/down_arrow.png",
    ).cdn;
  }

  static String get newMingIcon {
    return _helper(
      RemoteConfigAssetKeys.newMingIcon,
      "auto_ot/new_ming_icon.png",
    ).cdn;
  }

  static String get newShiftTimingIcon {
    return _helper(
      RemoteConfigAssetKeys.newShiftTimingIcon,
      "auto_ot/new_shift_timing_icon.png",
    ).cdn;
  }

  static String get otAssignmentFailureIcon {
    return _helper(
      RemoteConfigAssetKeys.otAssignmentFailureIcon,
      "auto_ot/ot_assignment_failure_icon.png",
    ).cdn;
  }

  static String get otAssignmentSuccessIcon {
    return _helper(
      RemoteConfigAssetKeys.otAssignmentSuccessIcon,
      "auto_ot/ot_assignment_success_icon.png",
    ).cdn;
  }

  static String get otShiftTimingIcon {
    return _helper(
      RemoteConfigAssetKeys.otShiftTimingIcon,
      "auto_ot/ot_shift_timing_icon.png",
    ).cdn;
  }

  static String get regularShiftTimingIcon {
    return _helper(
      RemoteConfigAssetKeys.regularShiftTimingIcon,
      "auto_ot/regular_shift_timing_icon.png",
    ).cdn;
  }

  static String get doNotDenyJobs {
    return _helper(
      RemoteConfigAssetKeys.doNotDenyJobs,
      "auto_ot/do_not_deny_jobs.png",
    ).cdn;
  }

  static String get logOutOnTime {
    return _helper(
      RemoteConfigAssetKeys.logOutOnTime,
      "auto_ot/log_out_on_time.png",
    ).cdn;
  }

  static String get loginOnTime {
    return _helper(
      RemoteConfigAssetKeys.loginOnTime,
      "auto_ot/login_on_time.png",
    ).cdn;
  }

  static String get autoOtLastStepBg {
    return _helper(
      RemoteConfigAssetKeys.autoOtLastStepBg,
      "auto_ot/auto_ot_last_step_bg.png",
    ).cdn;
  }

  //? Sunday Attendance Nudge Assets
  static String get sundayAttendanceNudgePlayAudio {
    return _helper(
      RemoteConfigAssetKeys.sundayAttendanceNudgePlayAudio,
      "sunday_nudge/images/play_audio.svg",
    ).cdn;
  }

  static String get sundayAttendanceNudgeTopBanner {
    return _helper(
      RemoteConfigAssetKeys.sundayAttendanceNudgeTopBanner,
      "sunday_nudge/images/sunday_nudge_top_banner.png",
    ).cdn;
  }

  static String get sundayAttendanceNudgeBonus {
    return _helper(
      RemoteConfigAssetKeys.sundayAttendanceBonus,
      "sunday_nudge/images/sunday_bonus.png",
    ).cdn;
  }

  static String get sundayAttendanceExtraIncome {
    return _helper(
      RemoteConfigAssetKeys.sundayAttendanceExtraIncome,
      "sunday_nudge/images/sunday_extra_income.png",
    ).cdn;
  }

  static String get sundayAttendanceMing {
    return _helper(
      RemoteConfigAssetKeys.sundayAttendanceMing,
      "sunday_nudge/images/sunday_ming.png",
    ).cdn;
  }

  static String get sundayAttendanceNudgeBaseAudioPath {
    return _helper(
      RemoteConfigAssetKeys.sundayAttendanceNudgeBaseAudioPath,
      "sunday_nudge/audios/sunday_attendance_{{language_code}}.mp3",
    ).cdn;
  }

  static String get jobRejectionWarningImage {
    return _helper(
      RemoteConfigAssetKeys.jobRejectionWarningImage,
      "job_flow/job_acceptance/job_rejection_warning.png",
    ).cdn;
  }

  static String get jobRejectionWarningStatusRed {
    return _helper(
      RemoteConfigAssetKeys.jobRejectionWarningStatusRed,
      "job_flow/job_acceptance/warning_red.svg",
    ).cdn;
  }

  static String get jobRejectionWarningStatusGreen {
    return _helper(
      RemoteConfigAssetKeys.jobRejectionWarningStatusGreen,
      "job_flow/job_acceptance/warning_green.svg",
    ).cdn;
  }

  static String get jobRejectionWarningStatusYellow {
    return _helper(
      RemoteConfigAssetKeys.jobRejectionWarningStatusYellow,
      "job_flow/job_acceptance/warning_yellow.svg",
    ).cdn;
  }

  static String get deallocationFirstWarningHeader {
    return _helper(
      RemoteConfigAssetKeys.deallocationFirstWarningHeader,
      "job_flow/job_acceptance/deallocation_first_warning_header.svg",
    ).cdn;
  }

  static String get deallocationFirstWarningItem1 {
    return _helper(
      "${RemoteConfigAssetKeys.deallocationFirstWarningItem}1",
      "job_flow/job_acceptance/deallocation_first_warning_item_1.png",
    ).cdn;
  }

  static String get deallocationFirstWarningItem2 {
    return _helper(
      "${RemoteConfigAssetKeys.deallocationFirstWarningItem}2",
      "job_flow/job_acceptance/deallocation_first_warning_item_2.png",
    ).cdn;
  }

  static String get referralShortShiftWhoToRefer1 {
    return _helper(
      '${RemoteConfigAssetKeys.referralShortShiftWhoToRefer}1',
      "referral/short_shift/who_to_refer_1.png",
    ).cdn;
  }

  static String get referralShortShiftWhoToRefer2 {
    return _helper(
      '${RemoteConfigAssetKeys.referralShortShiftWhoToRefer}2',
      "referral/short_shift/who_to_refer_2.png",
    ).cdn;
  }

  static String get referralShortShiftWhoToRefer3 {
    return _helper(
      '${RemoteConfigAssetKeys.referralShortShiftWhoToRefer}3',
      "referral/short_shift/who_to_refer_3.png",
    ).cdn;
  }

  static String get referralShortShiftTimings {
    return _helper(
      RemoteConfigAssetKeys.referralShortShiftTimings,
      "referral/short_shift/shift_timings.png",
    ).cdn;
  }

  static String get referralShortShiftDurations {
    return _helper(
      RemoteConfigAssetKeys.referralShortShiftDurations,
      "referral/short_shift/shift_durations.png",
    ).cdn;
  }

  static String get referralShortShiftIncome {
    return _helper(
      RemoteConfigAssetKeys.referralShortShiftIncome,
      "referral/short_shift/shift_income.png",
    ).cdn;
  }

  static String get referralShortShiftBenefitsAudio {
    return _helper(
      RemoteConfigAssetKeys.referralShortShiftIncome,
      "referral/short_shift/audios/part_time_referral_{{language_code}}.mp3",
    ).cdn;
  }

  static String get referralInformOnWhatsapp {
    return _helper(
      RemoteConfigAssetKeys.referralInformOnWhatsapp,
      "referral/referral_header/whatsapp_icon.svg",
    ).cdn;
  }

  //? AWOL Assets
  static String get awolEnterHotspot {
    return _helper(
      RemoteConfigAssetKeys.awolEnterHotspot,
      "awol/enter_hotspot.jpg",
    ).cdn;
  }

  static String get awolBackInHotspot {
    return _helper(
      RemoteConfigAssetKeys.awolBackInHotspot,
      "awol/back_in_hotspot.png",
    ).cdn;
  }

  static String get checkInLocationError {
    return _helper(
      RemoteConfigAssetKeys.checkInLocationError,
      "job_flow/job_acceptance/check_in_location_error.svg",
    ).cdn;
  }

  static String get checkInPhoneNumberError {
    return _helper(
      RemoteConfigAssetKeys.checkInPhoneNumberError,
      "job_flow/job_acceptance/check_in_phone_number_error.svg",
    ).cdn;
  }

  //? Lunch Assets
  /// Leading illustration on the Home lunch-slots banner.
  static String get lunchBanner {
    return _helper(
      RemoteConfigAssetKeys.lunchBanner,
      "banner/lunch_cph.webp",
    ).cdn;
  }

  //? Tiering Assets
  static String get goldTier {
    return _helper(
      RemoteConfigAssetKeys.goldTier,
      "tiering/gold_tier.png",
    ).cdn;
  }

  static String get silverTier {
    return _helper(
      RemoteConfigAssetKeys.silverTier,
      "tiering/silver_tier.png",
    ).cdn;
  }

  static String get diamondTier {
    return _helper(
      RemoteConfigAssetKeys.diamondTier,
      "tiering/diamond_tier.png",
    ).cdn;
  }

  static String get pinkDiamondTier {
    return _helper(
      RemoteConfigAssetKeys.pinkDiamondTier,
      "tiering/pink_diamond_tier.png",
    ).cdn;
  }

  static String get tierCoin {
    return _helper(
      RemoteConfigAssetKeys.tierCoin,
      "tiering/coin.png",
    ).cdn;
  }

  static String get tierJob {
    return _helper(
      RemoteConfigAssetKeys.tierJob,
      "tiering/job.png",
    ).cdn;
  }

  static String get baseTier {
    return _helper(
      RemoteConfigAssetKeys.baseTier,
      "tiering/basic_tier.png",
    ).cdn;
  }

  static String get udaanBannerHeaderImage {
    return _helper(
      RemoteConfigAssetKeys.udaanBannerHeaderImage,
      "tiering/udaan_banner_header_image.png",
    ).cdn;
  }

  static String get drawerMenuBasicPinkDiamondBg {
    return _helper(
      RemoteConfigAssetKeys.drawerMenuBasicPinkDiamondBg,
      "tiering/drawer_menu_basic_pink_diamond_bg.png",
    ).cdn;
  }

  static String get drawerMenuDiamondTierBg {
    return _helper(
      RemoteConfigAssetKeys.drawerMenuDiamondTierBg,
      "tiering/drawer_menu_diamond_tier_bg.png",
    ).cdn;
  }

  static String get drawerMenuGoldTierBg {
    return _helper(
      RemoteConfigAssetKeys.drawerMenuGoldTierBg,
      "tiering/drawer_menu_gold_tier_bg.png",
    ).cdn;
  }

  static String get drawerMenuSilverTierBg {
    return _helper(
      RemoteConfigAssetKeys.drawerMenuSilverTierBg,
      "tiering/drawer_menu_silver_tier_bg.png",
    ).cdn;
  }

  static String get drawerMenuBasicTierBg {
    return _helper(
      RemoteConfigAssetKeys.drawerMenuBasicTierBg,
      "tiering/drawer_menu_basic_tier_bg.png",
    ).cdn;
  }

  //? Tiering Nudge Images
  static String get genericSeeBenefits {
    return _helper(
      RemoteConfigAssetKeys.genericSeeBenefits,
      "tiering/generic_see_benefits.svg",
    ).cdn;
  }

  static String get genericMissedWeek {
    return _helper(
      RemoteConfigAssetKeys.genericMissedWeek,
      "tiering/generic_missed_week.svg",
    ).cdn;
  }

  static String get genericCoinSummary {
    return _helper(
      RemoteConfigAssetKeys.genericCoinSummary,
      "tiering/generic_coin_summary.svg",
    ).cdn;
  }

  static String get genericTierSummary {
    return _helper(
      RemoteConfigAssetKeys.genericTierSummary,
      "tiering/generic_tier_summary.svg",
    ).cdn;
  }

  static String get motivationRank {
    return _helper(
      RemoteConfigAssetKeys.motivationRank,
      "tiering/motivation_rank.svg",
    ).cdn;
  }

  static String get benefitMerch {
    return _helper(
      RemoteConfigAssetKeys.benefitMerch,
      "tiering/benefit_merch.svg",
    ).cdn;
  }

  static String get benefitRedCardWaiver {
    return _helper(
      RemoteConfigAssetKeys.benefitRedCardWaiver,
      "tiering/benefit_red_card_waiver.svg",
    ).cdn;
  }

  static String get benefitBirthday {
    return _helper(
      RemoteConfigAssetKeys.benefitBirthday,
      "tiering/benefit_birthday.svg",
    ).cdn;
  }

  static String get benefitVouchers {
    return _helper(
      RemoteConfigAssetKeys.benefitVouchers,
      "tiering/benefit_vouchers.svg",
    ).cdn;
  }

  static String get benefitCustomerPriority {
    return _helper(
      RemoteConfigAssetKeys.benefitCustomerPriority,
      "tiering/benefit_customer_priority.svg",
    ).cdn;
  }

  static String get benefitLunch {
    return _helper(
      RemoteConfigAssetKeys.benefitLunch,
      "tiering/benefit_lunch.svg",
    ).cdn;
  }

  static String get benefitPromotion {
    return _helper(
      RemoteConfigAssetKeys.benefitPromotion,
      "tiering/benefit_promotion.svg",
    ).cdn;
  }

  static String get benefitBasePay {
    return _helper(
      RemoteConfigAssetKeys.benefitBasePay,
      "tiering/benefit_base_pay.svg",
    ).cdn;
  }

  static String get benefitMinG {
    return _helper(
      RemoteConfigAssetKeys.benefitMinG,
      "tiering/benefit_min_g.svg",
    ).cdn;
  }

  static String get benefitEarlyPayout {
    return _helper(
      RemoteConfigAssetKeys.benefitEarlyPayout,
      "tiering/benefit_early_payout.svg",
    ).cdn;
  }

  static String get benefitAccidental {
    return _helper(
      RemoteConfigAssetKeys.benefitAccidental,
      "tiering/benefit_accidental.svg",
    ).cdn;
  }

  static String get benefitLoan {
    return _helper(
      RemoteConfigAssetKeys.benefitLoan,
      "tiering/benefit_loan.svg",
    ).cdn;
  }

  static String get benefitSeva {
    return _helper(
      RemoteConfigAssetKeys.benefitSeva,
      "tiering/benefit_seva.svg",
    ).cdn;
  }

  static String get benefitHealthInsurance {
    return _helper(
      RemoteConfigAssetKeys.benefitHealthInsurance,
      "tiering/benefit_health_insurance.svg",
    ).cdn;
  }
}
