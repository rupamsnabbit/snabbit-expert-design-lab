import 'package:flutter_test/flutter_test.dart';
import 'package:snabbit_runner/pages/go_live/tnc_accept.dart';
import 'package:snabbit_runner/pages/signup/registration_code_v2.dart';
import 'package:snabbit_runner/pages/signup/select_service.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/utils/registration_navigation.dart';
import 'package:snabbit_runner/utils/runner_registration_step.dart';

RegistrationStep _step(String raw) => RegistrationStep(
      rawStep: raw,
      step: RunnerRegistrationStep.getStepRouteName(raw),
    );

void main() {
  group('RegistrationNavigation.registrationStepAfterReset', () {
    test('returns snapshot when reset failed', () {
      final snapshot = _step(RunnerRegistrationStep.serviceSelection);
      final refreshed = _step(RunnerRegistrationStep.personal);

      final result = RegistrationNavigation.registrationStepAfterReset(
        snapshot: snapshot,
        refreshed: refreshed,
        resetSucceeded: false,
      );

      expect(result, same(snapshot));
      expect(result?.step, SelectService.routeName);
    });

    test('returns refreshed step when reset succeeded', () {
      final snapshot = _step(RunnerRegistrationStep.serviceSelection);
      final refreshed = _step(RunnerRegistrationStep.termsAndConditions);

      final result = RegistrationNavigation.registrationStepAfterReset(
        snapshot: snapshot,
        refreshed: refreshed,
        resetSucceeded: true,
      );

      expect(result, same(refreshed));
      expect(result?.step, TncAcceptPage.routeName);
    });

    test('snapshot preserves REGISTRATION_CODE route on reset failure', () {
      final snapshot = _step(RunnerRegistrationStep.registrationCode);

      final result = RegistrationNavigation.registrationStepAfterReset(
        snapshot: snapshot,
        refreshed: null,
        resetSucceeded: false,
      );

      expect(result?.rawStep, RunnerRegistrationStep.registrationCode);
      expect(result?.step, RegistrationCodeV2.routeName);
    });
  });

  group('RegistrationNavigation.shouldSkipNavigationAfterCityClose', () {
    const city = RunnerRegistrationStep.citySelection;

    test('skips only on manual dismiss (null result, step unchanged)', () {
      expect(
        RegistrationNavigation.shouldSkipNavigationAfterCityClose(
          stepBefore: city,
          stepAfter: city,
          cityStep: city,
          webviewClosedWithResult: false,
        ),
        isTrue,
      );
    });

    test('continues when web closed via bifrost even if step still city', () {
      expect(
        RegistrationNavigation.shouldSkipNavigationAfterCityClose(
          stepBefore: city,
          stepAfter: city,
          cityStep: city,
          webviewClosedWithResult: true,
        ),
        isFalse,
      );
    });

    test('continues when registration step advanced', () {
      expect(
        RegistrationNavigation.shouldSkipNavigationAfterCityClose(
          stepBefore: city,
          stepAfter: RunnerRegistrationStep.onboardingV2,
          cityStep: city,
          webviewClosedWithResult: false,
        ),
        isFalse,
      );
    });
  });

  group('RegistrationNavigation force-update gate RC key', () {
    test('wire value matches the Firebase console key', () {
      // Pin the wire string: a typo here fails no other test — the gate would
      // still default ON, but the RC kill-switch would target the wrong key and
      // become effectively undisableable.
      expect(
        RemoteConfigKeys.kmpForceUpdateGateEnabled,
        'expert_kmp_force_update_gate_enabled',
      );
    });
  });
}
