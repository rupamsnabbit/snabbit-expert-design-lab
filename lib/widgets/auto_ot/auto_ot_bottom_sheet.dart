import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/auto_ot/auto_ot_models.dart';
import '../../providers/auto_ot_provider.dart';
import '../../utils/colors.dart';
import '../../utils/enums.dart';
import '../common_bottomsheet_setup.dart';
import 'states/initial_state.dart';
import 'states/confirm_state.dart';
import 'states/loading_state.dart';
import 'states/success_state.dart';
import 'states/expired_state.dart';

/// Function to present the Auto-OT bottom sheet
///
/// Shows the Auto-OT bottom sheet as a modal and handles dismissal.
/// On dismissal, calls the deny API if the state is not success or idle.
/// Returns a Future that completes when the bottom sheet is dismissed.
Future<void> showAutoOtBottomSheet(
  BuildContext context, {
  OtType otType = OtType.EndOt,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AutoOtBottomSheet(otType: otType),
  ).then((result) {
    // Handle dismissal
    if (!context.mounted) return;
    final provider = Provider.of<AutoOtProvider>(context, listen: false);
    if (provider.state != AutoOtState.success &&
        provider.state != AutoOtState.idle) {
      final reason =
          result is AutoOtDenyReason ? result : AutoOtDenyReason.dismissed;
      provider.dismissPopup(reason);
    }
  });
}

/// Main Auto-OT bottom sheet widget
///
/// This is a stateless widget that listens to AutoOtProvider
/// and switches content based on the current state.
class AutoOtBottomSheet extends StatelessWidget {
  final OtType otType;

  const AutoOtBottomSheet({
    super.key,
    this.otType = OtType.EndOt,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AutoOtProvider>(
      builder: (context, provider, _) {
        // If popup is no longer visible, pop the modal route to remove the scrim.
        if (!provider.isPopupVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return const SizedBox.shrink();
        }

        // Determine content based on state
        Widget content;
        switch (provider.state) {
          case AutoOtState.initial:
            content = InitialStateWidget(otType: otType);
            break;
          case AutoOtState.confirm:
            content = ConfirmStateWidget(otType: otType);
            break;
          case AutoOtState.loading:
            content = const LoadingStateWidget();
            break;
          case AutoOtState.success:
            content = SuccessStateWidget(otType: otType);
            break;
          case AutoOtState.expired:
          case AutoOtState.failure:
            content = ExpiredStateWidget(
              otType: otType,
            );
            break;
          case AutoOtState.idle:
          default:
            return const SizedBox.shrink();
        }

        return CommonBottomSheetSetup(
          bgColor: AppColors.n0,
          showDragHandle: false,
          horizontalPadding: 0,
          child: content,
        );
      },
    );
  }
}
