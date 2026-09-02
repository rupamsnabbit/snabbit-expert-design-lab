import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/overlay_service.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Dialog explaining why the "Display over other apps" permission is needed.
///
/// When [isDismissable] is `false` (default), any user action (CTA tap,
/// outside tap, back button / swipe) opens the system settings screen for the
/// permission. The dialog auto-dismisses when the user returns to the app and
/// the permission is granted.
///
/// When [isDismissable] is `true`, the user can close the dialog via back
/// button, swipe, or a "Not now" button without granting permission. The AWOL
/// overlay feature degrades gracefully (foreground-only).
class OverlayPermissionDialog extends StatefulWidget {
  final bool isDismissable;

  const OverlayPermissionDialog({
    super.key,
    this.isDismissable = false,
  });

  @override
  State<OverlayPermissionDialog> createState() =>
      _OverlayPermissionDialogState();
}

class _OverlayPermissionDialogState extends State<OverlayPermissionDialog>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndMaybeDismiss();
    }
  }

  Future<void> _checkAndMaybeDismiss() async {
    final granted = await OverlayService.checkPermission();
    if (granted && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _openSettings() {
    OverlayService.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isDismissable,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _openSettings();
        }
      },
      child: Builder(builder: (context) {
        final lp = Provider.of<LanguageProvider>(context, listen: false);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(lp.getMessage(
              'overlay_permission_title', 'Allow display over other apps')),
          content: Text(lp.getMessage(
            'overlay_permission_content',
            'Snabbit Expert needs this permission to show important alerts '
            '(like hotspot breach warnings) when the app is in the background. '
            'Please enable "Display over other apps" in settings.',
          )),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.n90,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  lp.getMessage('overlay_permission_open_settings',
                      'Open Settings'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (widget.isDismissable)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(lp.getMessage(
                      'overlay_permission_not_now', 'Not now')),
                ),
              ),
          ],
        );
      }),
    );
  }
}
