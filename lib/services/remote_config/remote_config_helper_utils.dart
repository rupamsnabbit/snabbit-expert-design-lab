import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';

class RemoteConfigHelperUtils {
  static bool get isTrainingV2Enabled => RemoteConfigService.instance.getBool(
    RemoteConfigKeys.isTrainingV2Enabled,
    defaultValue: false,
  );

  /// Routes the drawer "Refer & earn" entry to the webview
  /// (`v1/referrals/home`) instead of the native `ReferralsHome`. Default OFF:
  /// the rollback + staged-rollout lever for the referrals webview migration.
  static bool get isReferralsV2Enabled => RemoteConfigService.instance.getBool(
    RemoteConfigKeys.isReferralsV2Enabled,
    defaultValue: false,
  );
}
