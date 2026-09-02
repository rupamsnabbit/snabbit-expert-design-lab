import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/pages/login/select_language_v2.dart';
import 'package:snabbit_runner/pages/signup/onboarding_screen.dart';
import 'package:snabbit_runner/utils/runner_registration_step.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';

void main() {
  group('RunnerRegistrationStep.getStepRouteName', () {
    test('PRE_REGISTRATION maps to onboarding hub', () {
      expect(
        RunnerRegistrationStep.getStepRouteName(
          RunnerRegistrationStep.preRegistration,
        ),
        OnboardingScreen.routeName,
      );
    });

    test('ONBOARDING maps to onboarding hub', () {
      expect(
        RunnerRegistrationStep.getStepRouteName(
          RunnerRegistrationStep.onboardingV2,
        ),
        OnboardingScreen.routeName,
      );
    });

    test('CITY_SELECTION returns null for navigation helper', () {
      expect(
        RunnerRegistrationStep.getStepRouteName(
          RunnerRegistrationStep.citySelection,
        ),
        isNull,
      );
    });

    test('START_REGISTRATION maps to select language', () {
      expect(
        RunnerRegistrationStep.getStepRouteName(
          RunnerRegistrationStep.startRegistration,
        ),
        SelectLanguageV2.routeName,
      );
    });

    test('unknown step returns null', () {
      expect(
        RunnerRegistrationStep.getStepRouteName('UNKNOWN_STEP'),
        isNull,
      );
    });
  });

  group('RunnerRegistrationStep.requiresResetBeforeOpen', () {
    test('returns true for SERVICE_SELECTION, TERMS_AND_CONDITIONS, REGISTRATION_CODE', () {
      expect(
        RunnerRegistrationStep.requiresResetBeforeOpen(
          RunnerRegistrationStep.serviceSelection,
        ),
        isTrue,
      );
      expect(
        RunnerRegistrationStep.requiresResetBeforeOpen(
          RunnerRegistrationStep.termsAndConditions,
        ),
        isTrue,
      );
      expect(
        RunnerRegistrationStep.requiresResetBeforeOpen(
          RunnerRegistrationStep.registrationCode,
        ),
        isTrue,
      );
    });

    test('returns false for other steps and null', () {
      expect(
        RunnerRegistrationStep.requiresResetBeforeOpen(
          RunnerRegistrationStep.personal,
        ),
        isFalse,
      );
      expect(
        RunnerRegistrationStep.requiresResetBeforeOpen(
          RunnerRegistrationStep.citySelection,
        ),
        isFalse,
      );
      expect(RunnerRegistrationStep.requiresResetBeforeOpen(null), isFalse);
    });
  });

  group('WebviewRoutes early registration', () {
    test('earlyRegistrationForm includes module_id', () {
      expect(
        WebviewRoutes.earlyRegistrationForm(42),
        'v1/sobt/registration/form?module_id=42',
      );
    });
  });
}
