import 'package:disk_space_2/disk_space_2.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';

/// Returns `true` when available device storage is below the Remote Config
/// threshold (default 500 MB). Fails open — returns `false` if the check
/// cannot determine free space.
Future<bool> checkShieldStorageLow() async {
  final thresholdMb = RemoteConfigService.instance.getInt(
    RemoteConfigKeys.shieldStorageBlockThresholdMb,
    defaultValue: 500,
  );

  // Feature disabled when threshold is 0.
  if (thresholdMb <= 0) return false;

  try {
    final freeMb = await DiskSpace.getFreeDiskSpace;
    if (freeMb == null) {
      return false;
    }

    final isLow = freeMb < thresholdMb;
    return isLow;
  } catch (e) {    
    return false;
  }
}
