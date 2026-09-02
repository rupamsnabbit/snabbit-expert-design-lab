// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:snabbit_runner/constants/assets_constants.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/colors.dart';

enum MaritalStatus {
  //TODO
  married,
  unmarried,
  divorced,
  widow
}

enum Gender {
  MALE,
  FEMALE;

  String? toJson() {
    return this == Gender.MALE
        ? 'M'
        : this == Gender.FEMALE
            ? 'F'
            : null;
  }
}

enum DocumentType {
  PAN,
  AADHAR,
}

Gender? getGenderFromString(String? genderString) {
  switch (genderString) {
    case 'M':
      return Gender.MALE;
    case 'F':
      return Gender.FEMALE;
    default:
      return null; // or throw an error if you prefer
  }
}

MaritalStatus? getMaritalStatusFromString(String? maritalStatusString) {
  switch (maritalStatusString) {
    case 'married':
      return MaritalStatus.married;
    case 'unmarried':
      return MaritalStatus.unmarried;
    case 'divorced':
      return MaritalStatus.divorced;
    case 'widow':
      return MaritalStatus.widow;
    default:
      return null; // or throw an error if you prefer
  }
}

DocumentType? getDocTypeFromString(String? docTypeString) {
  switch (docTypeString) {
    case DocumentStrings.pan:
      return DocumentType.PAN;
    case DocumentStrings.aadhaar:
      return DocumentType.AADHAR;
    default:
      return null; // or throw an error if you prefer
  }
}

enum PriorJob {
  Maid,
  Nanny,
  Housekeeping,
  Hotel_Staff,
  Other,
  Homemaker,
}

String? getPriorJobString(PriorJob? priorJob) {
  if (priorJob == null) return null;
  return priorJob.name.toLowerCase();
}

PriorJob? getPriorJobFromString(String? priorJobString) {
  if (priorJobString == null) return null;
  switch (priorJobString.toLowerCase()) {
    case 'maid':
      return PriorJob.Maid;
    case 'nanny':
      return PriorJob.Nanny;
    case 'housekeeping':
      return PriorJob.Housekeeping;
    case 'hotel_staff':
      return PriorJob.Hotel_Staff;
    case 'other':
      return PriorJob.Other;
    case 'homemaker':
      return PriorJob.Homemaker;
    default:
      return null;
  }
}

enum PlanToUseSalary {
  Pay_off_loan,
  Children_education,
  Support_family,
  Run_house,
  Medical_needs,
  Savings,
  Discretionary,
  Not_sure,
}

String? getPlanToUseSalaryString(PlanToUseSalary? planToUseSalary) {
  if (planToUseSalary == null) return null;
  return planToUseSalary.name.toLowerCase();
}

PlanToUseSalary? getPlanToUseSalaryFromString(String? planToUseSalaryString) {
  if (planToUseSalaryString == null) return null;
  switch (planToUseSalaryString.toLowerCase()) {
    case 'pay_off_loan':
      return PlanToUseSalary.Pay_off_loan;
    case 'children_education':
      return PlanToUseSalary.Children_education;
    case 'support_family':
      return PlanToUseSalary.Support_family;
    case 'run_house':
      return PlanToUseSalary.Run_house;
    case 'medical_needs':
      return PlanToUseSalary.Medical_needs;
    case 'savings':
      return PlanToUseSalary.Savings;
    case 'discretionary':
      return PlanToUseSalary.Discretionary;
    case 'not_sure':
      return PlanToUseSalary.Not_sure;
    default:
      return null;
  }
}

enum Religion {
  Hindu,
  Muslim,
  Christian,
  Sikh,
  Other,
}

String? getReligionString(Religion? religion) {
  if (religion == null) return null;
  return religion.name.toLowerCase();
}

Religion? getReligionFromString(String? religionString) {
  if (religionString == null) return null;
  switch (religionString.toLowerCase()) {
    case 'hindu':
      return Religion.Hindu;
    case 'muslim':
      return Religion.Muslim;
    case 'christian':
      return Religion.Christian;
    case 'sikh':
      return Religion.Sikh;
    case 'other':
      return Religion.Other;
    default:
      return null; // or throw an error if you prefer
  }
}

enum Sect {
  Marathi,
  Gujarati,
  Bengali,
  Bihari,
  UP,
  Jain,
  Buddhist,
  Punjabi,
  Tamil,
  Telugu,
  Malayali,
  Kannada,
  Northestern,
  Oriya,
  AngloIndian,
  Other
}

