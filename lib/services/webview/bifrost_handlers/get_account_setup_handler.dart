import 'package:snabbit_runner/services/webview/bifrost_handler.dart';
import 'package:snabbit_runner/utils/webview_constants.dart';

/// RPC handler for `getAccountSetup`. The web's Payouts page calls this on
/// mount to decide whether to render "Add bank" / "Add PAN" buttons.
///
/// The actual lookup lives in the caller — pass a [buildAccountSetup]
/// builder that resolves the runner's current bank + PAN state. This
/// keeps the handler a pure value-mapper and testable without a widget
/// tree or `UserProfileProvider`.
///
/// Response shape must match `AccountSetup` in
/// `app-webview/src/pages/payouts/types.ts`:
///
/// ```ts
/// interface AccountSetup {
///   upiBank: { status: 'not_added' | 'added' | 'needs_update' | 'processing'; maskedNumber?: string };
///   pan:     { status: 'not_added' | 'added' | 'processing';                  panNumber?: string };
/// }
/// ```
class GetAccountSetupHandler implements BifrostHandler {
  const GetAccountSetupHandler({required this.buildAccountSetup});

  /// Resolves the current account-setup state. Called once per RPC.
  final Future<BifrostResult> Function() buildAccountSetup;

  @override
  String get actionName => WebViewConstants.eventGetAccountSetup;

  @override
  BifrostPattern get pattern => BifrostPattern.rpc;

  @override
  Future<BifrostResult> handle(Map<String, dynamic> data) =>
      buildAccountSetup();
}
