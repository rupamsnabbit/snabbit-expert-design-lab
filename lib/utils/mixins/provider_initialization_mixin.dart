import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/referral.dart';

/// Mixin that provides common provider initialization patterns
/// to avoid repeating the same provider setup code across widgets.
///
/// Usage:
/// 1. Add `with ProviderInitializationMixin` to your State class
/// 2. Call `initializeCommonProviders()` in didChangeDependencies
/// 3. Access providers via the exposed getters
///
/// Example:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> with ProviderInitializationMixin {
///   @override
///   void didChangeDependencies() {
///     initializeCommonProviders();
///     super.didChangeDependencies();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Text(languageProvider.getMessage("key", "default"));
///   }
/// }
/// ```
mixin ProviderInitializationMixin<T extends StatefulWidget> on State<T> {
  bool _providersInitialized = false;

  // Common providers that most widgets use
  late LanguageProvider _languageProvider;
  late ReferralDataProvider _referralDataProvider;

  // Getters to access the providers
  LanguageProvider get languageProvider => _languageProvider;

  ReferralDataProvider get referralDataProvider => _referralDataProvider;

  bool get providersInitialized => _providersInitialized;

  /// Initialize the most commonly used providers.
  /// Call this in didChangeDependencies() to avoid repeated initialization.
  void initializeCommonProviders() {
    if (!_providersInitialized) {
      _providersInitialized = true;
      _languageProvider = Provider.of<LanguageProvider>(context, listen: true);
      _referralDataProvider =
          Provider.of<ReferralDataProvider>(context, listen: true);
    }
  }

  /// Initialize specific providers as needed.
  /// This can be used for widgets that need additional providers beyond the common ones.
  ///
  /// Example:
  /// ```dart
  /// late UserProfileProvider userProfileProvider;
  ///
  /// @override
  /// void didChangeDependencies() {
  ///   initializeCommonProviders();
  ///   initializeProvider<UserProfileProvider>((context) => userProfileProvider = context.read<UserProfileProvider>());
  ///   super.didChangeDependencies();
  /// }
  /// ```
  void initializeProvider<P>(void Function(BuildContext context) initializer) {
    if (!_providersInitialized) {
      throw StateError(
          'Call initializeCommonProviders() before initializeProvider()');
    }
    initializer(context);
  }

  /// Alternative method for widgets that need custom provider initialization logic.
  /// Override this method in your widget if you need special initialization behavior.
  void initializeCustomProviders() {
    // Override in subclass if needed
  }

  /// Convenience method that combines common and custom provider initialization.
  /// Call this if you want both common providers and custom ones initialized.
  void initializeAllProviders() {
    initializeCommonProviders();
    initializeCustomProviders();
  }
}