Sect? getSectFromString(String? sectString) {
  switch (sectString) {
    case 'Marathi':
      return Sect.Marathi;
    case 'Gujarati':
      return Sect.Gujarati;
    case 'Bengali':
      return Sect.Bengali;
    case 'Bihari':
      return Sect.Bihari;
    case 'UP':
      return Sect.UP;
    case 'Jain':
      return Sect.Jain;
    case 'Buddhist':
      return Sect.Buddhist;
    case 'Punjabi':
      return Sect.Punjabi;
    case 'Tamil':
      return Sect.Tamil;
    case 'Telugu':
      return Sect.Telugu;
    case 'Malayali':
      return Sect.Malayali;
    case 'Kannada':
      return Sect.Kannada;
    case 'Northestern':
      return Sect.Northestern;
    case 'Oriya':
      return Sect.Oriya;
    case 'AngloIndian':
      return Sect.AngloIndian;
    case 'Other':
      return Sect.Other;
    default:
      return null;
  }
}

enum Education {
  Never_went_to_school,
  Attended_school,
  Passed_10th,
  Passed_12th,
  Graduate,
  Postgraduate,
}

Education? getEducationFromString(String? educationString) {
  switch (educationString) {
    case 'Never_went_to_school':
      return Education.Never_went_to_school;
    case 'Attended_school':
      return Education.Attended_school;
    case 'Passed_10th':
      return Education.Passed_10th;
    case 'Passed_12th':
      return Education.Passed_12th;
    case 'Graduate':
      return Education.Graduate;
    case 'Postgraduate':
      return Education.Postgraduate;
    default:
      return null; // or throw an error if you prefer
  }
}

enum ReadLevelLanguages {
  ENGLISH,
  HINDI,
  MARATHI,
  I_CAN_ONLY_READ_ADDRESSES_BUT_NOT_COMPLEX_INFORMATION,
  OTHER_LANGUAGES,
  CANNOT_READ,
}

ReadLevelLanguages? getReadLevelLanguagesFromString(String? rll) {
  switch (rll) {
    case 'ENGLISH':
      return ReadLevelLanguages.ENGLISH;
    case 'HINDI':
      return ReadLevelLanguages.HINDI;
    case 'MARATHI':
      return ReadLevelLanguages.MARATHI;
    case 'I_CAN_ONLY_READ_ADDRESSES_BUT_NOT_COMPLEX_INFORMATION':
      return ReadLevelLanguages
          .I_CAN_ONLY_READ_ADDRESSES_BUT_NOT_COMPLEX_INFORMATION;
    case 'OTHER_LANGUAGES':
      return ReadLevelLanguages.OTHER_LANGUAGES;
    case 'CANNOT_READ':
      return ReadLevelLanguages.CANNOT_READ;
    default:
      return null;
  }
}

enum PriorTasks {
  SWEEPING,
  MOPPING,
  CLEANING_BATHROOMS,
  LAUNDRY,
  WASHING_DISHES,
  CUTTING_VEGETABLES,
  COOKING,
  NONE_OF_THE_ABOVE,
}

extension PriorTasksExtension on PriorTasks {
  String get description {
    switch (this) {
      case PriorTasks.CUTTING_VEGETABLES:
        return "Cutting vegetables";
      case PriorTasks.SWEEPING:
        return "Sweeping";
      case PriorTasks.MOPPING:
        return "Mopping";
      case PriorTasks.CLEANING_BATHROOMS:
        return "Cleaning bathrooms";
      case PriorTasks.LAUNDRY:
        return "Laundry";
      case PriorTasks.WASHING_DISHES:
        return "Washing dishes";
      case PriorTasks.COOKING:
        return "Cooking";
      case PriorTasks.NONE_OF_THE_ABOVE:
        return "None of the above";
    }
  }
}

String? getPriorTasksString(PriorTasks? priorTasks) {
  if (priorTasks == null) return null;
  return priorTasks.name.toLowerCase();
}

PriorTasks? getPriorTasksFromString(String? task) {
  if (task == null) return null;
  switch (task.toLowerCase()) {
    case 'sweeping':
      return PriorTasks.SWEEPING;
    case 'mopping':
      return PriorTasks.MOPPING;
    case 'cleaning_bathrooms':
      return PriorTasks.CLEANING_BATHROOMS;
    case 'laundry':
      return PriorTasks.LAUNDRY;
    case 'washing_dishes':
      return PriorTasks.WASHING_DISHES;
    case 'cutting_vegetables':
      return PriorTasks.CUTTING_VEGETABLES;
    case 'cooking':
      return PriorTasks.COOKING;
    case 'none_of_the_above':
      return PriorTasks.NONE_OF_THE_ABOVE;
    default:
      return null;
  }
}

