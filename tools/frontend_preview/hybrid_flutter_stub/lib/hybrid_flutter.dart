import 'package:flutter/material.dart';

import 'hybrid_callback.dart';

typedef FlutterWebViewCreatedCallback = void Function(
    HybridViewController controller);

/// Frontend-only replacement for the native KYC view.
class HybridView extends StatefulWidget {
  const HybridView({
    super.key,
    required this.onViewCreated,
    required this.url,
    required this.callback,
  });

  final String url;
  final FlutterWebViewCreatedCallback onViewCreated;
  final Hybridcallback callback;

  @override
  State<HybridView> createState() => _HybridViewState();
}

class _HybridViewState extends State<HybridView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onViewCreated(HybridViewController._());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'KYC preview placeholder',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'The native verification surface is disabled in frontend-only mode.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HybridViewController {
  HybridViewController._();

  Future<void> startHybridView({String? url}) async {}

  Future<void> handleBackPress() async {}

  Future<void> closeHybridView() async {}

  void setMethodCall(Hybridcallback callback) {}
}
