import 'package:snabbit_runner/pages/go_live/tnc_accept.dart';
import 'package:snabbit_runner/pages/login/select_language_v2.dart';
import 'package:snabbit_runner/pages/partner_home.dart';
import 'package:snabbit_runner/pages/signup/availability_details.dart';
import 'package:snabbit_runner/pages/signup/availability_details_2.dart';
import 'package:snabbit_runner/pages/signup/bank_details.dart';
import 'package:snabbit_runner/pages/signup/customer_service.dart';
import 'package:snabbit_runner/pages/signup/family_details/family_details.dart';
import 'package:snabbit_runner/pages/signup/insurance/children_details.dart';
import 'package:snabbit_runner/pages/signup/insurance_details.dart';
import 'package:snabbit_runner/pages/signup/integrity_test.dart';
import 'package:snabbit_runner/pages/signup/onboarding_screen.dart';
import 'package:snabbit_runner/pages/signup/personal_details.dart';
import 'package:snabbit_runner/pages/signup/prior_experience.dart';
import 'package:snabbit_runner/pages/signup/registration_code_v2.dart';
import 'package:snabbit_runner/pages/signup/select_service.dart';
import 'package:snabbit_runner/pages/signup/review/registration_review.dart';
import 'package:snabbit_runner/pages/signup/upload_documents_pan.dart';
import 'package:snabbit_runner/pages/signup/work_experience.dart';
import 'package:snabbit_runner/pages/verification_display.dart';

import '../pages/signup/upload_documents.dart';

class RunnerRegistrationStep {
  RunnerRegistrationStep._();

  static const String startRegistration = "START_REGISTRATION";
  static const String registrationCode = "REGISTRATION_CODE";
  static const String personal = "PERSONAL";
  static const String family = "FAMILY";
  static const String priorExp = "PRIOR_EXP";
  static const String kycAadhar = "KYC_DOCUMENTS_AADHAR";
  static const String kycPan = "KYC_DOCUMENTS_PAN";
  static const String bank = "BANK";
  static const String insurance = "INSURANCE";
  static const String availability = "AVAILABILITY";
  static const String ability = "ABILITY";
  static const String customerService = "CUSTOMER_SERVICE";
  static const String integrityTest = "INTEGRITY_TEST";
  static const String pendingVerification = "PENDING_VERIFICATION";
  static const String workExperience = "WORK_EXPERIENCE";
  static const String availability2 = "AVAILABILITY_2";
  static const String review = "REVIEW";
  static const String childrenDetails = "CHILDREN_DETAILS";
  static const String onboardingV2 = "ONBOARDING";
  static const String preRegistration = "PRE_REGISTRATION";
  static const String citySelection = "CITY_SELECTION";
  static const String serviceSelection = "SERVICE_SELECTION";
  static const String termsAndConditions = "TERMS_AND_CONDITIONS";

  /// Opero onboarding module key — opens registration form webview.
  static const String earlyRegistrationModuleKey = 'early_registration';

  static const Set<String> stepsRequiringReset = {
    serviceSelection,
    termsAndConditions,
    registrationCode,
  };

  static bool requiresResetBeforeOpen(String? rawStep) =>
      rawStep != null && stepsRequiringReset.contains(rawStep);

  static String? getStepRouteName(String step) {
    switch (step) {
      case startRegistration:
        return SelectLanguageV2.routeName;
      case serviceSelection:
        return SelectService.routeName;
      case registrationCode:
        return RegistrationCodeV2.routeName;
      case personal:
        return PersonalDetails.routeName;
      case family:
        return FamilyDetails.routeName;
      case priorExp:
        return PriorExperience.routeName;
      case kycAadhar:
        return UploadDocuments.routeName;
      case kycPan:
        return UploadDocumentsPan.routeName;
      case bank:
        return BankDetails.routeName;
      case insurance:
        return InsuranceDetails.routeName;
      case availability:
        return AvailabilityDetails.routeName;
      // case ability:
      //   return "Assess your ability for the job.";
      case customerService:
        return CustomerService.routeName;
      case integrityTest:
        return IntegrityTestWidget.routeName;
      case pendingVerification:
        return PartnerHome.routeName;
      case availability2:
        return AvailabilityDetails2.routeName;
      case workExperience:
        return WorkExperience.routeName;
      case review:
        return RegistrationReview.routeName;
      case childrenDetails:
        return ChildrenDetails.routeName;
      case termsAndConditions:
        return TncAcceptPage.routeName;
      case onboardingV2:
      case preRegistration:
        return OnboardingScreen.routeName;
      case citySelection:
        // Webview opened via [RegistrationNavigation] using [rawStep].
        return null;
      default:
        return null;
    }
  }
}