enum DocumentStatus {
  PENDING,
  SUCCESS,
  FAILED,
}

DocumentStatus? getDocumentStatusFromString(String? documentStatusString) {
  switch (documentStatusString) {
    case 'PENDING':
      return DocumentStatus.PENDING;
    case 'SUCCESS':
      return DocumentStatus.SUCCESS;
    case 'FAILED':
      return DocumentStatus.FAILED;
    default:
      return null;
  }
}

enum PetPreference {
  Not_Afraid,
  Dogs,
  Cats,
  Both_Dogs_And_Cats,
}

String? getPetPreferenceString(PetPreference? petPreference) {
  if (petPreference == null) return null;
  return petPreference.name.toLowerCase();
}

PetPreference? getPetPreferenceFromString(String? preferenceString) {
  if (preferenceString == null) return null;
  switch (preferenceString.toLowerCase()) {
    case 'not_afraid':
      return PetPreference.Not_Afraid;
    case 'dogs':
      return PetPreference.Dogs;
    case 'cats':
      return PetPreference.Cats;
    case 'both_dogs_and_cats':
      return PetPreference.Both_Dogs_And_Cats;
    default:
      return null;
  }
}

enum DietaryPreference {
  Strictly_Vegetarian,
  Non_Vegetarian,
}

String? getDietaryPreferenceString(DietaryPreference? dietaryPreference) {
  if (dietaryPreference == null) return null;
  return dietaryPreference.name.toLowerCase();
}

DietaryPreference? getDietaryPreferenceFromString(String? preferenceString) {
  if (preferenceString == null) return null;
  switch (preferenceString.toLowerCase()) {
    case 'strictly_vegetarian':
      return DietaryPreference.Strictly_Vegetarian;
    case 'non_vegetarian':
      return DietaryPreference.Non_Vegetarian;
    default:
      return null;
  }
}

extension DietaryPreferenceExtension on DietaryPreference {
  String get description {
    switch (this) {
      case DietaryPreference.Strictly_Vegetarian:
        return "Vegetarian";
      case DietaryPreference.Non_Vegetarian:
        return "Non-Vegetarian";
    }
  }
}

// enum LanguagePreferenceType {
//   english("ENGLISH"),
//   hindi("HINDI"),
//   marathi("MARATHI");
//
//   final String value;
//
//   const LanguagePreferenceType(this.value);
//
//   static LanguagePreferenceType fromString(String? value) {
//     switch (value?.toUpperCase()) {
//       case "ENGLISH":
//         return LanguagePreferenceType.english;
//       case "HINDI":
//         return LanguagePreferenceType.hindi;
//       case "MARATHI":
//         return LanguagePreferenceType.marathi;
//       default:
//         return LanguagePreferenceType.english;
//     }
//   }
// }

// String getLanguageCodeFromLanguagePreferenceType(
//     LanguagePreferenceType languagePreferenceType) {
//   switch (languagePreferenceType) {
//     case LanguagePreferenceType.ENGLISH:
//       return 'en';
//     case LanguagePreferenceType.HINDI:
//       return 'hi';
//     case LanguagePreferenceType.MARATHI:
//       return 'mr';
//   }
// }

// LanguagePreferenceType? getLanguagePreferenceTypeFromString(
//     String? preferenceString) {
//   switch (preferenceString) {
//     case 'ENGLISH':
//       return LanguagePreferenceType.english;
//     case 'MARATHI':
//       return LanguagePreferenceType.marathi;
//     case 'HINDI':
//       return LanguagePreferenceType.hindi;
//     default:
//       return null; // or throw an error if you prefer
//   }
// }

enum RunnerState {
  CREATED,
  REGISTERED,
  ON_HOLD,
  TRAINING,
  FAILED,
  ACTIVE,
  SUSPENDED,
  BLOCKED;

  static RunnerState? fromString(String? preferenceString) {
    switch (preferenceString) {
      case 'CREATED':
        return RunnerState.CREATED;
      case 'REGISTERED':
        return RunnerState.REGISTERED;
      case 'ON_HOLD':
        return RunnerState.ON_HOLD;
      case 'TRAINING':
        return RunnerState.TRAINING;
      case 'FAILED':
        return RunnerState.FAILED;
      case 'ACTIVE':
        return RunnerState.ACTIVE;
      case 'SUSPENDED':
        return RunnerState.SUSPENDED;
      case 'BLOCKED':
        return RunnerState.BLOCKED;
      default:
        return null; // or throw an error if you prefer
    }
  }
}

