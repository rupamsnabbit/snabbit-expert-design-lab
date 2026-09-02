import 'package:snabbit_runner/models/job_support/job_support_models.dart';
import 'package:snabbit_runner/models/issue_type_config.dart';
import 'package:snabbit_runner/services/otp_service.dart';
import 'package:snabbit_runner/utils/enums.dart';

class AppConfig {
  int? minAndroidVersion;
  int? skipAndroidVersion;
  String? appUpdateLink;
  int? expertNotMovingRepeatCount;
  List<String>? leaveReasons;
  List<String>? absenteeismReasons;
  List<String>? jobChangeReasons;
  List<String>? jobPreferredTimeChoices;
  List<String>? vehiclesUsed;
  List<String>? leaveCountChoices;
  List<String>? availabilityToWorkChoices;
  List<String>? spouseOccupationChoices;
  List<String>? maritalStatus;
  List<String>? priorJob;
  List<String>? planToUseSalary;
  List<String>? religion;
  // TODO: uncomment implement sect, education and readLevelLanguages if needed
  // List<String>? sect;
  // List<String>? education;
  // List<String>? readLevelLanguages;
  List<String>? priorTasks;
  List<String>? petPreference;
  List<String>? dietaryPreference;
  bool? isAadharEditable;
  bool? isPanEditable;
  int? refreshCooldown;
  bool? showSilentNotification;
  String? eBikeTrainingLink;
  List<String>? nomineesRelations;
  Map<String, dynamic>? criticalFields;
  List<int>? invalidVersionCodes;
  Map<String, dynamic>? docText;
  List<String>? issueTypes;
  bool? useNavPadding;
  List<WorkSchedule>? workSchedules;
  List<int>? weekendWorkHours;
  List<int>? regularWorkHours;
  List<IssueTypeConfig>? issueTypeConfigs;
  bool? showVpnWarning;
  bool? overrideFirebaseRCShutdown;
  List<String>? blockedAutoOTWidgets;
  List<String>? blockedShieldConsentWidgets;
  OtpServiceProvider otpServiceProvider;
  List<OtplessConfig>? otplessApplicableChannels;
  JobSupportConfig? jobSupportConfig;

