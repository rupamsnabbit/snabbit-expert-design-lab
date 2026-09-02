import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/utils/webview_launcher.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/widgets/remote_image_handler.dart';

/// Single-line tier nudge row — a leading remote badge, a localized title and a
/// trailing widget (a right chevron by default) — in a rounded gradient
/// container that opens a bifrost webview ([route]) on tap.
///
/// Layout mirrors the tier-nudge Figma frames: an 8px gap between the badge and
/// the text, a 4px gap before the trailing, and configurable padding /
/// [borderRadius]. No colours are baked in — the caller supplies [gradient],
/// [borderColor], [titleColor] and [chevronColor].
///
/// The title is localized through [LanguageProvider]: [titleKey] is resolved
/// via `getFormattedMessage`, falling back to [titleFallback], with
/// [additionalData] substituted into any `{{placeholder}}` tokens.
///
/// Callers that need a different trailing (e.g. a coin/count chip) pass
/// [trailing]; a different leading size passes [leadingSize].
class TierNudgeListItem extends StatelessWidget {
  const TierNudgeListItem({
    super.key,
    required this.titleKey,
    required this.leadingImage,
    this.route,
    required this.gradient,
    required this.borderColor,
    this.trailing,
    this.leadingSize,
    this.titleFallback = '',
    this.additionalData = const {},
    this.leadingImageColor,
    this.webViewTitle = '',
    this.titleColor,
    this.chevronColor,
    this.padding,
    this.borderRadius = 16,
    this.hideBorder = false,
    this.onTap,
  });

  /// Localization key resolved via [LanguageProvider.getFormattedMessage],
  /// e.g. `"you_are_a_gold_expert"`.
  final String titleKey;

  /// English fallback used when [titleKey] is missing from the active locale.
  /// May contain `{{placeholder}}` tokens filled from [additionalData].
  final String titleFallback;

  /// Values substituted into the resolved title's `{{placeholder}}` tokens.
  final Map<String, dynamic> additionalData;

  /// Remote image name/URL rendered as the leading badge via
  /// [RemoteImageHandler].
  final String leadingImage;

  /// Square side of the leading badge, in logical px (scaled with `.w`/`.h`).
  /// Null keeps the default 31.12×32 badge.
  final double? leadingSize;

  /// Optional tint applied to [leadingImage] (`BlendMode.srcIn`). Null leaves
  /// the badge's own colours untouched.
  final Color? leadingImageColor;

  /// [WebviewRoutes] path opened in the bifrost webview on tap. Null (or empty)
  /// renders the row non-tappable.
  final String? route;

  /// Background gradient — no colour is applied unless the caller supplies it.
  final Gradient gradient;

  /// Border colour, drawn only when [hideBorder] is false.
  final Color borderColor;

  /// Trailing widget. Null renders the default right chevron.
  final Widget? trailing;

  /// Title shown in the webview app bar once opened.
  final String webViewTitle;

  /// Colour of the title. Null inherits the ambient text colour.
  final Color? titleColor;

  /// Colour of the default trailing chevron. Ignored when [trailing] is set.
  final Color? chevronColor;

  /// Outer padding. Defaults to 12px vertical / 16px horizontal.
  final EdgeInsetsGeometry? padding;

  /// Corner radius in logical pixels (scaled with `.r`). Defaults to 16.
  final double borderRadius;

  /// Hides the border entirely when true.
  final bool hideBorder;

  /// Analytics hook fired when the (tappable) row is tapped, before the webview
  /// opens. Null for rows that don't need instrumentation.
  final VoidCallback? onTap;

  bool get _isTappable => route != null && route!.isNotEmpty;

  void _handleTap(BuildContext context) {
    onTap?.call();
    _openWebView(context);
  }

  void _openWebView(BuildContext context) {
    final path = route;
    if (path == null || path.isEmpty) return;
    final url = buildWebviewUrl(path);
    if (!WebViewLauncher.isOpenableHttps(url)) return;
    WebViewLauncher.open(context, url: url, title: webViewTitle);
  }

  Widget _buildLeading() {
    Widget leading = SizedBox(
      width: (leadingSize ?? 32).r,
      height: (leadingSize ?? 32).r,
      child: RemoteImageHandler(
        // Keyed by URL: RemoteImageHandler is stateful with no didUpdateWidget,
        // so a reused element (nudge rotation at the same slot) must be rebuilt
        // when the icon URL changes, else stale error/loaded state persists.
        key: ValueKey(leadingImage),
        imageUrl: leadingImage,
        fit: BoxFit.contain,
        animate: false,
        loadingWidget: const SizedBox.shrink(),
        errorWidget: const SizedBox.shrink(),
      ),
    );
    final tint = leadingImageColor;
    if (tint != null) {
      leading = ColorFiltered(
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
        child: leading,
      );
    }
    return leading;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isTappable ? () => _handleTap(context) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding:
            padding ?? EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(borderRadius.r),
          border:
              hideBorder ? null : Border.all(color: borderColor, width: 2.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildLeading(),
            SizedBox(width: 8.w),
            Expanded(
              child: Consumer<LanguageProvider>(
                builder: (context, languageProvider, _) => Text(
                  languageProvider.getFormattedMessage(
                    titleKey,
                    titleFallback,
                    additionalData,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                ),
              ),
            ),
            SizedBox(width: 4.w),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  size: 16.r,
                  color: chevronColor,
                ),
          ],
        ),
      ),
    );
  }
}