enum PaymentState {
  pending,
  earned,
  missed,
  deducted;

  // Helper method to get PaymentState from string
  static PaymentState? fromString(String? state) {
    switch (state) {
      case 'PENDING':
        return PaymentState.pending;
      case 'EARNED':
        return PaymentState.earned;
      case 'FAILED':
        return PaymentState.missed;
      case 'DEDUCTED':
        return PaymentState.deducted;
      default:
        return null;
    }
  }
}

enum DeductionState {
  pending,
  success,
  failed;

  // Helper method to get DeductionState from string
  static DeductionState? fromString(String? state) {
    switch (state) {
      case 'PENDING':
        return DeductionState.pending;
      case 'SUCCESS':
        return DeductionState.success;
      case 'FAILED':
        return DeductionState.failed;
      default:
        return null;
    }
  }
}

enum AttendanceType { provisional, confirmation }

extension AttendanceTypeExtension on AttendanceType {
  String get type {
    switch (this) {
      case AttendanceType.provisional:
        return AttendanceType.provisional.name.toUpperCase();
      case AttendanceType.confirmation:
        return AttendanceType.confirmation.name.toUpperCase();
    }
  }
}

enum PayoutPeriod {
  /// Order is important for tabs to place in order
  monthly,
  daily,
}

extension PayoutPeriodExtension on PayoutPeriod {
  String get description {
    switch (this) {
      case PayoutPeriod.daily:
        return "Din ki";
      case PayoutPeriod.monthly:
        return "Mahine ki";
      default:
        return name;
    }
  }
}

enum DailyAttendanceStatus {
  present,
  absent,
  falseAttendance,
}

extension DailyAttendanceStatusExtension on DailyAttendanceStatus {
  String get description {
    switch (this) {
      case DailyAttendanceStatus.present:
        return "Present";
      case DailyAttendanceStatus.absent:
        return "Absent";
      case DailyAttendanceStatus.falseAttendance:
        return "False Attendance";
      default:
        return name;
    }
  }
}

DailyAttendanceStatus? getDailyAttendanceStatusFromString(
    String? dailyAttendanceStatusString) {
  switch (dailyAttendanceStatusString) {
    case 'PRESENT':
      return DailyAttendanceStatus.present;
    case 'ABSENT':
      return DailyAttendanceStatus.absent;
    case 'FP':
      return DailyAttendanceStatus.falseAttendance;
    default:
      return null; // or throw an error if you prefer
  }
}

enum ReferralStatus {
  pending,
  inProgress,
  completed,
  paid,
  failed,
  droppedOut,
  didNotJoin,
}

enum ContestStatus {
  active,
  upcoming,
  completed,
}

ContestStatus? getContestStatusFromString(String? contestStatusString) {
  switch (contestStatusString?.toLowerCase()) {
    case 'active':
      return ContestStatus.active;
    case 'upcoming':
      return ContestStatus.upcoming;
    case 'completed':
      return ContestStatus.completed;
    default:
      return null;
  }
}

ReferralStatus? getReferralStatusFromString(String? referralStatusString) {
  switch (referralStatusString) {
    case 'PENDING':
      return ReferralStatus.pending;
    case 'IN_PROGRESS':
      return ReferralStatus.inProgress;
    case 'COMPLETED':
      return ReferralStatus.completed;
    case 'PAID':
      return ReferralStatus.paid;
    case 'FAILED':
      return ReferralStatus.failed;
    case 'DROP_OUT':
      return ReferralStatus.droppedOut;
    case 'DID_NOT_JOIN':
      return ReferralStatus.didNotJoin;
    default:
      return null; // or throw an error if you prefer
  }
}

enum ReferralStepStatus {
  pending,
  inProgress,
  completed,
  failed,
}

ReferralStepStatus? getReferralStepStatusFromString(
    String? referralStepStatusString) {
  switch (referralStepStatusString) {
    case 'PENDING':
      return ReferralStepStatus.pending;
    case 'IN_PROGRESS':
      return ReferralStepStatus.inProgress;
    case 'COMPLETED':
      return ReferralStepStatus.completed;
    case 'FAILED':
      return ReferralStepStatus.failed;
    default:
      return null; // or throw an error if you prefer
  }
}

