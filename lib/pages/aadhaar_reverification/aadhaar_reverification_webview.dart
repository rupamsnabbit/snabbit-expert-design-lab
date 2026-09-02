import 'package:flutter/material.dart';
import 'package:hybrid_flutter/hybrid_callback.dart';
import 'package:hybrid_flutter/hybrid_flutter.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/colors.dart';

/// Hosts the Perfios `HybridView`. The owning page implements [Hybridcallback]
/// and is passed in as [callback]. A back-press or the close button routes to
/// [onCancel] (an interrupted, retryable result) so the webview is never a
/// dead-end.
class AadhaarReverificationWebView extends StatelessWidget {
  const AadhaarReverificationWebView({
    super.key,
    required this.url,
    required this.callback,
    required this.onCancel,
  });

  final String url;
  final Hybridcallback callback;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onCancel();
      },
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: AppColors.n90,
          leading: IconButton(
            icon: const Icon(Icons.close),
            color: AppColors.n90,
            onPressed: onCancel,
          ),
          title: Text(
            languageProvider.getMessage(
                'aadhaar_rekyc_title', 'Aadhaar verification'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        body: SafeArea(
          child: HybridView(
            onViewCreated: (HybridViewController controller) {},
            callback: callback,
            url: url,
          ),
        ),
      ),
    );
  }
}