  AppConfig({
    this.minAndroidVersion,
    this.skipAndroidVersion,
    this.appUpdateLink,
    this.expertNotMovingRepeatCount,
    this.leaveReasons,
    this.absenteeismReasons,
    this.jobChangeReasons,
    this.jobPreferredTimeChoices,
    this.vehiclesUsed,
    this.leaveCountChoices,
    this.availabilityToWorkChoices,
    this.spouseOccupationChoices,
    this.maritalStatus,
    this.priorJob,
    this.planToUseSalary,
    this.religion,
    // this.sect,
    // this.education,
    // this.readLevelLanguages,
    this.priorTasks,
    this.petPreference,
    this.dietaryPreference,
    this.isAadharEditable,
    this.isPanEditable,
    this.refreshCooldown,
    this.showSilentNotification,
    this.eBikeTrainingLink,
    this.nomineesRelations,
    this.criticalFields,
    this.invalidVersionCodes,
    this.docText,
    this.issueTypes,
    this.useNavPadding,
    this.workSchedules,
    this.weekendWorkHours,
    this.regularWorkHours,
    this.issueTypeConfigs,
    this.showVpnWarning,
    this.overrideFirebaseRCShutdown,
    this.blockedAutoOTWidgets,
    this.blockedShieldConsentWidgets,
    this.otpServiceProvider = OtpServiceProvider.edumarc,
    this.otplessApplicableChannels,
    this.jobSupportConfig,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      minAndroidVersion: json['min_android_version'],
      skipAndroidVersion: json['skip_android_version'],
      appUpdateLink: json['app_update_link'],
      leaveReasons: List<String>.from(json['leave_reasons']),
      absenteeismReasons: List<String>.from(json['absenteeism_reasons']),
      jobChangeReasons: List<String>.from(json['job_change_reasons']),
      expertNotMovingRepeatCount: json['expert_not_moving_repeat_count'] ?? 1,
      jobPreferredTimeChoices: List<String>.from(json['job_preferred_time']),
      vehiclesUsed: List<String>.from(json['vehicles_used']),
      leaveCountChoices: List<String>.from(json['leave_count']),
      availabilityToWorkChoices:
          List<String>.from(json['availability_to_work']),
      spouseOccupationChoices: List<String>.from(json['spouse_occupation']),
      maritalStatus: List<String>.from(json['marital_status']),
      priorJob: List<String>.from(json['prior_job']),
      planToUseSalary: List<String>.from(json['plan_to_use_salary']),
      religion: List<String>.from(json['religion']),
      // sect: List<String>.from(json['sect']),
      // education: List<String>.from(json['education']),
      // readLevelLanguages: List<String>.from(json['read_level_languages']),
      priorTasks: List<String>.from(json['prior_tasks']),
      petPreference: List<String>.from(json['pet_preference']),
      dietaryPreference: List<String>.from(json['dietary_preference']),
      isAadharEditable: json['is_aadhar_editable'] ?? false,
      isPanEditable: json['is_pan_editable'] ?? false,
      refreshCooldown: json['refresh_cooldown'] ?? 10,
      showSilentNotification: json['show_silent_notification'],
      eBikeTrainingLink: json['ebike_training_link'],
      nomineesRelations: List<String>.from(json['nominees_relations_list']),
      criticalFields: json['critical_fields'],
      invalidVersionCodes: json['invalid_version_codes'] != null
          ? List<int>.from(json['invalid_version_codes'])
          : null,
      docText: json['doc_text'],
      issueTypes: json['issue_types'] != null
          ? List<String>.from(json['issue_types'])
          : null,
      useNavPadding: json['use_nav_padding'],
      workSchedules: json['work_schedule'] != null
          ? (json['work_schedule'] as List?)
              ?.map((x) => WorkSchedule.fromString(x))
              .whereType<WorkSchedule>()
              .toList()
          : null,
      weekendWorkHours: json['weekend_work_hours'] != null
          ? List<int>.from(json['weekend_work_hours'])
          : null,
      regularWorkHours: json['regular_work_hours'] != null
          ? List<int>.from(json['regular_work_hours'])
          : null,
      issueTypeConfigs: json['issue_type_configs'] != null
          ? (json['issue_type_configs'] as List<dynamic>)
              .map((config) => IssueTypeConfig.fromJson(config))
              .toList()
          : null,
      showVpnWarning: json['show_vpn_warning'],
      overrideFirebaseRCShutdown: json['override_firebase_rc_shutdown'],
      blockedAutoOTWidgets: json['blocked_auto_ot_widgets'] != null
          ? List<String>.from(json['blocked_auto_ot_widgets'])
          : null,
      blockedShieldConsentWidgets:
          json['blocked_shield_consent_widgets'] != null
              ? List<String>.from(json['blocked_shield_consent_widgets'])
              : null,
      otpServiceProvider: _parseOtpServiceProvider(json['otp_service_provider']),
      otplessApplicableChannels: (json['otpless_applicable_channels'] as List?)
          ?.map<OtplessConfig?>((e) => OtplessConfig.fromString(e.toString()))
          .whereType<OtplessConfig>()
          .toList(),
      jobSupportConfig: json['job_support'] is Map<String, dynamic>
          ? JobSupportConfig.fromJson(json['job_support'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min_android_version': minAndroidVersion,
      'skip_android_version': skipAndroidVersion,
      'leave_reasons': leaveReasons,
      'absenteeism_reasons': absenteeismReasons,
      'job_change_reasons': jobChangeReasons,
      'job_preferred_time': jobPreferredTimeChoices,
      'vehicles_used': vehiclesUsed,
      'leave_count': leaveCountChoices,
      'availability_to_work': availabilityToWorkChoices,
      'spouse_occupation': spouseOccupationChoices,
      'marital_status': maritalStatus,
      'prior_job': priorJob,
      'plan_to_use_salary': planToUseSalary,
      'religion': religion,
      // 'sect': sect,
      // 'education': education,
      // 'read_level_languages': readLevelLanguages,
      'prior_tasks': priorTasks,
      'pet_preference': petPreference,
      'dietary_preference': dietaryPreference,
      'nominees_relations_list': nomineesRelations,
      'critical_fields': criticalFields,
      'invalid_version_codes': invalidVersionCodes,
      'expert_not_moving_repeat_count': expertNotMovingRepeatCount,
    };
  }

  dynamic getCriticalField(String key) {
    return criticalFields?[key];
  }

  static OtpServiceProvider _parseOtpServiceProvider(dynamic value) {
    if (value == null) return OtpServiceProvider.edumarc;
    switch (value.toString().toLowerCase()) {
      case 'otpless':
        return OtpServiceProvider.otpless;
      case 'edumarc':
      default:
        return OtpServiceProvider.edumarc;
    }
  }
}
