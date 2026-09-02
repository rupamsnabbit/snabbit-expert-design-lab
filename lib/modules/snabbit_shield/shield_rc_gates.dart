import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';

/// Remote-config cohort gates for the two Expert Shield capability tiers.
///
/// - [monitoringOnlyEnabled]: Layer 1b — mic + ML monitoring (no clips).
/// - [recordingEnabled]: recording clips + full monitoring.
///
/// Fail-safe: both default OFF (RC absent ⇒ disabled). Evaluated at shield
/// start, so a flag change takes effect on the next app reopen / job start (no
/// mid-session teardown). Recording escalates the mic layer, so it is only
/// enabled when monitoringOnly is also enabled (B ⇒ A) — starting recording
/// without the mic layer would leave native monitoring running with no capture.
class ShieldRcGates {
  const ShieldRcGates._();

  static bool monitoringOnlyEnabled() => RemoteConfigService.instance.getBool(
        RemoteConfigKeys.shieldMonitoringOnlyEnabled,
        defaultValue: false,
      );

  static bool recordingEnabled() =>
      monitoringOnlyEnabled() &&
      RemoteConfigService.instance.getBool(
        RemoteConfigKeys.shieldRecordingEnabled,
        defaultValue: false,
      );
}
