import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/utils/common_methods.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../providers/language_provider.dart';
import '../services/globals.dart';
import '../services/monitoring/monitoring_service_helper.dart';
import '../utils/colors.dart';

void showUpdateRequiredPopup() {
  try {
    if (GlobalState().isAndroidUpdateRequired()) {
      Future.delayed(const Duration(milliseconds: 500))
          .then((_) => _showUpdateRequiredDialog(isSkip: false));
    } else if (GlobalState().isSkipAndroidUpdateRequired()) {
      Future(() => _showUpdateRequiredDialog(isSkip: true));
    }
  } catch (e) {
    // Synchronous guard only (version checks + scheduling). The dialog itself is
    // shown from a later microtask, so its failure is caught inside
    // _showUpdateRequiredDialog — not here.
    MonitoringServiceHelper.logError('update_popup_schedule_failed', {
      'error': e.toString(),
    });
  }
}

/// Shows the update dialog, guarded. This runs from a delayed microtask, so a
/// failure here — a null navigator context mid-transition, or `showDialog`
/// throwing — would escape [showUpdateRequiredPopup]'s synchronous try/catch as
/// an unhandled async error and silently no-op. The force-update gate
/// (`RegistrationNavigation`) now keeps a blocked cohort runner on Flutter with
/// THIS dialog as the only block, so a silent failure would wedge them on a blank
/// loader — catch + log it as a monitorable event (`update_popup_show_failed`).
void _showUpdateRequiredDialog({required bool isSkip}) {
  try {
    final context = GlobalState().navigatorKey.currentContext;
    if (context == null) {
      MonitoringServiceHelper.logError('update_popup_show_failed', {
        'reason': 'null_navigator_context',
        'is_skip': isSkip,
      });
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: isSkip,
      builder: (_) => UpdateRequiredPopup(isSkip: isSkip),
    );
  } catch (e) {
    MonitoringServiceHelper.logError('update_popup_show_failed', {
      'reason': e.runtimeType.toString(),
      'is_skip': isSkip,
    });
  }
}

class UpdateRequiredPopup extends StatefulWidget {
  final bool isSkip;

  const UpdateRequiredPopup({
    super.key,
    this.isSkip = false,
  });

  @override
  State<UpdateRequiredPopup> createState() => _UpdateRequiredPopupState();
}

class _UpdateRequiredPopupState extends State<UpdateRequiredPopup> {
  bool init = true;
  late LanguageProvider languageProvider;

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  Future<void> _redirectToStore() async {
    String url = GlobalState().appConfig?.appUpdateLink ??
        "https://play.google.com/store/apps/details?id=com.snabbit.runner";
    try {
      await launchUrlString(url);
    } catch (e) {
      // DO NOTHING
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isSkip ? true : false,
      child: AlertDialog(
        backgroundColor: AppColors.n0,
        title: Text(
          widget.isSkip
              ? languageProvider.getMessage(
                  'update_available',
                  'Update Available',
                )
              : languageProvider.getMessage(
                  "update_required",
                  "Update Required",
                ),
        ),
        content: Text(
          widget.isSkip
              ? languageProvider.getMessage("update_available_subtitle",
                  'A new version of app is available. Please upgrade your app and never miss new updates.')
              : languageProvider.getMessage(
                  "update_required_subtitle",
                  "Your current version is outdated. A new version of the app is available. Please update to continue.",
                ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: <Widget>[
          Row(
            children: [
              if (widget.isSkip)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      backgroundColor: AppColors.brandInverted,
                    ),
                    child: Text(
                      languageProvider.getMessage(
                        "skip",
                        "Skip",
                      ),
                    ),
                    onPressed: () async {
                      await skipUpdate();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ),
              if (widget.isSkip) SizedBox(width: 16.w),
              Expanded(
                child: ElevatedButton(
                  child: Text(
                    languageProvider.getMessage(
                      "update",
                      "Update",
                    ),
                  ),
                  onPressed: () async {
                    await _redirectToStore();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
