import 'package:pigeon/pigeon.dart';

// Type-safe bridge that pushes Firebase Remote Config bool flags into the KMP
// module. Flutter owns Firebase Remote Config; the KMP (`:shared`) side has no
// RC path of its own, so Flutter mirrors the flags KMP cares about across this
// channel and KMP reads them from an in-memory store. Run codegen after editing:
//   dart run pigeon --input pigeons/remote_config_api.dart
// Generated files are committed (paths below). Do NOT hand-edit the *.g.* files.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/services/remote_config/remote_config_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/com/snabbit/runner/remoteconfig/bridge/RemoteConfigApi.g.kt',
    kotlinOptions:
        KotlinOptions(package: 'com.snabbit.runner.remoteconfig.bridge'),
    dartPackageName: 'snabbit_runner',
  ),
)

/// Dart → KMP (method channel). Flutter pushes the Remote Config bool flags the
/// native module needs (e.g. `expert_show_earnings`) so KMP screens can gate on
/// them without their own Firebase dependency.
@HostApi()
abstract class RemoteConfigHostApi {
  /// Replace the native-side snapshot of RC bool flags. Called after each
  /// fetch-and-activate and on real-time config updates, so KMP always reads
  /// the latest values. A key absent from [flags] falls back to the KMP-side
  /// caller default (safe when RC is unavailable).
  void setBoolFlags(Map<String, bool> flags);

  /// Replace the native-side snapshot of RC **string** flags (e.g. JSON config
  /// like `expert_vishwaas_banner`). Same semantics as [setBoolFlags]: a key
  /// absent from [flags] falls back to the KMP-side caller default.
  void setStringFlags(Map<String, String> flags);
}
