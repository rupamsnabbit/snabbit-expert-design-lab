import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/utils/colors.dart';
import 'package:snabbit_runner/widgets/common_app_bar.dart';
import 'package:snabbit_runner/widgets/picture_capture.dart';

class SelfieCapturePage extends StatefulWidget {

  /// Callback for when user confirms the captured selfie.
  /// Required unless [popWithResult] is true.
  final Function(File image)? onSubmit;

  /// Callback for when user cancels the process.
  /// Required unless [popWithResult] is true.
  final Function()? onCancel;

  /// When true the page behaves as a modal that returns a [File] via
  /// [Navigator.pop]: confirm pops with the captured image, cancel /
  /// back pops with null. [onSubmit] and [onCancel] are ignored.
  ///
  /// This mode is used by [CaptureImageHandler] so the bifrost handler
  /// can `await Navigator.push<File>(...)` and receive the result.
  final bool popWithResult;

  /// When non-null and [popWithResult] is true, the page listens to
  /// this notifier and pops itself (with `null`) when the value becomes
  /// `true`. Used by [CaptureImageHandler.cancel] to dismiss the
  /// camera page without a blind [Navigator.pop] on the parent context.
  final ValueNotifier<bool>? dismissNotifier;

  /// Optional title text key
  final String? titleTextKey;

  /// Optional subtitle text key
  final String? subtitleTextKey;

  const SelfieCapturePage({
    super.key,
    this.onSubmit,
    this.onCancel,
    this.popWithResult = false,
    this.dismissNotifier,
    this.titleTextKey,
    this.subtitleTextKey,
  }) : assert(
         popWithResult || onSubmit != null,
         'Either popWithResult must be true or onSubmit must be provided',
       );

  @override
  State<SelfieCapturePage> createState() => _SelfieCapturePageState();
}

class _SelfieCapturePageState extends State<SelfieCapturePage> {
  bool init = true;
  bool loading = false;
  File? capturedImage;
  bool isPreviewMode = false;
  late LanguageProvider languageProvider;

  /// Guards against double-pop from concurrent dismiss paths
  /// (e.g. [_handleImageCaptured] + [_onDismissRequested] or
  /// [_handleConfirm] racing with [_handleRetake]).
  bool _hasPopped = false;

  @override
  void initState() {
    super.initState();
    widget.dismissNotifier?.addListener(_onDismissRequested);
    MonitoringServiceHelper.logDebug(
      'selfie_capture_page_opened',
      {
        'popWithResult': widget.popWithResult,
        'hasDismissNotifier': widget.dismissNotifier != null,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  @override
  void dispose() {
    widget.dismissNotifier?.removeListener(_onDismissRequested);
    super.dispose();
  }

  void _safePop([File? result]) {
    if (_hasPopped || !mounted) return;
    _hasPopped = true;
    Navigator.of(context).pop(result);
  }

  void _onDismissRequested() {
    if (widget.dismissNotifier?.value == true) {
      MonitoringServiceHelper.logInfo(
        'selfie_capture_page_dismiss_notifier_fired',
        {
          'hasPopped': _hasPopped,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _safePop(null);
    }
  }

  @override
  void didChangeDependencies() {
    if (init) {
      init = false;
      languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    }
    super.didChangeDependencies();
  }

  void _handleImageCaptured(File image) {
    if (widget.popWithResult) {
      // Skip native preview — pop immediately with the captured file.
      // The web side owns the preview UX (retake / confirm); showing
      // it here too is redundant and creates a confusing double-preview
      // flow. If the image is corrupt the web's `<img>` onError fires
      // and the web-side retake button handles recovery.
      _safePop(image);
      return;
    }
    setState(() {
      capturedImage = image;
      isPreviewMode = true;
    });
  }

  void _handleRetake() {
    if (isPreviewMode) {
      setState(() {
        capturedImage = null;
        isPreviewMode = false;
      });
    } else if (mounted) {
      // Back from the camera view (no capture). In popWithResult mode
      // this pops with null — the caller interprets it as cancellation.
      if (widget.popWithResult) {
        _safePop(null);
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  // Future<void> (not void) so the result is observable; still assignable
  // to the button's VoidCallback via Dart's function subtyping.
  Future<void> _handleConfirm() async {
    if (capturedImage == null) return;

    if (widget.popWithResult) {
      // Modal mode: pop with the captured image so the awaiting
      // Navigator.push<File>() call receives it.
      _safePop(capturedImage);
      return;
    }

    // Callback mode: delegate to the provided onSubmit. try/finally so a
    // throwing onSubmit can't strand the page on a permanent loading
    // spinner, and the error is recorded rather than thrown as an
    // unhandled async exception.
    setState(() {
      loading = true;
    });
    try {
      await widget.onSubmit!(capturedImage!);
    } catch (e, stack) {
      MonitoringServiceHelper.logError(
        'selfie_capture_confirm_failed',
        {
          'error': e.toString(),
          'stackTrace': stack.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      // Surface the failure so the user isn't dropped back on the preview
      // with no feedback (they can then retry submit or retake).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getMessage(
                'selfie_submit_failed',
                "Couldn't submit your selfie. Please try again.",
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.n0,
      appBar: CommonAppBar(
        title: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                languageProvider.getMessage(
                  widget.titleTextKey ?? 'take_selfie',
                  'Take Selfie',
                ),
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                languageProvider.getMessage(
                  widget.subtitleTextKey ?? 'selfie_subtitle',
                  'Smile and make sure your face is visible',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: loading ? const Center(child: CupertinoActivityIndicator(),) : isPreviewMode && capturedImage != null
          ? _buildPreviewMode()
          : _buildCaptureMode(),
    );
  }

  Widget _buildCaptureMode() {
    return Stack(
      children: [
        PictureCapture(
          onImageCaptured: _handleImageCaptured,
        ),
      ],
    );
  }

  Widget _buildPreviewMode() {
    return Column(
      children: [
        // Preview the captured image
        Expanded(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Image.file(
              capturedImage!,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // Action buttons
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 41.h,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleRetake,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.n0,
                  ),
                  child: Text(
                    languageProvider.getMessage(
                      'retake',
                      'Retake',
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleConfirm,
                  child: Text(
                    languageProvider.getMessage(
                      'submit',
                      'Submit',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