enum AttendanceStatus {
  PRESENT,
  ABSENT,
  FALSE_ATTENDANCE,
  FALSE_ATTENDANCE_WARNING,
  NO_SHOW,
  NO_SHOW_WARNING,
  EMERGENCY_LOGOUT
}

AttendanceStatus? getAttendanceStatusFromString(String? statusStr) {
  switch (statusStr) {
    case 'PRESENT':
      return AttendanceStatus.PRESENT;
    case 'ABSENT':
      return AttendanceStatus.ABSENT;
    case 'FALSE_ATTENDANCE':
      return AttendanceStatus.FALSE_ATTENDANCE;
    case 'FALSE_ATTENDANCE_WARNING':
      return AttendanceStatus.FALSE_ATTENDANCE_WARNING;
    case 'NO_SHOW':
      return AttendanceStatus.NO_SHOW;
    case 'NO_SHOW_WARNING':
      return AttendanceStatus.NO_SHOW_WARNING;
    case 'EMERGENCY_LOGOUT':
      return AttendanceStatus.EMERGENCY_LOGOUT;
    default:
      return null;
  }
}

enum Tier {
  // BASIC is legacy (sunset, like PRO/ELITE) — kept for the old tier system.
  // The new tiering system's base tier is BASE.
  BASIC,
  PRO,
  ELITE,
  BASE,
  SILVER,
  GOLD,
  DIAMOND,
  PINK_DIAMOND;

  static Tier? fromString(String? tierString) {
    switch (tierString?.toUpperCase()) {
      case 'BASIC':
        return Tier.BASIC;
      case 'PRO':
        return Tier.PRO;
      case 'ELITE':
        return Tier.ELITE;
      case 'BASE':
        return Tier.BASE;
      case 'SILVER':
        return Tier.SILVER;
      case 'GOLD':
        return Tier.GOLD;
      case 'DIAMOND':
        return Tier.DIAMOND;
      case 'PINK_DIAMOND':
        return Tier.PINK_DIAMOND;
      default:
        return null;
    }
  }

  String? getBackgroundImage() {
    switch (this) {
      case Tier.BASIC:
        return AssetConstants.basicTierBackground;
      case Tier.PRO:
        return AssetConstants.proTierBackground;
      case Tier.ELITE:
        return AssetConstants.eliteTierBackground;
      default:
        return null;
    }
  }

  String? get description {
    switch (this) {
      case Tier.BASIC:
        return "BASIC";
      case Tier.PRO:
        return "PRO";
      case Tier.ELITE:
        return "ELITE";
      default:
        return null;
    }
  }

  String? get normalizedDescription {
    switch (this) {
      case Tier.BASIC:
        return "Basic";
      case Tier.PRO:
        return "Pro";
      case Tier.ELITE:
        return "Elite";
      case Tier.BASE:
        return "Base";
      case Tier.SILVER:
        return "Silver";
      case Tier.GOLD:
        return "Gold";
      case Tier.DIAMOND:
        return "Diamond";
      case Tier.PINK_DIAMOND:
        return "Pink Diamond";
      default:
        return null;
    }
  }

  bool get isLegacyTier => this == Tier.BASIC ||
  this == Tier.PRO ||
  this == Tier.ELITE;
}

enum AlternateDeliveryMethod {
  foot,
  cycle,
  eCycle,
  yulu,
  motorcycle;

  static AlternateDeliveryMethod fromString(String? method) {
    switch (method?.toUpperCase()) {
      case 'FOOT':
        return AlternateDeliveryMethod.foot;
      case 'CYCLE':
        return AlternateDeliveryMethod.cycle;
      case 'ECYCLE':
        return AlternateDeliveryMethod.eCycle;
      case 'YULU':
        return AlternateDeliveryMethod.yulu;
      case 'MOTORCYCLE':
        return AlternateDeliveryMethod.motorcycle;
      default:
        return AlternateDeliveryMethod.foot;
    }
  }

  String getAsset() {
    switch (this) {
      case AlternateDeliveryMethod.foot:
        return AssetConstants.walking;
      case AlternateDeliveryMethod.cycle:
      case AlternateDeliveryMethod.eCycle:
      case AlternateDeliveryMethod.yulu:
      case AlternateDeliveryMethod.motorcycle:
        return AssetConstants.electricMotor;
      default:
        return AssetConstants.walking;
    }
  }
}

enum ServerError { MAX_CUSTOMERS_BLOCKED }

enum WorkSchedule {
  weekendOnly(
    originalText: 'Weekend only',
    key: 'weekend_only',
  ),
  everyday(
    originalText: 'Everyday',
    key: 'everyday',
  );

  // This property stores the original string value.
  final String originalText;
  final String key;

  const WorkSchedule({
    required this.originalText,
    required this.key,
  });

  // A factory constructor to create an enum from a string.
  static WorkSchedule? fromString(String? text) {
    for (var schedule in WorkSchedule.values) {
      if (schedule.key.toUpperCase() == text?.toUpperCase()) {
        return schedule;
      }
    }
    return null;
  }
}

enum VerificationStatus {
  verified,
  unverified,
  detailsMissing;

  static VerificationStatus? fromString(String? tierString) {
    switch (tierString?.toLowerCase()) {
      case 'verified':
        return VerificationStatus.verified;
      case 'unverified':
        return VerificationStatus.unverified;
      case 'details_missing':
        return VerificationStatus.detailsMissing;
      default:
        return null;
    }
  }

  String get label {
    switch (this) {
      case VerificationStatus.verified:
        return 'Verified';
      case VerificationStatus.unverified:
        return 'Unverified';
      case VerificationStatus.detailsMissing:
        return 'Details Missing';
    }
  }

  Color get labelColor {
    switch (this) {
      case VerificationStatus.verified:
        return AppColors.g50;
      case VerificationStatus.unverified:
        return AppColors.n60;
      case VerificationStatus.detailsMissing:
        return AppColors.y50;
    }
  }

  Color get bgColor {
    switch (this) {
      case VerificationStatus.verified:
        return AppColors.g10;
      case VerificationStatus.unverified:
        return AppColors.n20;
      case VerificationStatus.detailsMissing:
        return AppColors.y10;
    }
  }
}

enum ExpiryType {
  date,
  days;

  static ExpiryType? fromString(String? text) {
    switch (text?.toLowerCase()) {
      case 'date':
        return ExpiryType.date;
      case 'days':
        return ExpiryType.days;
      default:
        return null;
    }
  }
}

enum LocationSyncFailureReason {
  locationPermissionMissing('LOCATION_PERMISSION_MISSING'),
  locationServiceDisabled('LOCATION_SERVICE_DISABLED'),
  locationStepFailed('LOCATION_STEP_FAILED'),
  unknown('UNKNOWN'),
  timeout('TIMEOUT'),
  dioException('DIO_EXCEPTION');

  const LocationSyncFailureReason(this.key);

  final String key;
}

enum OtType {
  EndOt,
  StartOt;

  String get key {
    switch (this) {
      case OtType.EndOt:
        return 'END_OT';
      case OtType.StartOt:
        return 'START_OT';
    }
  }

  static OtType fromKey(String key) {
    return OtType.values.firstWhere(
      (e) => e.key == key,
      orElse: () => OtType.EndOt,
    );
  }
}

enum DeallocationWarningType {
  goodShift('GOOD_SHIFT'),
  minG('MIN_G'),
  none('NONE');

  final String key;

  const DeallocationWarningType(this.key);

  static DeallocationWarningType fromKey(String key) {
    return DeallocationWarningType.values.firstWhere(
      (e) => e.key == key,
      orElse: () => DeallocationWarningType.none,
    );
  }
}

/// How shield recording was started.
enum ShieldTrigger {
  auto('auto'),
  manual('manual'),
  sos('sos');

  final String value;
  const ShieldTrigger(this.value);
}

/// Source that triggered an SOS alert (maps to API snake_case strings).
enum SosSource {
  ml('ml'),
  accelerometer('accelerometer'),
  volumeButton('volume_button'),
  notificationButton('notification_button'),
  manual('manual');

  final String apiValue;
  const SosSource(this.apiValue);
}

enum ReferralShiftType {
  shortShift(key: 'SHORT_SHIFT'),
  fullTime(key: 'FULL_TIME');

  final String key;

  const ReferralShiftType({
    required this.key,
  });

  static ReferralShiftType fromKey(String? key) {
    return ReferralShiftType.values.firstWhere(
      (e) => e.key == key,
      orElse: () => ReferralShiftType.fullTime,
    );
  }

  String displayText(LanguageProvider languageProvider) {
    switch (this) {
      case ReferralShiftType.shortShift:
        return languageProvider.getMessage(
          'part_time_referral',
          'Part-time Referral',
        );
      case ReferralShiftType.fullTime:
        return languageProvider.getMessage(
          'full_time_referral',
          'Full-time Referral',
        );
    }
  }
}

enum OtpServiceProvider {
  edumarc,
  otpless,
}
